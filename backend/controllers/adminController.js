const User = require('../models/User');
const Announcement = require('../models/Announcement');
const { Message, Group, Call } = require('../models/Chat');
const { protect, authorize } = require('../middleware/auth');

// @desc      Get admin dashboard stats
// @route     GET /api/admin/dashboard
// @access    Private/Admin
exports.getDashboardStats = async (req, res) => {
  try {
    // Get counts for different entities
    const userCount = await User.countDocuments();
    const announcementCount = await Announcement.countDocuments();
    const activeUsers = await User.countDocuments({ isActive: true });
    const groupCount = await Group.countDocuments();
    const messageCount = await Message.countDocuments();
    const callCount = await Call.countDocuments();
    
    // Get recent activities
    const recentUsers = await User.find()
      .sort({ createdAt: -1 })
      .limit(5)
      .select('firstName lastName username email role createdAt');
      
    const recentAnnouncements = await Announcement.find()
      .populate('author', 'firstName lastName username')
      .sort({ createdAt: -1 })
      .limit(5);
      
    const recentMessages = await Message.find()
      .populate('sender', 'firstName lastName username')
      .populate('receiver', 'firstName lastName username')
      .sort({ createdAt: -1 })
      .limit(5);

    res.status(200).json({
      success: true,
      data: {
        stats: {
          totalUsers: userCount,
          activeUsers: activeUsers,
          totalAnnouncements: announcementCount,
          totalGroups: groupCount,
          totalMessages: messageCount,
          totalCalls: callCount
        },
        recentActivities: {
          recentUsers,
          recentAnnouncements,
          recentMessages
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

// @desc      Get all users with pagination
// @route     GET /api/admin/users
// @access    Private/Admin
exports.getAllUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;
    
    // Build query
    let query = {};
    
    // Add search capability
    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search, 'i');
      query.$or = [
        { firstName: searchRegex },
        { lastName: searchRegex },
        { username: searchRegex },
        { email: searchRegex }
      ];
    }
    
    // Add role filter
    if (req.query.role) {
      query.role = req.query.role;
    }
    
    // Add status filter
    if (req.query.status) {
      query.isActive = req.query.status === 'active';
    }
    
    const users = await User.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    
    const total = await User.countDocuments(query);
    
    res.status(200).json({
      success: true,
      data: {
        users,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(total / limit),
          totalUsers: total,
          hasNext: page < Math.ceil(total / limit),
          hasPrev: page > 1
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

// @desc      Get all announcements with filters
// @route     GET /api/admin/announcements
// @access    Private/Admin
exports.getAllAnnouncements = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;
    
    // Build query
    let query = {};
    
    // Add search capability
    if (req.query.search) {
      const searchRegex = new RegExp(req.query.search, 'i');
      query.$or = [
        { title: searchRegex },
        { content: searchRegex }
      ];
    }
    
    // Add category filter
    if (req.query.category) {
      query.category = req.query.category;
    }
    
    // Add priority filter
    if (req.query.priority) {
      query.priority = req.query.priority;
    }
    
    // Add publication status filter
    if (req.query.status) {
      query.isPublished = req.query.status === 'published';
    }
    
    const announcements = await Announcement.find(query)
      .populate('author', 'firstName lastName username role')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);
    
    const total = await Announcement.countDocuments(query);
    
    res.status(200).json({
      success: true,
      data: {
        announcements,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(total / limit),
          totalAnnouncements: total,
          hasNext: page < Math.ceil(total / limit),
          hasPrev: page > 1
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

// @desc      Update user role
// @route     PUT /api/admin/users/role/:id
// @access    Private/Admin
exports.updateUserRole = async (req, res) => {
  try {
    const { role } = req.body;
    const validRoles = ['student', 'faculty', 'admin'];
    
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid role specified'
      });
    }
    
    const user = await User.findByIdAndUpdate(
      req.params.id,
      { role },
      { new: true, runValidators: true }
    ).select('-password');
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    res.status(200).json({
      success: true,
      data: user
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};