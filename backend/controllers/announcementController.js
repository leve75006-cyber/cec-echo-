const Announcement = require('../models/Announcement');
const User = require('../models/User');
const { protect, authorize } = require('../middleware/auth');

// @desc      Get all announcements
// @route     GET /api/announcements
// @access    Private
exports.getAnnouncements = async (req, res) => {
  try {
    // Determine which announcements to show based on user role
    let query = {};
    
    if (req.user.role === 'student') {
      query.targetAudience = { $in: ['all', 'students'] };
    } else if (req.user.role === 'faculty') {
      query.targetAudience = { $in: ['all', 'faculty', 'students'] };
    }
    // Admins can see all announcements
    
    query.isPublished = true;
    
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

// @desc      Get single announcement
// @route     GET /api/announcements/:id
// @access    Private
exports.getAnnouncement = async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id)
      .populate('author', 'firstName lastName username role department')
      .populate('viewers', 'firstName lastName username')
      .populate('comments.user', 'firstName lastName username');

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Check if user is authorized to view this announcement
    if (
      announcement.targetAudience.includes('all') ||
      announcement.targetAudience.includes(req.user.role) ||
      req.user.role === 'admin' ||
      announcement.author._id.toString() === req.user.id
    ) {
      // Mark as viewed by current user
      if (!announcement.viewers.includes(req.user.id)) {
        announcement.viewers.push(req.user.id);
        await announcement.save();
      }

      res.status(200).json({
        success: true,
        data: announcement
      });
    } else {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view this announcement'
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Create new announcement
// @route     POST /api/announcements
// @access    Private/Admin & Faculty
exports.createAnnouncement = async (req, res) => {
  try {
    // Add user ID to body
    req.body.author = req.user.id;

    // Set published status based on user role
    if (req.user.role === 'admin' || req.user.role === 'faculty') {
      req.body.isPublished = true;
      req.body.publishedAt = Date.now();
    } else {
      req.body.isPublished = false; // Will need approval
    }

    const announcement = await Announcement.create(req.body);

    res.status(201).json({
      success: true,
      data: announcement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Update announcement
// @route     PUT /api/announcements/:id
// @access    Private/Admin & Faculty (only authors can update their own)
exports.updateAnnouncement = async (req, res) => {
  try {
    let announcement = await Announcement.findById(req.params.id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Check if user is authorized to update
    if (req.user.role !== 'admin' && announcement.author.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this announcement'
      });
    }

    announcement = await Announcement.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true
    });

    res.status(200).json({
      success: true,
      data: announcement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Delete announcement
// @route     DELETE /api/announcements/:id
// @access    Private/Admin (only authors can delete their own)
exports.deleteAnnouncement = async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Check if user is authorized to delete
    if (req.user.role !== 'admin' && announcement.author.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this announcement'
      });
    }

    await Announcement.findByIdAndDelete(req.params.id);

    res.status(200).json({
      success: true,
      data: {}
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Publish announcement
// @route     PUT /api/announcements/publish/:id
// @access    Private/Admin & Faculty
exports.publishAnnouncement = async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Check if user is authorized to publish
    if (req.user.role !== 'admin' && req.user.role !== 'faculty') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to publish announcements'
      });
    }

    announcement.isPublished = true;
    announcement.publishedAt = Date.now();
    await announcement.save();

    res.status(200).json({
      success: true,
      data: announcement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Like announcement
// @route     PUT /api/announcements/like/:id
// @access    Private
exports.likeAnnouncement = async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Check if user has already liked
    if (announcement.likes.includes(req.user.id)) {
      // Unlike
      announcement.likes.pull(req.user.id);
    } else {
      // Like
      announcement.likes.push(req.user.id);
    }

    await announcement.save();

    res.status(200).json({
      success: true,
      data: announcement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};

// @desc      Add comment to announcement
// @route     POST /api/announcements/comment/:id
// @access    Private
exports.addComment = async (req, res) => {
  try {
    const announcement = await Announcement.findById(req.params.id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found'
      });
    }

    // Add comment
    const comment = {
      user: req.user.id,
      content: req.body.content
    };

    announcement.comments.unshift(comment);
    await announcement.save();

    // Populate the new comment
    await announcement.populate({
      path: 'comments.user',
      select: 'firstName lastName username'
    });

    res.status(200).json({
      success: true,
      data: announcement
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};