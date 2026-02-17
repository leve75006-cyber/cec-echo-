const jwt = require('jsonwebtoken');
const { getUserById } = require('../utils/supabaseDb');

const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    try {
      token = req.headers.authorization.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await getUserById(decoded.id);

      if (!user || !user.isActive) {
        return res.status(401).json({ message: 'Not authorized, user not found or inactive' });
      }

      req.user = {
        id: user.id,
        _id: user.id,
        role: user.role,
        department: user.department,
        isActive: user.isActive,
        firstName: user.firstName,
        lastName: user.lastName,
        username: user.username,
        email: user.email,
        profilePicture: user.profilePicture,
      };
      return next();
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        return res.status(401).json({ message: 'Token expired, please log in again' });
      }
      return res.status(401).json({ message: 'Not authorized, token failed' });
    }
  }

  return res.status(401).json({ message: 'Not authorized, no token' });
};

const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user.role)) {
    return res.status(403).json({
      message: `User role '${req.user.role}' is not authorized to access this route. Please contact admin.`,
    });
  }
  return next();
};

module.exports = { protect, authorize };
