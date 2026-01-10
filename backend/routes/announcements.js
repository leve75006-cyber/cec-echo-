const express = require('express');
const router = express.Router();
const { 
  getAnnouncements, 
  getAnnouncement, 
  createAnnouncement, 
  updateAnnouncement, 
  deleteAnnouncement, 
  publishAnnouncement,
  likeAnnouncement,
  addComment
} = require('../controllers/announcementController');
const { protect, authorize } = require('../middleware/auth');

router.route('/')
  .get(protect, getAnnouncements)
  .post(protect, createAnnouncement); // Only admin/faculty can create

router.route('/:id')
  .get(protect, getAnnouncement)
  .put(protect, updateAnnouncement) // Only admin/author can update
  .delete(protect, deleteAnnouncement); // Only admin/author can delete

router.route('/publish/:id')
  .put(protect, authorize('admin', 'faculty'), publishAnnouncement);

router.route('/like/:id')
  .put(protect, likeAnnouncement);

router.route('/comment/:id')
  .post(protect, addComment);

module.exports = router;