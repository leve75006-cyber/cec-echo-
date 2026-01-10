const { Message, Group, Call } = require('../models/Chat');
const User = require('../models/User');
const { protect } = require('../middleware/auth');

// @desc      Get all messages for a user
// @route     GET /api/chat/messages
// @access    Private
exports.getMessages = async (req, res) => {
  try {
    const messages = await Message.find({
      $or: [
        { sender: req.user.id },
        { receiver: req.user.id },
        { groupId: { $exists: true } } // Include group messages
      ]
    })
    .populate('sender', 'firstName lastName username profilePicture')
    .populate('receiver', 'firstName lastName username profilePicture')
    .populate('groupId', 'name avatar')
    .sort({ createdAt: -1 })
    .limit(100); // Limit to last 100 messages

    res.status(200).json({
      success: true,
      data: messages
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get messages between two users
// @route     GET /api/chat/messages/:userId
// @access    Private
exports.getDirectMessages = async (req, res) => {
  try {
    const messages = await Message.find({
      $and: [
        {
          $or: [
            { sender: req.user.id, receiver: req.params.userId },
            { sender: req.params.userId, receiver: req.user.id }
          ]
        },
        { isDeleted: false }
      ]
    })
    .populate('sender', 'firstName lastName username profilePicture')
    .populate('receiver', 'firstName lastName username profilePicture')
    .sort({ createdAt: -1 });

    // Mark messages as read if sent to current user
    await Message.updateMany(
      {
        receiver: req.user.id,
        sender: req.params.userId,
        isRead: false
      },
      { isRead: true }
    );

    res.status(200).json({
      success: true,
      data: messages
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Send a message
// @route     POST /api/chat/messages
// @access    Private
exports.sendMessage = async (req, res) => {
  try {
    const { receiver, content, messageType, groupId } = req.body;

    // Validate if it's a group or direct message
    if (!receiver && !groupId) {
      return res.status(400).json({
        success: false,
        message: 'Either receiver or groupId is required'
      });
    }

    if (receiver && groupId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot send message to both user and group at the same time'
      });
    }

    // For direct messages, validate receiver exists
    if (receiver) {
      const receiverExists = await User.findById(receiver);
      if (!receiverExists) {
        return res.status(404).json({
          success: false,
          message: 'Receiver not found'
        });
      }
    }

    const message = await Message.create({
      sender: req.user.id,
      receiver,
      content,
      messageType,
      groupId
    });

    // Populate sender for response
    await message.populate('sender', 'firstName lastName username profilePicture');

    res.status(201).json({
      success: true,
      data: message
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Create a group
// @route     POST /api/chat/groups
// @access    Private
exports.createGroup = async (req, res) => {
  try {
    const { name, description, members, isPrivate } = req.body;

    // Validate members exist
    if (members && members.length > 0) {
      const existingMembers = await User.find({ _id: { $in: members } });
      if (existingMembers.length !== members.length) {
        return res.status(404).json({
          success: false,
          message: 'Some members not found'
        });
      }
    }

    const group = await Group.create({
      name,
      description,
      creator: req.user.id,
      members: members ? members.map(memberId => ({ user: memberId })) : [],
      admins: [req.user.id],
      isPrivate
    });

    // Add the creator as an admin member
    group.members.unshift({
      user: req.user.id,
      role: 'admin',
      joinedAt: new Date()
    });
    await group.save();

    res.status(201).json({
      success: true,
      data: group
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get all groups for a user
// @route     GET /api/chat/groups
// @access    Private
exports.getGroups = async (req, res) => {
  try {
    // Get groups where user is a member
    const groups = await Group.find({
      'members.user': req.user.id
    })
    .populate('creator', 'firstName lastName username')
    .populate('members.user', 'firstName lastName username profilePicture')
    .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: groups
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get group by ID
// @route     GET /api/chat/groups/:id
// @access    Private
exports.getGroup = async (req, res) => {
  try {
    const group = await Group.findOne({
      _id: req.params.id,
      'members.user': req.user.id // Ensure user is a member of the group
    })
    .populate('creator', 'firstName lastName username')
    .populate('members.user', 'firstName lastName username profilePicture')
    .populate({
      path: 'members.user',
      select: 'firstName lastName username profilePicture'
    });

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found or you are not a member'
      });
    }

    res.status(200).json({
      success: true,
      data: group
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Add member to group
// @route     PUT /api/chat/groups/add-member/:id
// @access    Private
exports.addMemberToGroup = async (req, res) => {
  try {
    const { userId, role } = req.body;

    const group = await Group.findOne({
      _id: req.params.id,
      admins: req.user.id // Ensure user is an admin
    });

    if (!group) {
      return res.status(404).json({
        success: false,
        message: 'Group not found or you are not an admin'
      });
    }

    // Check if user exists
    const userToAdd = await User.findById(userId);
    if (!userToAdd) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Check if user is already in the group
    const isAlreadyMember = group.members.some(member => member.user.toString() === userId);
    if (isAlreadyMember) {
      return res.status(400).json({
        success: false,
        message: 'User is already a member of this group'
      });
    }

    // Add member to group
    group.members.push({
      user: userId,
      role: role || 'member'
    });

    await group.save();

    res.status(200).json({
      success: true,
      data: group
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Initiate a call
// @route     POST /api/chat/calls
// @access    Private
exports.initiateCall = async (req, res) => {
  try {
    const { callee, groupId, callType } = req.body;

    // Validate callee exists if it's a direct call
    if (callee) {
      const calleeExists = await User.findById(callee);
      if (!calleeExists) {
        return res.status(404).json({
          success: false,
          message: 'Callee not found'
        });
      }
    }

    const call = await Call.create({
      caller: req.user.id,
      callee,
      groupId,
      callType: callType || 'audio'
    });

    // Populate user data for response
    await call.populate([
      { path: 'caller', select: 'firstName lastName username profilePicture' },
      { path: 'callee', select: 'firstName lastName username profilePicture' },
      { path: 'groupId', select: 'name' }
    ]);

    res.status(201).json({
      success: true,
      data: call
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Update call status
// @route     PUT /api/chat/calls/:id
// @access    Private
exports.updateCallStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['ringing', 'ongoing', 'completed', 'missed', 'rejected'];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid call status'
      });
    }

    const call = await Call.findById(req.params.id);

    if (!call) {
      return res.status(404).json({
        success: false,
        message: 'Call not found'
      });
    }

    // Check authorization - either caller or callee can update
    if (call.caller.toString() !== req.user.id && call.callee.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this call'
      });
    }

    call.status = status;

    // Set start/end times based on status
    if (status === 'ongoing' && !call.startTime) {
      call.startTime = Date.now();
    } else if (['completed', 'missed', 'rejected'].includes(status) && !call.endTime) {
      call.endTime = Date.now();
      if (call.startTime) {
        call.duration = Math.floor((call.endTime - call.startTime) / 1000); // Duration in seconds
      }
    }

    await call.save();

    res.status(200).json({
      success: true,
      data: call
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};
