const {
  listAnnouncements,
  getAnnouncementById,
  createAnnouncement,
  updateAnnouncement,
  deleteAnnouncement,
  enrichAnnouncements,
} = require('../utils/supabaseDb');

const canViewAnnouncement = (announcement, user) => {
  if (user.role === 'admin') return true;
  if (announcement.author === user.id) return true;
  const audience = announcement.targetAudience || [];
  if (audience.includes('all')) return true;
  if (user.role === 'student' && audience.includes('students')) return true;
  if (user.role === 'faculty' && (audience.includes('faculty') || audience.includes('students'))) return true;
  if (audience.includes('specific-dept') && announcement.department && announcement.department === user.department) return true;
  return false;
};

exports.getAnnouncements = async (req, res) => {
  try {
    const allAnnouncements = await listAnnouncements();
    const filtered = allAnnouncements.filter((announcement) => {
      if (!announcement.isPublished) return false;
      return canViewAnnouncement(announcement, req.user);
    });
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

exports.getAnnouncement = async (req, res) => {
  try {
    const announcement = await getAnnouncementById(req.params.id);
    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    if (!canViewAnnouncement(announcement, req.user)) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to view this announcement',
      });
    }

    const viewers = announcement.viewers || [];
    if (!viewers.includes(req.user.id)) {
      viewers.push(req.user.id);
      announcement.viewers = viewers;
      await updateAnnouncement(announcement.id, { viewers });
    }

    const populated = await enrichAnnouncements([announcement]);
    return res.status(200).json({
      success: true,
      data: populated[0],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.createAnnouncement = async (req, res) => {
  try {
    const payload = {
      ...req.body,
      author: req.user.id,
      isPublished: req.user.role === 'admin' || req.user.role === 'faculty',
      publishedAt:
        req.user.role === 'admin' || req.user.role === 'faculty' ? new Date().toISOString() : null,
    };

    const announcement = await createAnnouncement(payload);
    return res.status(201).json({
      success: true,
      data: announcement,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.updateAnnouncement = async (req, res) => {
  try {
    const existing = await getAnnouncementById(req.params.id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    if (req.user.role !== 'admin' && existing.author !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to update this announcement',
      });
    }

    const updated = await updateAnnouncement(req.params.id, req.body || {});
    return res.status(200).json({
      success: true,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.deleteAnnouncement = async (req, res) => {
  try {
    const existing = await getAnnouncementById(req.params.id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    if (req.user.role !== 'admin' && existing.author !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this announcement',
      });
    }

    await deleteAnnouncement(req.params.id);
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

exports.publishAnnouncement = async (req, res) => {
  try {
    const existing = await getAnnouncementById(req.params.id);
    if (!existing) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    if (req.user.role !== 'admin' && req.user.role !== 'faculty') {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to publish announcements',
      });
    }

    const updated = await updateAnnouncement(req.params.id, {
      isPublished: true,
      publishedAt: new Date().toISOString(),
    });
    return res.status(200).json({
      success: true,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.likeAnnouncement = async (req, res) => {
  try {
    const announcement = await getAnnouncementById(req.params.id);
    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    const likes = announcement.likes || [];
    if (likes.includes(req.user.id)) {
      announcement.likes = likes.filter((id) => id !== req.user.id);
    } else {
      likes.push(req.user.id);
      announcement.likes = likes;
    }

    const updated = await updateAnnouncement(req.params.id, { likes: announcement.likes });
    return res.status(200).json({
      success: true,
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

exports.addComment = async (req, res) => {
  try {
    const announcement = await getAnnouncementById(req.params.id);
    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    const comments = announcement.comments || [];
    comments.unshift({
      user: req.user.id,
      content: req.body.content,
      createdAt: new Date().toISOString(),
    });

    await updateAnnouncement(req.params.id, { comments });
    const refreshed = await getAnnouncementById(req.params.id);
    const populated = await enrichAnnouncements([refreshed]);

    return res.status(200).json({
      success: true,
      data: populated[0],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};
