const express = require('express');
const router = express.Router();
const { 
  getDashboardStats, 
  getAllUsers, 
  getAllAnnouncements, 
  updateUserRole,
  createFaculty,
  deleteFaculty,
  deleteStudentByRegNo,
  cleanupExpiredCecStudents,
} = require('../controllers/adminController');
const { protect, authorize } = require('../middleware/auth');

// All routes in this file are protected and require admin role
router.use(protect);
router.use(authorize('admin'));

router.route('/dashboard')
  .get(getDashboardStats);

router.route('/users')
  .get(getAllUsers);

router.route('/announcements')
  .get(getAllAnnouncements);

router.route('/users/role/:id')
  .put(updateUserRole);

router.route('/faculty')
  .post(createFaculty);

router.route('/faculty/:id')
  .delete(deleteFaculty);

router.route('/students/by-reg/:registrationNumber')
  .delete(deleteStudentByRegNo);

router.route('/groups/cec-assemble/cleanup')
  .post(cleanupExpiredCecStudents);

module.exports = router;
