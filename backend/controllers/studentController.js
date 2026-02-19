const {
  listAnnouncements,
  enrichAnnouncements,
  listGroups,
  enrichGroups,
  listMessages,
  enrichMessages,
  listUsers,
  getUserById,
  listStudyMaterials,
  createStudyMaterial: createStudyMaterialRecord,
} = require('../utils/supabaseDb');
const { ensureStudentInCecAssemble, cleanupExpiredStudentsFromCecAssemble } = require('../utils/defaultGroups');

const isStudentVisibleAnnouncement = (announcement, userDepartment) => {
  const audience = announcement.targetAudience || [];
  if (!announcement.isPublished) return false;
  if (audience.includes('all') || audience.includes('students')) return true;
  if (audience.includes('specific-dept') && announcement.department === userDepartment) return true;
  return false;
};

exports.getStudentAnnouncements = async (req, res) => {
  try {
    const announcements = await listAnnouncements();
    const filtered = announcements.filter((announcement) =>
      isStudentVisibleAnnouncement(announcement, req.user.department)
    );
    const populated = await enrichAnnouncements(filtered);

    return res.status(200).json({
      success: true,
      count: populated.length,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getStudentProfile = async (req, res) => {
  try {
    const [student, announcements, groups, messages] = await Promise.all([
      getUserById(req.user.id),
      listAnnouncements(),
      listGroups(),
      listMessages(),
    ]);

    const recentAnnouncements = announcements
      .filter((announcement) => (announcement.viewers || []).includes(req.user.id))
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
      .slice(0, 5);

    const userGroups = groups.filter((group) =>
      (group.members || []).some((member) => member.user === req.user.id)
    );
    const populatedGroups = await enrichGroups(userGroups);

    const recentMessages = await enrichMessages(
      messages
        .filter((message) => message.sender === req.user.id || message.receiver === req.user.id)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 10)
    );

    return res.status(200).json({
      success: true,
      data: {
        user: {
          ...student,
          sentMessages: recentMessages.filter((message) => message.sender.id === req.user.id),
          receivedMessages: recentMessages.filter((message) => message.receiver && message.receiver.id === req.user.id),
        },
        recentAnnouncements,
        groups: populatedGroups,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getStudentGroups = async (req, res) => {
  try {
    const groups = (await listGroups()).filter((group) =>
      (group.members || []).some((member) => member.user === req.user.id)
    );
    const populated = await enrichGroups(groups);

    return res.status(200).json({
      success: true,
      data: populated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getUnreadMessagesCount = async (req, res) => {
  try {
    const unreadCount = (await listMessages()).filter(
      (message) => message.receiver === req.user.id && !message.isRead
    ).length;

    return res.status(200).json({
      success: true,
      data: { unreadCount },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getStudentDashboard = async (req, res) => {
  try {
    await cleanupExpiredStudentsFromCecAssemble();
    if (req.user.role === 'student') {
      await ensureStudentInCecAssemble(req.user.id);
    }

    const [announcements, messages, groups] = await Promise.all([
      listAnnouncements(),
      listMessages(),
      listGroups(),
    ]);

    const visibleAnnouncements = announcements.filter((announcement) =>
      isStudentVisibleAnnouncement(announcement, req.user.department)
    );
    const unreadMessagesCount = messages.filter(
      (message) => message.receiver === req.user.id && !message.isRead
    ).length;
    const userGroups = groups.filter((group) =>
      (group.members || []).some((member) => member.user === req.user.id)
    );

    const recentAnnouncements = await enrichAnnouncements(
      visibleAnnouncements
        .slice()
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 5)
    );
    const recentMessages = await enrichMessages(
      messages
        .filter((message) => message.sender === req.user.id || message.receiver === req.user.id)
        .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
        .slice(0, 5)
    );

    return res.status(200).json({
      success: true,
      data: {
        stats: {
          totalAnnouncements: visibleAnnouncements.length,
          unreadMessages: unreadMessagesCount,
          totalGroups: userGroups.length,
        },
        recent: {
          announcements: recentAnnouncements,
          messages: recentMessages,
          groups: userGroups.slice(0, 5),
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

exports.getChatUsers = async (req, res) => {
  try {
    const users = (await listUsers(false))
      .filter((user) => user.id !== req.user.id && user.isActive)
      .sort((a, b) => `${a.firstName} ${a.lastName}`.localeCompare(`${b.firstName} ${b.lastName}`))
      .slice(0, 200);

    return res.status(200).json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.getStudyMaterialsByCourseCode = async (req, res) => {
  try {
    const courseCode = (req.params.courseCode || '').toUpperCase().trim();
    if (!courseCode) {
      return res.status(400).json({
        success: false,
        message: 'Course code is required',
      });
    }

    const materials = (await listStudyMaterials())
      .filter((material) => material.courseCode === courseCode && material.isPublished)
      .slice(0, 100);

    return res.status(200).json({
      success: true,
      count: materials.length,
      data: materials,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.createStudyMaterial = async (req, res) => {
  try {
    const title = (req.body?.title || '').trim();
    const courseCode = (req.body?.courseCode || '').toUpperCase().trim();

    if (!title || !courseCode) {
      return res.status(400).json({
        success: false,
        message: 'Title and courseCode are required',
      });
    }

    const material = await createStudyMaterialRecord({
      title,
      description: (req.body?.description || '').trim(),
      courseCode,
      subjectName: (req.body?.subjectName || '').trim(),
      department: (req.body?.department || req.user.department || '').trim(),
      semester: (req.body?.semester || '').trim(),
      materialType: (req.body?.materialType || 'notes').trim(),
      resourceUrl: (req.body?.resourceUrl || '').trim(),
      tags: Array.isArray(req.body?.tags)
        ? req.body.tags.map((t) => String(t).trim()).filter(Boolean)
        : [],
      isPublished: req.body?.isPublished !== false,
      uploadedBy: req.user.id,
    });

    return res.status(201).json({
      success: true,
      data: material,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
