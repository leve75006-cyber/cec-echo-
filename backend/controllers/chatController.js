const {
  listMessages,
  createMessage,
  updateMessages,
  enrichMessages,
  listUsers,
  getUserById,
  listGroups,
  createGroup,
  updateGroup,
  getGroupById,
  enrichGroups,
  createCall,
  getCallById,
  updateCall,
  enrichCalls,
} = require('../utils/supabaseDb');
const { ensureStudentInCecAssemble, cleanupExpiredStudentsFromCecAssemble } = require('../utils/defaultGroups');

exports.getMessages = async (req, res) => {
  try {
    const myGroups = (await listGroups()).filter((group) =>
      (group.members || []).some((member) => member.user === req.user.id)
    );
    const myGroupIds = new Set(myGroups.map((group) => group.id));

    const messages = (await listMessages())
      .filter((message) => {
        if (message.sender === req.user.id || message.receiver === req.user.id) {
          return true;
        }
        return Boolean(message.groupId) && myGroupIds.has(message.groupId);
      })
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 100);

    const populated = await enrichMessages(messages);
    return res.status(200).json({
      success: true,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getDirectMessages = async (req, res) => {
  try {
    const otherUserId = req.params.userId;
    const messages = (await listMessages())
      .filter(
        (message) =>
          !message.isDeleted &&
          ((message.sender === req.user.id && message.receiver === otherUserId) ||
            (message.sender === otherUserId && message.receiver === req.user.id))
      )
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    await updateMessages(
      {
        receiver: req.user.id,
        sender: otherUserId,
        isRead: false,
      },
      { is_read: true }
    );

    const populated = await enrichMessages(messages);
    return res.status(200).json({
      success: true,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const { receiver, content, messageType, groupId, fileUrl, fileName, fileSize } = req.body;

    if (!receiver && !groupId) {
      return res.status(400).json({
        success: false,
        message: 'Either receiver or groupId is required',
      });
    }
    if (receiver && groupId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot send message to both user and group at the same time',
      });
    }

    if (receiver) {
      const receiverExists = await getUserById(receiver);
      if (!receiverExists) {
        return res.status(404).json({
          success: false,
          message: 'Receiver not found',
        });
      }
    }

    if (groupId) {
      const group = await getGroupById(groupId);
      const isMember = Boolean(group && (group.members || []).some((member) => member.user === req.user.id));
      if (!isMember) {
        return res.status(403).json({
          success: false,
          message: 'You are not a member of this group',
        });
      }
    }

    const message = await createMessage({
      sender: req.user.id,
      receiver,
      content,
      messageType,
      groupId,
      fileUrl,
      fileName,
      fileSize,
    });

    const populated = await enrichMessages([message]);
    return res.status(201).json({
      success: true,
      data: populated[0],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getGroupMessages = async (req, res) => {
  try {
    const groupId = req.params.groupId;
    const group = await getGroupById(groupId);
    if (!group || !(group.members || []).some((member) => member.user === req.user.id)) {
      return res.status(404).json({
        success: false,
        message: 'Group not found or you are not a member',
      });
    }

    const messages = (await listMessages())
      .filter((message) => !message.isDeleted && message.groupId === groupId)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    const populated = await enrichMessages(messages);
    return res.status(200).json({
      success: true,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.createGroup = async (req, res) => {
  try {
    const { name, description, members, isPrivate } = req.body;

    if (members && members.length > 0) {
      const allUsers = await listUsers(false);
      const existingMemberIds = new Set(allUsers.map((user) => user.id));
      const missing = members.find((memberId) => !existingMemberIds.has(memberId));
      if (missing) {
        return res.status(404).json({
          success: false,
          message: 'Some members not found',
        });
      }
    }

    const memberList = [
      {
        user: req.user.id,
        role: 'admin',
        joinedAt: new Date().toISOString(),
      },
      ...((members || []).filter((memberId) => memberId !== req.user.id).map((memberId) => ({
        user: memberId,
        role: 'member',
        joinedAt: new Date().toISOString(),
      }))),
    ];

    const group = await createGroup({
      name,
      description,
      creator: req.user.id,
      members: memberList,
      admins: [req.user.id],
      isPrivate,
    });

    return res.status(201).json({
      success: true,
      data: group,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getGroups = async (req, res) => {
  try {
    await cleanupExpiredStudentsFromCecAssemble();
    if (req.user.role === 'student') {
      await ensureStudentInCecAssemble(req.user.id);
    }

    const groups = (await listGroups()).filter((group) =>
      (group.members || []).some((member) => member.user === req.user.id)
    );
    const populated = await enrichGroups(groups);

    return res.status(200).json({
      success: true,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getGroup = async (req, res) => {
  try {
    await cleanupExpiredStudentsFromCecAssemble();
    if (req.user.role === 'student') {
      await ensureStudentInCecAssemble(req.user.id);
    }

    const group = await getGroupById(req.params.id);
    if (!group || !(group.members || []).some((member) => member.user === req.user.id)) {
      return res.status(404).json({
        success: false,
        message: 'Group not found or you are not a member',
      });
    }

    const populated = await enrichGroups([group]);
    return res.status(200).json({
      success: true,
      data: populated[0],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.addMemberToGroup = async (req, res) => {
  try {
    const { userId, role } = req.body;
    const group = await getGroupById(req.params.id);

    if (!group || !(group.admins || []).includes(req.user.id)) {
      return res.status(404).json({
        success: false,
        message: 'Group not found or you are not an admin',
      });
    }

    const userToAdd = await getUserById(userId);
    if (!userToAdd) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    if ((group.members || []).some((member) => member.user === userId)) {
      return res.status(400).json({
        success: false,
        message: 'User is already a member of this group',
      });
    }

    const members = [
      ...(group.members || []),
      {
        user: userId,
        role: role || 'member',
        joinedAt: new Date().toISOString(),
      },
    ];

    const updated = await updateGroup(group.id, { members });
    return res.status(200).json({
      success: true,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.initiateCall = async (req, res) => {
  try {
    const { callee, groupId, callType } = req.body;

    if (callee) {
      const calleeExists = await getUserById(callee);
      if (!calleeExists) {
        return res.status(404).json({
          success: false,
          message: 'Callee not found',
        });
      }
    }
    if (groupId) {
      const group = await getGroupById(groupId);
      const isMember = Boolean(group && (group.members || []).some((member) => member.user === req.user.id));
      if (!isMember) {
        return res.status(403).json({
          success: false,
          message: 'You are not a member of this group',
        });
      }
    }

    const call = await createCall({
      caller: req.user.id,
      callee,
      groupId,
      callType: callType || 'audio',
    });

    const populated = await enrichCalls([call]);
    return res.status(201).json({
      success: true,
      data: populated[0],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateCallStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const validStatuses = ['ringing', 'ongoing', 'completed', 'missed', 'rejected'];

    if (!validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid call status',
      });
    }

    const call = await getCallById(req.params.id);
    if (!call) {
      return res.status(404).json({
        success: false,
        message: 'Call not found',
      });
    }

    if (call.caller !== req.user.id && call.callee !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this call',
      });
    }

    const updates = { status };
    if (status === 'ongoing' && !call.startTime) {
      updates.startTime = new Date().toISOString();
    } else if (['completed', 'missed', 'rejected'].includes(status) && !call.endTime) {
      const endTime = new Date();
      updates.endTime = endTime.toISOString();
      if (call.startTime) {
        updates.duration = Math.floor((endTime.getTime() - new Date(call.startTime).getTime()) / 1000);
      }
    }

    const updated = await updateCall(req.params.id, updates);
    return res.status(200).json({
      success: true,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
