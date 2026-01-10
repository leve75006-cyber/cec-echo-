const Announcement = require('../models/Announcement');
const User = require('../models/User');
const { Message, Group } = require('../models/Chat');
const { protect } = require('../middleware/auth');

// @desc      Get announcements for student
// @route     GET /api/student/announcements
// @access    Private/Student
exports.getStudentAnnouncements = async (req, res) => {
  try {
    // Students can see announcements for all, students, or their specific department
    const query = {
      $and: [
        { isPublished: true },
        {
          $or: [
            { targetAudience: { $in: ['all', 'students'] } },
            { targetAudience: 'specific-dept', department: req.user.department }
          ]
        }
      ]
    };

    const announcements = await Announcement.find(query)
      .populate('author', 'firstName lastName username role department')
      .populate('viewers', 'firstName lastName username')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: announcements.length,
      data: announcements
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get student profile with additional info
// @route     GET /api/student/profile
// @access    Private/Student
exports.getStudentProfile = async (req, res) => {
  try {
    // Get the student's profile with additional information
    const student = await User.findById(req.user.id)
      .populate({
        path: 'sentMessages',
        select: 'content createdAt messageType',
        options: { sort: { createdAt: -1 }, limit: 10 }
      })
      .populate({
        path: 'receivedMessages', 
        select: 'content createdAt messageType',
        options: { sort: { createdAt: -1 }, limit: 10 }
      });

    // Get recent announcements viewed by the student
    const recentAnnouncements = await Announcement.find({
      viewers: req.user.id
    })
    .sort({ createdAt: -1 })
    .limit(5);

    // Get student's group memberships
    const groups = await Group.find({
      'members.user': req.user.id
    })
    .populate('creator', 'firstName lastName username')
    .populate('members.user', 'firstName lastName username profilePicture');

    res.status(200).json({
      success: true,
      data: {
        user: student,
        recentAnnouncements,
        groups
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get student's groups
// @route     GET /api/student/groups
// @access    Private/Student
exports.getStudentGroups = async (req, res) => {
  try {
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

// @desc      Get student's unread messages count
// @route     GET /api/student/unread-count
// @access    Private/Student
exports.getUnreadMessagesCount = async (req, res) => {
  try {
    const unreadCount = await Message.countDocuments({
      receiver: req.user.id,
      isRead: false
    });

    res.status(200).json({
      success: true,
      data: {
        unreadCount
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Get student dashboard
// @route     GET /api/student/dashboard
// @access    Private/Student
exports.getStudentDashboard = async (req, res) => {
  try {
    // Get counts for different entities relevant to the student
    const announcementsCount = await Announcement.countDocuments({
      $and: [
        { isPublished: true },
        {
          $or: [
            { targetAudience: { $in: ['all', 'students'] } },
            { targetAudience: 'specific-dept', department: req.user.department }
          ]
        }
      ]
    });

    const unreadMessagesCount = await Message.countDocuments({
      receiver: req.user.id,
      isRead: false
    });

    const groupsCount = await Group.countDocuments({
      'members.user': req.user.id
    });

    // Get recent announcements
    const recentAnnouncements = await Announcement.find({
      $and: [
        { isPublished: true },
        {
          $or: [
            { targetAudience: { $in: ['all', 'students'] } },
            { targetAudience: 'specific-dept', department: req.user.department }
          ]
        }
      ]
    })
    .populate('author', 'firstName lastName username')
    .sort({ createdAt: -1 })
    .limit(5);

    // Get recent messages
    const recentMessages = await Message.find({
      $or: [
        { sender: req.user.id },
        { receiver: req.user.id }
      ]
    })
    .populate('sender', 'firstName lastName username')
    .populate('receiver', 'firstName lastName username')
    .sort({ createdAt: -1 })
    .limit(5);

    // Get student's groups
    const groups = await Group.find({
      'members.user': req.user.id
    })
    .sort({ createdAt: -1 })
    .limit(5);

    res.status(200).json({
      success: true,
      data: {
        stats: {
          totalAnnouncements: announcementsCount,
          unreadMessages: unreadMessagesCount,
          totalGroups: groupsCount
        },
        recent: {
          announcements: recentAnnouncements,
          messages: recentMessages,
          groups: groups
        }
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};