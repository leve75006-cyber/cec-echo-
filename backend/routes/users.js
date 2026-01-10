const express = require('express');
const router = express.Router();
const { getUsers, getUser, updateUser, deleteUser, getUsersByRole, toggleUserStatus } = require('../controllers/userController');
const { protect, authorize } = require('../middleware/auth');

router.route('/')
  .get(protect, authorize('admin'), getUsers);

router.route('/:id')
  .get(protect, authorize('admin'), getUser)
  .put(protect, authorize('admin'), updateUser)
  .delete(protect, authorize('admin'), deleteUser);

router.route('/role/:role')
  .get(protect, authorize('admin'), getUsersByRole);

router.route('/toggle-status/:id')
  .put(protect, authorize('admin'), toggleUserStatus);

module.exports = router;