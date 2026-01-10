const { Call } = require('../models/Chat');
const User = require('../models/User');
const { emitToUser } = require('./socketHandler');

// WebRTC configuration
const webrtcConfig = {
  iceServers: [
    {
      urls: process.env.STUN_SERVER || 'stun:stun.l.google.com:19302'
    },
    // TURN server configuration for NAT traversal
    {
      urls: process.env.TURN_SERVER || 'turn:your-turn-server.com:3478',
      username: process.env.TURN_USERNAME || 'your-turn-username',
      credential: process.env.TURN_CREDENTIALS || 'your-turn-password'
    }
  ],
  iceCandidatePoolSize: 10
};

// Handle WebRTC signaling
const initializeWebRTC = (io) => {
  io.on('connection', (socket) => {
    // Handle call initiation
    socket.on('call-user', async (data) => {
      try {
        const { to, from, callType, offer } = data;
        
        // Create call record in database
        const call = await Call.create({
          caller: from,
          callee: to,
          callType: callType || 'audio',
          status: 'initiated'
        });

        // Notify the callee about the incoming call
        socket.to(to.toString()).emit('incoming-call', {
          from,
          callId: call._id,
          callType: callType,
          offer,
          callerInfo: await getUserInfo(from)
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle call acceptance
    socket.on('accept-call', async (data) => {
      try {
        const { callId, to, answer } = data;
        
        // Update call status to ongoing
        const call = await Call.findByIdAndUpdate(
          callId,
          { 
            status: 'ongoing',
            startTime: Date.now()
          },
          { new: true }
        );

        // Notify the caller that the call is accepted
        socket.to(to.toString()).emit('call-accepted', {
          callId,
          answer
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle call rejection
    socket.on('reject-call', async (data) => {
      try {
        const { callId, to } = data;
        
        // Update call status to rejected
        await Call.findByIdAndUpdate(callId, { status: 'rejected' });
        
        // Notify the caller that the call is rejected
        socket.to(to.toString()).emit('call-rejected', { callId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle call termination
    socket.on('terminate-call', async (data) => {
      try {
        const { callId, to } = data;
        
        // Update call status to completed and set end time
        const call = await Call.findByIdAndUpdate(
          callId,
          { 
            status: 'completed',
            endTime: Date.now(),
            $expr: { $add: [{ $ifNull: ['$startTime', Date.now()] }, Date.now()] } // Calculate duration
          },
          { new: true }
        );

        // If call had a start time, calculate duration
        if (call.startTime) {
          const duration = Math.floor((Date.now() - call.startTime.getTime()) / 1000);
          await Call.findByIdAndUpdate(callId, { duration });
        }

        // Notify the other party that the call is terminated
        socket.to(to.toString()).emit('call-terminated', { callId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle ICE candidate exchange
    socket.on('ice-candidate', (data) => {
      const { to, candidate } = data;
      socket.to(to.toString()).emit('ice-candidate', {
        candidate,
        from: socket.id
      });
    });

    // Handle broadcast calls (like FM broadcast)
    socket.on('initiate-broadcast', async (data) => {
      try {
        const { groupId, from, callType } = data;
        
        // Create broadcast call record
        const call = await Call.create({
          caller: from,
          groupId,
          callType: callType || 'audio',
          status: 'ongoing' // Broadcast starts immediately
        });

        // Notify all group members about the broadcast
        socket.to(groupId.toString()).emit('broadcast-initiated', {
          from,
          callId: call._id,
          callType,
          callerInfo: await getUserInfo(from)
        });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle raise hand in broadcast
    socket.on('raise-hand', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        
        // Notify the broadcaster that someone raised their hand
        const call = await Call.findById(callId);
        if (call) {
          socket.to(call.caller.toString()).emit('hand-raised', {
            userId,
            userName: (await getUserInfo(userId)).name
          });
          
          // Notify all participants about the hand raise
          socket.to(groupId.toString()).emit('participant-hand-raised', {
            userId,
            userName: (await getUserInfo(userId)).name
          });
        }
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle permission to speak in broadcast
    socket.on('grant-speaker-permission', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        
        // Notify the participant that they can now speak
        socket.to(userId.toString()).emit('speaker-permission-granted', { callId });
        
        // Notify all participants about the permission change
        socket.to(groupId.toString()).emit('speaker-added', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle revoke speaker permission
    socket.on('revoke-speaker-permission', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        
        // Notify the participant that their speaking permission is revoked
        socket.to(userId.toString()).emit('speaker-permission-revoked', { callId });
        
        // Notify all participants about the permission change
        socket.to(groupId.toString()).emit('speaker-removed', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });

    // Handle participant leaving broadcast
    socket.on('leave-broadcast', async (data) => {
      try {
        const { callId, userId, groupId } = data;
        
        // Notify the broadcaster that a participant left
        const call = await Call.findById(callId);
        if (call) {
          socket.to(call.caller.toString()).emit('participant-left', { userId });
        }
        
        // Notify all participants about the departure
        socket.to(groupId.toString()).emit('participant-left-broadcast', { userId });
      } catch (error) {
        socket.emit('call-error', { message: error.message });
      }
    });
  });
};

// Helper function to get user info
const getUserInfo = async (userId) => {
  try {
    const user = await User.findById(userId).select('firstName lastName username profilePicture');
    return {
      id: user._id,
      name: `${user.firstName} ${user.lastName}`,
      username: user.username,
      profilePicture: user.profilePicture
    };
  } catch (error) {
    console.error('Error getting user info:', error);
    return { id: userId, name: 'Unknown User' };
  }
};

// Get WebRTC configuration for client
const getWebRTCConfig = () => {
  return webrtcConfig;
};

module.exports = {
  initializeWebRTC,
  getWebRTCConfig
};