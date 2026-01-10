const express = require('express');
const router = express.Router();
const { 
  getStudentAnnouncements,
  getStudentProfile,
  getStudentGroups,
  getUnreadMessagesCount,
  getStudentDashboard
} = require('../controllers/studentController');
const { protect, authorize } = require('../middleware/auth');

// All routes in this file are protected and require student, faculty, or admin role
router.use(protect);

router.route('/announcements')
  .get(getStudentAnnouncements);

router.route('/profile')
  .get(getStudentProfile);

router.route('/groups')
  .get(getStudentGroups);

router.route('/unread-count')
  .get(getUnreadMessagesCount);

router.route('/dashboard')
  .get(getStudentDashboard);

module.exports = router;