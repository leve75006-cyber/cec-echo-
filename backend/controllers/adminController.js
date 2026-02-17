const {
  listUsers,
  listAnnouncements,
  listMessages,
  listGroups,
  listCalls,
  enrichAnnouncements,
  enrichMessages,
  updateUser,
} = require('../utils/supabaseDb');

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
