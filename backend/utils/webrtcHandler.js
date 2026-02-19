const { createCall, updateCall, getCallById, getUserById, getGroupById } = require('./supabaseDb');

const webrtcConfig = {
  iceServers: [
    {
      urls: process.env.STUN_SERVER || 'stun:stun.l.google.com:19302',
    },
    {
      urls: process.env.TURN_SERVER || 'turn:your-turn-server.com:3478',
      username: process.env.TURN_USERNAME || 'your-turn-username',
      credential: process.env.TURN_CREDENTIALS || 'your-turn-password',
    },
  ],
  iceCandidatePoolSize: 10,
};

const initializeWebRTC = (io) => {
  io.on('connection', (socket) => {
    socket.on('call-user', async (data) => {
      try {
        const { to, from, callType, offer, meetingId } = data;

        const caller = await getUserById(from);
        if (!caller) {
          socket.emit('call-error', { message: 'Caller not found' });
          return;
        }
        if (!['faculty', 'admin'].includes(caller.role)) {
          socket.emit('call-error', { message: 'Only faculty can start calls.' });
          return;
        }

        const callee = await getUserById(to);
        if (!callee) {
          socket.emit('call-error', { message: 'Callee not found' });
          return;
        }

        const call = await createCall({
          caller: from,
          callee: to,
          callType: callType || 'audio',
          status: 'initiated',
          meetingId,
        });

        socket.emit('call-initiated', {
          callId: call.id,
          to,
          callType,
          meetingId,
          calleeInfo: await getUserInfo(to),
        });

        socket.to(String(to)).emit('incoming-call', {
          from,
          callId: call.id,
          callType,
          offer,
          meetingId,
          callerInfo: await getUserInfo(from),
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('accept-call', async (data) => {
      try {
        const { callId, to, answer } = data;
        await updateCall(callId, { status: 'ongoing', startTime: new Date().toISOString() });

        socket.to(String(to)).emit('call-accepted', {
          callId,
          answer,
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('reject-call', async (data) => {
      try {
        const { callId, to } = data;
        await updateCall(callId, { status: 'rejected', endTime: new Date().toISOString() });
        socket.to(String(to)).emit('call-rejected', { callId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('terminate-call', async (data) => {
      try {
        const { callId, to } = data;
        const call = await getCallById(callId);
        const endTime = new Date();
        const updates = {
          status: 'completed',
          endTime: endTime.toISOString(),
        };
        if (call && call.startTime) {
          updates.duration = Math.floor((endTime.getTime() - new Date(call.startTime).getTime()) / 1000);
        }
        await updateCall(callId, updates);
        socket.to(String(to)).emit('call-terminated', { callId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('ice-candidate', (data) => {
      const { to, candidate } = data;
      socket.to(String(to)).emit('ice-candidate', {
        candidate,
        from: socket.id,
      });
    });

    socket.on('initiate-broadcast', async (data) => {
      try {
        const { groupId, from, callType } = data;
        const group = await getGroupById(groupId);
        const isMember = Boolean(group && (group.members || []).some((member) => member.user === from));
        if (!isMember) {
          socket.emit('call-error', { message: 'Not authorized for this group call.' });
          return;
        }

        const call = await createCall({
          caller: from,
          groupId,
          callType: callType || 'audio',
          status: 'ongoing',
        });

        socket.to(String(groupId)).emit('broadcast-initiated', {
          from,
          callId: call.id,
          callType,
          callerInfo: await getUserInfo(from),
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('raise-hand', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        const call = await getCallById(callId);
        if (call) {
          socket.to(String(call.caller)).emit('hand-raised', {
            userId,
            userName: (await getUserInfo(userId)).name,
          });
          socket.to(String(groupId)).emit('participant-hand-raised', {
            userId,
            userName: (await getUserInfo(userId)).name,
          });
        }
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('grant-speaker-permission', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        socket.to(String(userId)).emit('speaker-permission-granted', { callId });
        socket.to(String(groupId)).emit('speaker-added', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('revoke-speaker-permission', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        socket.to(String(userId)).emit('speaker-permission-revoked', { callId });
        socket.to(String(groupId)).emit('speaker-removed', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    socket.on('leave-broadcast', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        const call = await getCallById(callId);
        if (call) {
          socket.to(String(call.caller)).emit('participant-left', { userId });
        }
        socket.to(String(groupId)).emit('participant-left-broadcast', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });
  });
};

const getUserInfo = async (userId) => {
  try {
    const user = await getUserById(userId);
    if (!user) {
      return { id: userId, name: 'Unknown User' };
    }
    return {
      id: user.id,
      name: `${user.firstName} ${user.lastName}`.trim(),
      username: user.username,
      profilePicture: user.profilePicture,
    };
  } catch (error) {
    console.error('Error getting user info:', error);
    return { id: userId, name: 'Unknown User' };
  }
};

const getWebRTCConfig = () => webrtcConfig;

module.exports = {
  initializeWebRTC,
  getWebRTCConfig,
};
