const {
  listUsers,
  listAnnouncements,
  listMessages,
  listGroups,
  listCalls,
  enrichAnnouncements,
  enrichMessages,
  updateUser,
  createUser,
  deleteUser,
  findUserByUniqueFields,
} = require('../utils/supabaseDb');
const bcrypt = require('bcryptjs');
const {
  removeUserFromCecAssemble,
  cleanupExpiredStudentsFromCecAssemble,
} = require('../utils/defaultGroups');

exports.getDashboardStats = async (req, res) => {
  try {
    const [users, announcements, messages, groups, calls] = await Promise.all([
      listUsers(false),
      listAnnouncements(),
      listMessages(),
      listGroups(),
      listCalls(),
    ]);

    const recentUsers = users
      .slice()
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 5)
      .map((user) => ({
        _id: user.id,
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
      }));

    const recentAnnouncements = await enrichAnnouncements(
      announcements
        .slice()
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 5)
    );
    const recentMessages = await enrichMessages(
      messages
        .slice()
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 5)
    );

    return res.status(200).json({
      success: true,
      data: {
        stats: {
          totalUsers: users.length,
          activeUsers: users.filter((user) => user.isActive).length,
          totalAnnouncements: announcements.length,
          totalGroups: groups.length,
          totalMessages: messages.length,
          totalCalls: calls.length,
        },
        recentActivities: {
          recentUsers,
          recentAnnouncements,
          recentMessages,
        },
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getAllUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;
    const search = (req.query.search || '').toLowerCase().trim();

    let users = await listUsers(false);
    if (search) {
      users = users.filter((user) => {
        const haystack = [user.firstName, user.lastName, user.username, user.email].join(' ').toLowerCase();
        return haystack.includes(search);
      });
    }
    if (req.query.role) {
      users = users.filter((user) => user.role === req.query.role);
    }
    if (req.query.status) {
      const shouldBeActive = req.query.status === 'active';
      users = users.filter((user) => user.isActive === shouldBeActive);
    }

    const total = users.length;
    const pagedUsers = users.slice(skip, skip + limit);
    return res.status(200).json({
      success: true,
      data: {
        users: pagedUsers,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(total / limit),
          totalUsers: total,
          hasNext: page < Math.ceil(total / limit),
          hasPrev: page > 1,
        },
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getAllAnnouncements = async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const limit = parseInt(req.query.limit, 10) || 10;
    const skip = (page - 1) * limit;
    const search = (req.query.search || '').toLowerCase().trim();

    let announcements = await listAnnouncements();
    if (search) {
      announcements = announcements.filter((announcement) =>
        `${announcement.title} ${announcement.content}`.toLowerCase().includes(search)
      );
    }
    if (req.query.category) {
      announcements = announcements.filter((announcement) => announcement.category === req.query.category);
    }
    if (req.query.priority) {
      announcements = announcements.filter((announcement) => announcement.priority === req.query.priority);
    }
    if (req.query.status) {
      const shouldBePublished = req.query.status === 'published';
      announcements = announcements.filter((announcement) => announcement.isPublished === shouldBePublished);
    }

    const total = announcements.length;
    const paged = announcements.slice(skip, skip + limit);
    const populated = await enrichAnnouncements(paged);

    return res.status(200).json({
      success: true,
      data: {
        announcements: populated,
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(total / limit),
          totalAnnouncements: total,
          hasNext: page < Math.ceil(total / limit),
          hasPrev: page > 1,
        },
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateUserRole = async (req, res) => {
  try {
    const { role } = req.body;
    const validRoles = ['student', 'faculty', 'admin'];

    if (!validRoles.includes(role)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid role specified',
      });
    }

    const user = await updateUser(req.params.id, { role });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.createFaculty = async (req, res) => {
  try {
    const { username, email, password, firstName, lastName, department, registrationNumber } = req.body || {};

    if (!username || !email || !password || !firstName || !lastName) {
      return res.status(400).json({
        success: false,
        message: 'username, email, password, firstName, and lastName are required',
      });
    }

    const duplicate = await findUserByUniqueFields({ email, username, registrationNumber });
    if (duplicate) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email, username or registration number',
      });
    }

    const hashedPassword = await bcrypt.hash(String(password), 10);
    const faculty = await createUser({
      username: String(username).trim(),
      email: String(email).trim().toLowerCase(),
      password: hashedPassword,
      firstName: String(firstName).trim(),
      lastName: String(lastName).trim(),
      role: 'faculty',
      department: department ? String(department).trim() : '',
      registrationNumber: registrationNumber ? String(registrationNumber).trim() : '',
      isActive: true,
    });

    return res.status(201).json({
      success: true,
      data: faculty,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.deleteFaculty = async (req, res) => {
  try {
    const users = await listUsers(false);
    const faculty = users.find((user) => user.id === req.params.id);

    if (!faculty) {
      return res.status(404).json({
        success: false,
        message: 'Faculty not found',
      });
    }
    if (faculty.role !== 'faculty') {
      return res.status(400).json({
        success: false,
        message: 'Target user is not a faculty',
      });
    }

    await deleteUser(faculty.id);
    await removeUserFromCecAssemble(faculty.id);

    return res.status(200).json({
      success: true,
      data: {},
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.deleteStudentByRegNo = async (req, res) => {
  try {
    const registrationNumber = String(req.params.registrationNumber || '').trim().toUpperCase();
    if (!registrationNumber) {
      return res.status(400).json({
        success: false,
        message: 'Registration number is required',
      });
    }

    const users = await listUsers(false);
    const student = users.find(
      (user) =>
        user.role === 'student' &&
        String(user.registrationNumber || '').trim().toUpperCase() === registrationNumber
    );

    if (!student) {
      return res.status(404).json({
        success: false,
        message: 'Student not found for the provided registration number',
      });
    }

    await deleteUser(student.id);
    await removeUserFromCecAssemble(student.id);

    return res.status(200).json({
      success: true,
      data: {},
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.cleanupExpiredCecStudents = async (req, res) => {
  try {
    const result = await cleanupExpiredStudentsFromCecAssemble();
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
