const supabase = require('../config/supabase');

const USER_SELECT =
  'id,username,email,password,first_name,last_name,role,department,registration_number,is_active,last_login,profile_picture,created_at,updated_at';
const USER_PUBLIC_SELECT =
  'id,username,email,first_name,last_name,role,department,registration_number,is_active,last_login,profile_picture,created_at,updated_at';
const ANNOUNCEMENT_SELECT =
  'id,title,content,author,category,priority,target_audience,department,attachments,is_published,published_at,expires_at,viewers,likes,comments,created_at,updated_at';
const MESSAGE_SELECT =
  'id,sender,receiver,group_id,content,message_type,file_url,file_name,file_size,is_read,is_deleted,created_at,updated_at';
const GROUP_SELECT =
  'id,name,description,creator,members,admins,is_private,avatar,created_at,updated_at';
const CALL_SELECT =
  'id,caller,callee,group_id,call_type,meeting_id,status,start_time,end_time,duration,created_at,updated_at';
const STUDY_MATERIAL_SELECT =
  'id,title,description,course_code,subject_name,department,semester,material_type,resource_url,tags,is_published,uploaded_by,created_at,updated_at';

const throwOnError = (error) => {
  if (error) {
    throw new Error(error.message);
  }
};

const unique = (arr) => [...new Set(arr.filter(Boolean))];

const mapUser = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    username: row.username,
    email: row.email,
    password: row.password,
    firstName: row.first_name,
    lastName: row.last_name,
    role: row.role,
    department: row.department || '',
    registrationNumber: row.registration_number || '',
    isActive: row.is_active,
    lastLogin: row.last_login,
    profilePicture: row.profile_picture || '',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const mapAnnouncement = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    title: row.title,
    content: row.content,
    author: row.author,
    category: row.category,
    priority: row.priority,
    targetAudience: row.target_audience || [],
    department: row.department || '',
    attachments: row.attachments || [],
    isPublished: row.is_published,
    publishedAt: row.published_at,
    expiresAt: row.expires_at,
    viewers: row.viewers || [],
    likes: row.likes || [],
    comments: row.comments || [],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const mapMessage = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    sender: row.sender,
    receiver: row.receiver,
    groupId: row.group_id,
    content: row.content,
    messageType: row.message_type,
    fileUrl: row.file_url,
    fileName: row.file_name,
    fileSize: row.file_size,
    isRead: row.is_read,
    isDeleted: row.is_deleted,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const mapGroup = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    name: row.name,
    description: row.description || '',
    creator: row.creator,
    members: row.members || [],
    admins: row.admins || [],
    isPrivate: row.is_private,
    avatar: row.avatar || '',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const mapCall = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    caller: row.caller,
    callee: row.callee,
    groupId: row.group_id,
    callType: row.call_type,
    meetingId: row.meeting_id,
    status: row.status,
    startTime: row.start_time,
    endTime: row.end_time,
    duration: row.duration,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const mapStudyMaterial = (row) => {
  if (!row) return null;
  return {
    _id: row.id,
    id: row.id,
    title: row.title,
    description: row.description || '',
    courseCode: row.course_code,
    subjectName: row.subject_name || '',
    department: row.department || '',
    semester: row.semester || '',
    materialType: row.material_type,
    resourceUrl: row.resource_url || '',
    tags: row.tags || [],
    isPublished: row.is_published,
    uploadedBy: row.uploaded_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const fetchUsersByIds = async (ids, usePublic = true) => {
  const cleanIds = unique(ids);
  if (!cleanIds.length) return {};
  const select = usePublic ? USER_PUBLIC_SELECT : USER_SELECT;
  const { data, error } = await supabase.from('users').select(select).in('id', cleanIds);
  throwOnError(error);
  return (data || []).reduce((acc, row) => {
    const user = mapUser(row);
    acc[user.id] = user;
    return acc;
  }, {});
};

const enrichAnnouncements = async (announcements) => {
  const authorIds = announcements.map((a) => a.author);
  const viewerIds = announcements.flatMap((a) => a.viewers || []);
  const commentUserIds = announcements.flatMap((a) =>
    (a.comments || []).map((comment) => comment.user)
  );
  const userMap = await fetchUsersByIds([...authorIds, ...viewerIds, ...commentUserIds], true);
  return announcements.map((announcement) => ({
    ...announcement,
    author: userMap[announcement.author] || announcement.author,
    viewers: (announcement.viewers || []).map((id) => userMap[id] || { _id: id, id }),
    comments: (announcement.comments || []).map((comment) => ({
      ...comment,
      user: userMap[comment.user] || { _id: comment.user, id: comment.user },
    })),
  }));
};

const enrichMessages = async (messages) => {
  const senderIds = messages.map((m) => m.sender);
  const receiverIds = messages.map((m) => m.receiver);
  const userMap = await fetchUsersByIds([...senderIds, ...receiverIds], true);
  return messages.map((message) => ({
    ...message,
    sender: userMap[message.sender] || message.sender,
    receiver: message.receiver ? userMap[message.receiver] || message.receiver : null,
  }));
};

const enrichGroups = async (groups) => {
  const creatorIds = groups.map((g) => g.creator);
  const memberIds = groups.flatMap((g) => (g.members || []).map((member) => member.user));
  const userMap = await fetchUsersByIds([...creatorIds, ...memberIds], true);

  return groups.map((group) => ({
    ...group,
    creator: userMap[group.creator] || group.creator,
    members: (group.members || []).map((member) => ({
      ...member,
      user: userMap[member.user] || member.user,
    })),
  }));
};

const enrichCalls = async (calls) => {
  const callerIds = calls.map((c) => c.caller);
  const calleeIds = calls.map((c) => c.callee);
  const userMap = await fetchUsersByIds([...callerIds, ...calleeIds], true);
  const groups = await listGroups();
  const groupMap = groups.reduce((acc, group) => {
    acc[group.id] = group;
    return acc;
  }, {});
  return calls.map((call) => ({
    ...call,
    caller: userMap[call.caller] || call.caller,
    callee: call.callee ? userMap[call.callee] || call.callee : null,
    groupId: call.groupId ? groupMap[call.groupId] || call.groupId : null,
  }));
};

const listUsers = async (includePassword = false) => {
  const select = includePassword ? USER_SELECT : USER_PUBLIC_SELECT;
  const { data, error } = await supabase.from('users').select(select).order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapUser);
};

const getUserById = async (id, includePassword = false) => {
  const select = includePassword ? USER_SELECT : USER_PUBLIC_SELECT;
  const { data, error } = await supabase.from('users').select(select).eq('id', id).maybeSingle();
  throwOnError(error);
  return mapUser(data);
};

const findUserByEmail = async (email, includePassword = false) => {
  const select = includePassword ? USER_SELECT : USER_PUBLIC_SELECT;
  const { data, error } = await supabase
    .from('users')
    .select(select)
    .ilike('email', String(email).trim())
    .maybeSingle();
  throwOnError(error);
  return mapUser(data);
};

const findUserByUniqueFields = async ({ email, username, registrationNumber }) => {
  const users = await listUsers(true);
  const normalizedEmail = String(email || '').toLowerCase().trim();
  const normalizedUsername = String(username || '').trim();
  const normalizedRegNo = registrationNumber ? String(registrationNumber).trim() : '';
  return (
    users.find(
      (user) =>
        user.email.toLowerCase() === normalizedEmail ||
        user.username === normalizedUsername ||
        (normalizedRegNo && user.registrationNumber === normalizedRegNo)
    ) || null
  );
};

const createUser = async (payload) => {
  const insertPayload = {
    username: payload.username,
    email: payload.email,
    password: payload.password,
    first_name: payload.firstName,
    last_name: payload.lastName,
    role: payload.role || 'student',
    department: payload.department || '',
    registration_number: payload.registrationNumber || '',
    is_active: payload.isActive !== false,
    last_login: payload.lastLogin || null,
    profile_picture: payload.profilePicture || '',
  };
  const { data, error } = await supabase.from('users').insert(insertPayload).select(USER_SELECT).single();
  throwOnError(error);
  return mapUser(data);
};

const updateUser = async (id, payload, includePassword = false) => {
  const updatePayload = {};
  if (payload.username !== undefined) updatePayload.username = payload.username;
  if (payload.email !== undefined) updatePayload.email = payload.email;
  if (payload.password !== undefined) updatePayload.password = payload.password;
  if (payload.firstName !== undefined) updatePayload.first_name = payload.firstName;
  if (payload.lastName !== undefined) updatePayload.last_name = payload.lastName;
  if (payload.role !== undefined) updatePayload.role = payload.role;
  if (payload.department !== undefined) updatePayload.department = payload.department;
  if (payload.registrationNumber !== undefined) updatePayload.registration_number = payload.registrationNumber;
  if (payload.isActive !== undefined) updatePayload.is_active = payload.isActive;
  if (payload.lastLogin !== undefined) updatePayload.last_login = payload.lastLogin;
  if (payload.profilePicture !== undefined) updatePayload.profile_picture = payload.profilePicture;

  const select = includePassword ? USER_SELECT : USER_PUBLIC_SELECT;
  const { data, error } = await supabase
    .from('users')
    .update(updatePayload)
    .eq('id', id)
    .select(select)
    .maybeSingle();
  throwOnError(error);
  return mapUser(data);
};

const deleteUser = async (id) => {
  const { data, error } = await supabase.from('users').delete().eq('id', id).select(USER_PUBLIC_SELECT).maybeSingle();
  throwOnError(error);
  return mapUser(data);
};

const listAnnouncements = async () => {
  const { data, error } = await supabase
    .from('announcements')
    .select(ANNOUNCEMENT_SELECT)
    .order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapAnnouncement);
};

const getAnnouncementById = async (id) => {
  const { data, error } = await supabase
    .from('announcements')
    .select(ANNOUNCEMENT_SELECT)
    .eq('id', id)
    .maybeSingle();
  throwOnError(error);
  return mapAnnouncement(data);
};

const createAnnouncement = async (payload) => {
  const insertPayload = {
    title: payload.title,
    content: payload.content,
    author: payload.author,
    category: payload.category || 'general',
    priority: payload.priority || 'medium',
    target_audience: payload.targetAudience || ['all'],
    department: payload.department || '',
    attachments: payload.attachments || [],
    is_published: payload.isPublished || false,
    published_at: payload.publishedAt || null,
    expires_at: payload.expiresAt || null,
    viewers: payload.viewers || [],
    likes: payload.likes || [],
    comments: payload.comments || [],
  };
  const { data, error } = await supabase
    .from('announcements')
    .insert(insertPayload)
    .select(ANNOUNCEMENT_SELECT)
    .single();
  throwOnError(error);
  return mapAnnouncement(data);
};

const updateAnnouncement = async (id, payload) => {
  const updatePayload = {};
  if (payload.title !== undefined) updatePayload.title = payload.title;
  if (payload.content !== undefined) updatePayload.content = payload.content;
  if (payload.author !== undefined) updatePayload.author = payload.author;
  if (payload.category !== undefined) updatePayload.category = payload.category;
  if (payload.priority !== undefined) updatePayload.priority = payload.priority;
  if (payload.targetAudience !== undefined) updatePayload.target_audience = payload.targetAudience;
  if (payload.department !== undefined) updatePayload.department = payload.department;
  if (payload.attachments !== undefined) updatePayload.attachments = payload.attachments;
  if (payload.isPublished !== undefined) updatePayload.is_published = payload.isPublished;
  if (payload.publishedAt !== undefined) updatePayload.published_at = payload.publishedAt;
  if (payload.expiresAt !== undefined) updatePayload.expires_at = payload.expiresAt;
  if (payload.viewers !== undefined) updatePayload.viewers = payload.viewers;
  if (payload.likes !== undefined) updatePayload.likes = payload.likes;
  if (payload.comments !== undefined) updatePayload.comments = payload.comments;

  const { data, error } = await supabase
    .from('announcements')
    .update(updatePayload)
    .eq('id', id)
    .select(ANNOUNCEMENT_SELECT)
    .maybeSingle();
  throwOnError(error);
  return mapAnnouncement(data);
};

const deleteAnnouncement = async (id) => {
  const { data, error } = await supabase
    .from('announcements')
    .delete()
    .eq('id', id)
    .select(ANNOUNCEMENT_SELECT)
    .maybeSingle();
  throwOnError(error);
  return mapAnnouncement(data);
};

const listMessages = async () => {
  const { data, error } = await supabase.from('messages').select(MESSAGE_SELECT).order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapMessage);
};

const createMessage = async (payload) => {
  const insertPayload = {
    sender: payload.sender,
    receiver: payload.receiver || null,
    group_id: payload.groupId || null,
    content: payload.content,
    message_type: payload.messageType || 'text',
    file_url: payload.fileUrl || null,
    file_name: payload.fileName || null,
    file_size: payload.fileSize || null,
    is_read: payload.isRead || false,
    is_deleted: payload.isDeleted || false,
  };
  const { data, error } = await supabase.from('messages').insert(insertPayload).select(MESSAGE_SELECT).single();
  throwOnError(error);
  return mapMessage(data);
};

const updateMessages = async (filter, payload) => {
  let query = supabase.from('messages').update(payload);
  if (filter.receiver) query = query.eq('receiver', filter.receiver);
  if (filter.sender) query = query.eq('sender', filter.sender);
  if (filter.isRead !== undefined) query = query.eq('is_read', filter.isRead);
  const { error } = await query;
  throwOnError(error);
};

const listGroups = async () => {
  const { data, error } = await supabase.from('groups').select(GROUP_SELECT).order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapGroup);
};

const getGroupById = async (id) => {
  const { data, error } = await supabase.from('groups').select(GROUP_SELECT).eq('id', id).maybeSingle();
  throwOnError(error);
  return mapGroup(data);
};

const createGroup = async (payload) => {
  const insertPayload = {
    name: payload.name,
    description: payload.description || '',
    creator: payload.creator,
    members: payload.members || [],
    admins: payload.admins || [],
    is_private: payload.isPrivate || false,
    avatar: payload.avatar || '',
  };
  const { data, error } = await supabase.from('groups').insert(insertPayload).select(GROUP_SELECT).single();
  throwOnError(error);
  return mapGroup(data);
};

const updateGroup = async (id, payload) => {
  const updatePayload = {};
  if (payload.name !== undefined) updatePayload.name = payload.name;
  if (payload.description !== undefined) updatePayload.description = payload.description;
  if (payload.members !== undefined) updatePayload.members = payload.members;
  if (payload.admins !== undefined) updatePayload.admins = payload.admins;
  if (payload.isPrivate !== undefined) updatePayload.is_private = payload.isPrivate;
  if (payload.avatar !== undefined) updatePayload.avatar = payload.avatar;

  const { data, error } = await supabase.from('groups').update(updatePayload).eq('id', id).select(GROUP_SELECT).maybeSingle();
  throwOnError(error);
  return mapGroup(data);
};

const listCalls = async () => {
  const { data, error } = await supabase.from('calls').select(CALL_SELECT).order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapCall);
};

const getCallById = async (id) => {
  const { data, error } = await supabase.from('calls').select(CALL_SELECT).eq('id', id).maybeSingle();
  throwOnError(error);
  return mapCall(data);
};

const createCall = async (payload) => {
  const insertPayload = {
    caller: payload.caller,
    callee: payload.callee || null,
    group_id: payload.groupId || null,
    call_type: payload.callType || 'audio',
    meeting_id: payload.meetingId || null,
    status: payload.status || 'initiated',
    start_time: payload.startTime || null,
    end_time: payload.endTime || null,
    duration: payload.duration || null,
  };
  const { data, error } = await supabase.from('calls').insert(insertPayload).select(CALL_SELECT).single();
  throwOnError(error);
  return mapCall(data);
};

const updateCall = async (id, payload) => {
  const updatePayload = {};
  if (payload.status !== undefined) updatePayload.status = payload.status;
  if (payload.startTime !== undefined) updatePayload.start_time = payload.startTime;
  if (payload.endTime !== undefined) updatePayload.end_time = payload.endTime;
  if (payload.duration !== undefined) updatePayload.duration = payload.duration;
  if (payload.meetingId !== undefined) updatePayload.meeting_id = payload.meetingId;
  if (payload.callType !== undefined) updatePayload.call_type = payload.callType;
  if (payload.groupId !== undefined) updatePayload.group_id = payload.groupId;
  if (payload.callee !== undefined) updatePayload.callee = payload.callee;

  const { data, error } = await supabase.from('calls').update(updatePayload).eq('id', id).select(CALL_SELECT).maybeSingle();
  throwOnError(error);
  return mapCall(data);
};

const listStudyMaterials = async () => {
  const { data, error } = await supabase
    .from('study_materials')
    .select(STUDY_MATERIAL_SELECT)
    .order('created_at', { ascending: false });
  throwOnError(error);
  return (data || []).map(mapStudyMaterial);
};

module.exports = {
  supabase,
  listUsers,
  getUserById,
  findUserByEmail,
  findUserByUniqueFields,
  createUser,
  updateUser,
  deleteUser,
  listAnnouncements,
  getAnnouncementById,
  createAnnouncement,
  updateAnnouncement,
  deleteAnnouncement,
  enrichAnnouncements,
  listMessages,
  createMessage,
  updateMessages,
  enrichMessages,
  listGroups,
  getGroupById,
  createGroup,
  updateGroup,
  enrichGroups,
  listCalls,
  getCallById,
  createCall,
  updateCall,
  enrichCalls,
  listStudyMaterials,
  fetchUsersByIds,
};
