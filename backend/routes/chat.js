const express = require('express');
const router = express.Router();
const { 
  getMessages, 
  getDirectMessages, 
  getGroupMessages,
  sendMessage, 
  createGroup, 
  getGroups, 
  getGroup, 
  addMemberToGroup,
  initiateCall,
  updateCallStatus
} = require('../controllers/chatController');
const { protect } = require('../middleware/auth');

// Messages
router.route('/messages')
  .get(protect, getMessages)
  .post(protect, sendMessage);

router.route('/messages/:userId')
  .get(protect, getDirectMessages);

router.route('/messages/group/:groupId')
  .get(protect, getGroupMessages);

// Groups
router.route('/groups')
  .get(protect, getGroups)
  .post(protect, createGroup);

router.route('/groups/:id')
  .get(protect, getGroup);

router.route('/groups/add-member/:id')
  .put(protect, addMemberToGroup);

// Calls
router.route('/calls')
  .post(protect, initiateCall);

router.route('/calls/:id')
  .put(protect, updateCallStatus);

module.exports = router;
