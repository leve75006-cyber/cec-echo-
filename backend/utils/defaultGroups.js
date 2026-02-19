const { listGroups, createGroup, updateGroup, getUserById, fetchUsersByIds } = require('./supabaseDb');

const CEC_ASSEMBLE_NAME = 'CEC ASSEMBLE';
const COURSE_DURATION_YEARS = 4;

const parseAdmissionYear = (registrationNumber) => {
  const raw = String(registrationNumber || '').trim().toUpperCase();
  if (!raw) return null;
  const match = raw.match(/^[A-Z]+(\d{2})/);
  if (!match) return null;
  const yy = Number(match[1]);
  if (Number.isNaN(yy)) return null;
  return 2000 + yy;
};

const isRegistrationExpired = (registrationNumber, now = new Date()) => {
  const admissionYear = parseAdmissionYear(registrationNumber);
  if (!admissionYear) {
    return false;
  }
  const graduationYear = admissionYear + COURSE_DURATION_YEARS;
  return now.getUTCFullYear() > graduationYear;
};

const findCecAssembleGroup = async () => {
  const groups = await listGroups();
  return (
    groups.find(
      (group) => String(group.name || '').trim().toLowerCase() === CEC_ASSEMBLE_NAME.toLowerCase()
    ) || null
  );
};

const ensureCecAssembleGroup = async (creatorId) => {
  const existing = await findCecAssembleGroup();
  if (existing) {
    return existing;
  }

  return createGroup({
    name: CEC_ASSEMBLE_NAME,
    description: 'Default community group for all CEC ECHO students.',
    creator: creatorId,
    members: [
      {
        user: creatorId,
        role: 'admin',
        joinedAt: new Date().toISOString(),
      },
    ],
    admins: [creatorId],
    isPrivate: false,
  });
};

const ensureStudentInCecAssemble = async (studentUserId) => {
  if (!studentUserId) {
    return null;
  }

  const student = await getUserById(studentUserId);
  if (!student || student.role !== 'student') {
    return null;
  }

  const group = await ensureCecAssembleGroup(studentUserId);
  const members = group.members || [];
  const alreadyMember = members.some((member) => member.user === student.id);
  const expired = isRegistrationExpired(student.registrationNumber);

  if (expired) {
    if (!alreadyMember) {
      return group;
    }
    const filteredMembers = members.filter((member) => member.user !== student.id);
    return updateGroup(group.id, { members: filteredMembers });
  }

  if (alreadyMember) {
    return group;
  }

  const updatedMembers = [
    ...members,
    {
      user: student.id,
      role: 'member',
      joinedAt: new Date().toISOString(),
    },
  ];

  return updateGroup(group.id, { members: updatedMembers });
};

const removeUserFromCecAssemble = async (userId) => {
  if (!userId) return null;
  const group = await findCecAssembleGroup();
  if (!group) return null;
  const members = group.members || [];
  const exists = members.some((member) => member.user === userId);
  if (!exists) return group;
  const filteredMembers = members.filter((member) => member.user !== userId);
  return updateGroup(group.id, { members: filteredMembers });
};

const cleanupExpiredStudentsFromCecAssemble = async () => {
  const group = await findCecAssembleGroup();
  if (!group) {
    return { groupFound: false, removedCount: 0 };
  }

  const members = group.members || [];
  if (!members.length) {
    return { groupFound: true, removedCount: 0 };
  }

  const userIds = members.map((member) => member.user);
  const userMap = await fetchUsersByIds(userIds, true);

  const keptMembers = [];
  let removedCount = 0;

  for (const member of members) {
    const user = userMap[member.user];
    if (user && user.role === 'student' && isRegistrationExpired(user.registrationNumber)) {
      removedCount += 1;
      continue;
    }
    keptMembers.push(member);
  }

  if (removedCount > 0) {
    await updateGroup(group.id, { members: keptMembers });
  }

  return { groupFound: true, removedCount };
};

module.exports = {
  CEC_ASSEMBLE_NAME,
  isRegistrationExpired,
  ensureStudentInCecAssemble,
  removeUserFromCecAssemble,
  cleanupExpiredStudentsFromCecAssemble,
};
