const Message = require('../models/Chat').Message;
const User = require('../models/User');
const { initializeWebRTC } = require('./webrtcHandler');

let io;

// Initialize socket.io connections
const initializeSocket = (server) => {
  const socketIo = require('socket.io')(server, {
    cors: {
      origin: process.env.FRONTEND_URL || 'http://localhost:3000',
      methods: ['GET', 'POST']
    }
  });

  io = socketIo;

  initializeWebRTC(socketIo);

  socketIo.on('connection', (socket) => {
    console.log('New client connected:', socket.id);

    // Join a specific room (could be user ID, group ID, etc.)
    socket.on('join-room', (room) => {
      socket.join(room);
      console.log(`Socket ${socket.id} joined room ${room}`);
    });

    // Handle private messaging
    socket.on('private-message', async (data) => {
      try {
        // Verify sender is authenticated
        const sender = await User.findById(data.senderId);
        if (!sender) {
          socket.emit('error', { message: 'Sender not found' });
          return;
        }

        // Create message in database
        const message = await Message.create({
          sender: data.senderId,
          receiver: data.receiverId,
          content: data.content,
          messageType: data.messageType || 'text'
        });

        // Populate sender info for the message
        await message.populate('sender', 'firstName lastName username profilePicture');

        // Emit message to sender and receiver
        socket.to(data.receiverId.toString()).emit('receive-private-message', message);
        socket.emit('message-sent', message);
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    // Handle group messaging
    socket.on('group-message', async (data) => {
      try {
        // Verify sender is authenticated
        const sender = await User.findById(data.senderId);
        if (!sender) {
          socket.emit('error', { message: 'Sender not found' });
          return;
        }

        // Create group message in database
        const message = await Message.create({
          sender: data.senderId,
          groupId: data.groupId,
          content: data.content,
          messageType: data.messageType || 'text'
        });

        // Populate sender info for the message
        await message.populate('sender', 'firstName lastName username profilePicture');

        // Emit message to the group
        socket.to(data.groupId.toString()).emit('receive-group-message', message);
        
        // Also emit to sender to confirm sending
        socket.emit('message-sent', message);
      } catch (error) {
        socket.emit('error', { message: error.message });
      }
    });

    // Handle typing indicators
    socket.on('typing-start', (data) => {
      socket.to(data.room).emit('user-typing', { userId: data.userId, userName: data.userName });
    });

    socket.on('typing-stop', (data) => {
      socket.to(data.room).emit('user-stopped-typing', { userId: data.userId });
    });

    // Handle online/offline status
    socket.on('set-online-status', async (userId) => {
      try {
        // Update user's online status in DB if needed
        socket.broadcast.emit('user-status-changed', { userId, status: 'online' });
      } catch (error) {
        console.error('Error setting online status:', error);
      }
    });

    socket.on('disconnect', () => {
      console.log('Client disconnected:', socket.id);
      // Could update user's online status in DB here
    });
  });

  return socketIo;
};

// Helper function to emit events to specific user
const emitToUser = (userId, event, data) => {
  if (io) {
    io.to(userId.toString()).emit(event, data);
  }
};

// Helper function to emit events to specific room
const emitToRoom = (room, event, data) => {
  if (io) {
    io.to(room.toString()).emit(event, data);
  }
};

// Helper function to emit events to all clients except sender
const emitToOthers = (socketId, event, data) => {
  if (io) {
    io.to(socketId).emit(event, data);
  }
};

module.exports = {
  initializeSocket,
  emitToUser,
  emitToRoom,
  emitToOthers
};