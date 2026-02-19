const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const {
  getUserById,
  findUserByEmail,
  findUserByUniqueFields,
  createUser,
  updateUser,
} = require('../utils/supabaseDb');
const { ensureStudentInCecAssemble } = require('../utils/defaultGroups');

const ALLOWED_SELF_REGISTER_ROLES = ['student', 'faculty'];

const toPublicUser = (user) => ({
  id: user._id || user.id,
  _id: user._id || user.id,
  username: user.username,
  email: user.email,
  firstName: user.firstName,
  lastName: user.lastName,
  role: user.role,
  department: user.department,
  registrationNumber: user.registrationNumber,
  isActive: user.isActive,
  profilePicture: user.profilePicture,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
});

const generateToken = (id) =>
  jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE,
  });

exports.register = async (req, res) => {
  try {
    const { username, email, password, firstName, lastName, role, department, registrationNumber } = req.body;

    if (!username || !email || !password || !firstName || !lastName) {
      return res.status(400).json({
        success: false,
        message: 'Please provide username, firstName, lastName, email and password',
      });
    }

    const duplicate = await findUserByUniqueFields({ email, username, registrationNumber });
    if (duplicate) {
      return res.status(400).json({
        success: false,
        message: 'User already exists with this email, username or registration number',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const requestedRole = String(role || 'student').toLowerCase();
    if (!ALLOWED_SELF_REGISTER_ROLES.includes(requestedRole)) {
      return res.status(400).json({
        success: false,
        message: 'Role is not allowed for self registration',
      });
    }

    const user = await createUser({
      username: String(username).trim(),
      email: String(email).trim().toLowerCase(),
      password: hashedPassword,
      firstName: String(firstName).trim(),
      lastName: String(lastName).trim(),
      role: requestedRole,
      department: department ? String(department).trim() : '',
      registrationNumber: registrationNumber ? String(registrationNumber).trim() : '',
      isActive: true,
    });

    if (user.role === 'student') {
      await ensureStudentInCecAssemble(user.id);
    }

    const token = generateToken(user.id);
    res.cookie('token', token, {
      expires: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
    });

    return res.status(201).json({
      success: true,
      token,
      user: toPublicUser(user),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email and password',
      });
    }

    const user = await findUserByEmail(String(email).trim().toLowerCase(), true);
    if (!user || !(await bcrypt.compare(password, user.password || ''))) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password',
      });
    }

    if (!user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Account is deactivated. Please contact administrator.',
      });
    }

    const updatedUser = await updateUser(user.id, { lastLogin: new Date().toISOString() });

    if (user.role === 'student') {
      await ensureStudentInCecAssemble(user.id);
    }

    const token = generateToken(user.id);

    return res.status(200).json({
      success: true,
      token,
      user: toPublicUser(updatedUser || user),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.logout = async (req, res) => {
  res.cookie('token', '', {
    expires: new Date(Date.now() + 10 * 1000),
    httpOnly: true,
  });

  return res.status(200).json({
    success: true,
    message: 'Logged out successfully',
  });
};

exports.getMe = async (req, res) => {
  try {
    const user = await getUserById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    return res.status(200).json({
      success: true,
      user: toPublicUser(user),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateMe = async (req, res) => {
  try {
    const allowedFields = ['firstName', 'lastName', 'email', 'department', 'profilePicture'];
    const updates = {};
    for (const field of Object.keys(req.body || {})) {
      if (allowedFields.includes(field)) {
        updates[field] = req.body[field];
      }
    }

    const user = await updateUser(req.user.id, updates);
    return res.status(200).json({
      success: true,
      user: toPublicUser(user),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updatePassword = async (req, res) => {
  try {
    const user = await getUserById(req.user.id, true);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    if (!(await bcrypt.compare(req.body.currentPassword, user.password || ''))) {
      return res.status(401).json({
        success: false,
        message: 'Current password is incorrect',
      });
    }

    const newPassword = await bcrypt.hash(req.body.newPassword, 10);
    await updateUser(req.user.id, { password: newPassword }, true);
    const token = generateToken(req.user.id);

    return res.status(200).json({
      success: true,
      token,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
