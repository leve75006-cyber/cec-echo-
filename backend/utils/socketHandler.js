const { createMessage, enrichMessages, getUserById } = require('./supabaseDb');
const { initializeWebRTC } = require('./webrtcHandler');

let io;

const initializeSocket = (server) => {
  const socketIo = require('socket.io')(server, {
    cors: {
      origin: process.env.FRONTEND_URL || 'http://localhost:3000',
      methods: ['GET', 'POST'],
    },
  });

  io = socketIo;
  initializeWebRTC(socketIo);

  socketIo.on('connection', (socket) => {
    console.log('New client connected:', socket.id);

    socket.on('join-room', (room) => {
      socket.join(room);
      console.log(`Socket ${socket.id} joined room ${room}`);
    });

    socket.on('private-message', async (data) => {
      try {
        const sender = await getUserById(data.senderId);
        if (!sender) {
          socket.emit('error', { message: 'Sender not found' });
          return;
        }

        const message = await createMessage({
          sender: data.senderId,
          receiver: data.receiverId,
          content: data.content,
          messageType: data.messageType || 'text',
        });
        const [populated] = await enrichMessages([message]);

        socket.to(String(data.receiverId)).emit('receive-private-message', populated);
        socket.emit('message-sent', populated);
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    socket.on('group-message', async (data) => {
      try {
        const sender = await getUserById(data.senderId);
        if (!sender) {
          socket.emit('error', { message: 'Sender not found' });
          return;
        }

        const message = await createMessage({
          sender: data.senderId,
          groupId: data.groupId,
          content: data.content,
          messageType: data.messageType || 'text',
        });
        const [populated] = await enrichMessages([message]);

        socket.to(String(data.groupId)).emit('receive-group-message', populated);
        socket.emit('message-sent', populated);
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    socket.on('typing-start', (data) => {
      socket.to(data.room).emit('user-typing', { userId: data.userId, userName: data.userName });
    });

    socket.on('typing-stop', (data) => {
      socket.to(data.room).emit('user-stopped-typing', { userId: data.userId });
    });

    socket.on('set-online-status', async (userId) => {
      try {
        socket.broadcast.emit('user-status-changed', { userId, status: 'online' });
      } catch (error) {
        console.error('Error setting online status:', error);
      }
    });

    socket.on('disconnect', () => {
      console.log('Client disconnected:', socket.id);
    });
  });

  return socketIo;
};

const emitToUser = (userId, event, data) => {
  if (io) {
    io.to(String(userId)).emit(event, data);
  }
};

const emitToRoom = (room, event, data) => {
  if (io) {
    io.to(String(room)).emit(event, data);
  }
};

const emitToOthers = (socketId, event, data) => {
  if (io) {
    io.to(socketId).emit(event, data);
  }
};

module.exports = {
  initializeSocket,
  emitToUser,
  emitToRoom,
  emitToOthers,
};
