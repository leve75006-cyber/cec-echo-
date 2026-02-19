import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/announcement.dart';
import '../../models/call_invite.dart';
import '../../models/message.dart';
import '../../models/study_material.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';

Uint8List? _decodeDataUriBytesGlobal(String dataUri) {
  final index = dataUri.indexOf(',');
  if (index == -1) {
    return null;
  }
  final payload = dataUri.substring(index + 1);
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

ImageProvider<Object>? _profileImageProvider(String? profilePicture) {
  final raw = (profilePicture ?? '').trim();
  if (raw.isEmpty) {
    return null;
  }
  if (raw.startsWith('data:image/')) {
    final bytes = _decodeDataUriBytesGlobal(raw);
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    return null;
  }
  return NetworkImage(raw);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _bootstrapped = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final home = context.read<HomeProvider>();
      final user = auth.user;
      if (user != null) {
        await home.initialize(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final homeProvider = context.watch<HomeProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final user = authProvider.user;

    final pages = [
      DashboardPage(
        userName: user?.firstName ?? 'User',
        stats: homeProvider.dashboardStats,
        onQuickAction: _onQuickAction,
      ),
      AnnouncementsPage(
        announcements: homeProvider.announcements,
        onRefresh: homeProvider.refreshAnnouncements,
        onOpen: _openAnnouncement,
        onEnterBroadcasts: _openBroadcasts,
        canPostCircular: _canPostCircular(user?.role),
        onPostCircular: () => _openPostCircularDialog(defaultCategory: 'general'),
      ),
      InternshipPlacementPage(
        announcements: homeProvider.announcements,
        onRefresh: homeProvider.refreshAnnouncements,
        onOpen: _openAnnouncement,
        canPostCircular: _canPostCircular(user?.role),
        onPostCircular: () => _openPostCircularDialog(defaultCategory: 'internship'),
      ),
      ChatPage(
        currentUser: user,
        contacts: homeProvider.contacts,
        groups: homeProvider.groups,
        allUsers: homeProvider.allUsers,
        messages: homeProvider.messages,
        incomingCalls: homeProvider.incomingCalls,
        outgoingCalls: homeProvider.outgoingCalls,
        onRefresh: homeProvider.refreshAll,
        onOpenChat: _openChat,
        onStartChat: _openStartChatPicker,
        onCreateGroup: _openCreateGroupDialog,
        onOpenGroupChat: _openGroupChat,
        onStartMeeting: _openMeetingInviteDialog,
        onAcceptCall: homeProvider.acceptCall,
        onRejectCall: homeProvider.rejectCall,
        onEndCall: homeProvider.endCall,
      ),
      ProfilePage(
        onEditProfile: _openEditProfileDialog,
        onEditPhoto: _openEditPhotoDialog,
        onPrivacy: _openChangePasswordDialog,
        onHelp: _openHelpSupportDialog,
        onUploadNotes: _openUploadNotesDialog,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('CEC ECHO', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: themeProvider.isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(
              themeProvider.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: _showNotifications,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'refresh', child: Text('Refresh Data')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            onSelected: (value) async {
              final home = context.read<HomeProvider>();
              if (value == 'settings') {
                _showSettings();
              }
              if (value == 'refresh') {
                await home.refreshAll();
                if (!mounted) {
                  return;
                }
              }
              if (value == 'logout') {
                home.clearSession();
                await authProvider.logout();
              }
            },
          ),
        ],
      ),
      body: homeProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: pages[_selectedIndex],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Announcements'),
          NavigationDestination(icon: Icon(Icons.work_outline_rounded), label: 'Internships'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: user?.role == 'faculty'
          ? null
          : FloatingActionButton.extended(
              onPressed: _openExamTopicsChatbot,
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Exam Bot'),
            ),
    );
  }

  void _openBroadcasts() {
    setState(() => _selectedIndex = 3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open Meeting Invites in Chats to join faculty broadcasts.'),
      ),
    );
  }

  bool _canPostCircular(String? role) {
    return role == 'admin' || role == 'faculty';
  }

  void _onQuickAction(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 1);
      return;
    }
    if (index == 1) {
      setState(() => _selectedIndex = 3);
      return;
    }
    if (index == 2) {
      setState(() => _selectedIndex = 2);
      return;
    }
    _openStudyMaterialsDialog();
  }

  Future<void> _showNotifications() async {
    final home = context.read<HomeProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final items = home.announcements.take(8).toList();
        if (items.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No new notifications.')),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final a = items[index];
            return ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(a.content, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                _openAnnouncement(a);
              },
            );
          },
        );
      },
    );
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: const Text('Live data is enabled via API + Socket.IO. Use Refresh Data to sync immediately.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Future<void> _openAnnouncement(Announcement announcement) async {
    final commentController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Consumer2<HomeProvider, AuthProvider>(
          builder: (context, home, auth, _) {
            final refreshed = home.announcements.firstWhere(
              (a) => a.id == announcement.id,
              orElse: () => announcement,
            );
            final likedByMe = auth.user != null && refreshed.likes.any((u) => u.id == auth.user!.id);

            return AlertDialog(
              title: Text(refreshed.title),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(refreshed.content),
                    if ((refreshed.attachments ?? []).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._buildAnnouncementAttachmentTiles(refreshed.attachments ?? const []),
                    ],
                    const SizedBox(height: 12),
                    Text('Likes: ${refreshed.likes.length} | Comments: ${refreshed.comments.length}'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      decoration: const InputDecoration(labelText: 'Add a comment'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await home.toggleLike(refreshed.id);
                  },
                  child: Text(likedByMe ? 'Unlike' : 'Like'),
                ),
                TextButton(
                  onPressed: () async {
                    await home.addComment(refreshed.id, commentController.text);
                    commentController.clear();
                  },
                  child: const Text('Comment'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPostCircularDialog({
    required String defaultCategory,
  }) async {
    final home = context.read<HomeProvider>();
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final attachments = <Map<String, String>>[];
    var category = defaultCategory;
    var priority = 'medium';
    var pickType = 'image';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> addAttachment() async {
              final picked = await _pickMediaByType(pickType);
              if (picked == null) {
                return;
              }
              setStateDialog(() {
                attachments.add({
                  'type': pickType,
                  'name': picked.$2,
                  'dataUrl': picked.$1,
                });
              });
            }

            Future<void> submit() async {
              final ok = await home.createAnnouncementCircular(
                title: titleController.text,
                content: contentController.text,
                category: category,
                priority: priority,
                attachments: attachments,
              );
              if (!mounted) {
                return;
              }
              final messenger = ScaffoldMessenger.of(this.context);
              if (!ok) {
                messenger.showSnackBar(
                  SnackBar(content: Text(home.error ?? 'Unable to post circular')),
                );
                return;
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('Circular posted successfully')),
              );
            }

            return AlertDialog(
              title: const Text('Post Circular'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: contentController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Content'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('General')),
                          DropdownMenuItem(value: 'internship', child: Text('Internship')),
                          DropdownMenuItem(value: 'placement', child: Text('Placement')),
                          DropdownMenuItem(value: 'academic', child: Text('Academic')),
                          DropdownMenuItem(value: 'event', child: Text('Event')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setStateDialog(() => category = value);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setStateDialog(() => priority = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text('Attachments'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Image'),
                            selected: pickType == 'image',
                            onSelected: (_) => setStateDialog(() => pickType = 'image'),
                          ),
                          ChoiceChip(
                            label: const Text('Video'),
                            selected: pickType == 'video',
                            onSelected: (_) => setStateDialog(() => pickType = 'video'),
                          ),
                          ChoiceChip(
                            label: const Text('File'),
                            selected: pickType == 'file',
                            onSelected: (_) => setStateDialog(() => pickType = 'file'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: addAttachment,
                        icon: const Icon(Icons.attachment_rounded),
                        label: const Text('Add Attachment'),
                      ),
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item['type'] == 'image'
                                  ? Icons.image_outlined
                                  : item['type'] == 'video'
                                      ? Icons.videocam_outlined
                                      : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(item['name'] ?? 'Attachment'),
                            subtitle: Text((item['type'] ?? 'file').toUpperCase()),
                            trailing: IconButton(
                              onPressed: () {
                                setStateDialog(() => attachments.removeAt(index));
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Post'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildAnnouncementAttachmentTiles(List<dynamic> attachments) {
    return attachments.asMap().entries.map((entry) {
      final item = entry.value;
      final type = _attachmentType(item);
      final label = _attachmentName(item, entry.key + 1);
      final data = _attachmentData(item);
      if (type == 'image' && data.startsWith('data:image/')) {
        final bytes = _decodeDataUriBytes(data);
        if (bytes != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                bytes,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      }

      final icon = type == 'video'
          ? Icons.videocam_outlined
          : type == 'image'
              ? Icons.image_outlined
              : Icons.insert_drive_file_outlined;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${type.toUpperCase()}: $label')),
          ],
        ),
      );
    }).toList();
  }

  String _attachmentType(dynamic raw) {
    if (raw is Map) {
      return (raw['type']?.toString() ?? 'file').toLowerCase();
    }
    return 'file';
  }

  String _attachmentName(dynamic raw, int fallbackIndex) {
    if (raw is Map) {
      final value = raw['name']?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return 'Attachment $fallbackIndex';
  }

  String _attachmentData(dynamic raw) {
    if (raw is Map) {
      final dataUrl = raw['dataUrl']?.toString() ?? '';
      if (dataUrl.isNotEmpty) {
        return dataUrl;
      }
      final url = raw['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        return url;
      }
    }
    return '';
  }

  Future<void> _openChat(User contact) async {
    final home = context.read<HomeProvider>();
    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current == null) {
      return;
    }

    final sendController = TextEditingController();
    String? pickedMediaDataUri;
    String? pickedFileName;
    var messageType = 'text';
    var thread = await home.getDirectMessages(contact.id);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> send() async {
              String text = sendController.text.trim();
              if (text.isEmpty && messageType != 'text') {
                text = _defaultMediaCaption(messageType);
              }
              final ok = await home.sendDirectMessage(
                receiverId: contact.id,
                content: text,
                messageType: messageType,
                fileUrl: pickedMediaDataUri,
                fileName: pickedFileName,
              );
              if (!ok) {
                return;
              }
              sendController.clear();
              pickedMediaDataUri = null;
              pickedFileName = null;
              messageType = 'text';
              thread = await home.getDirectMessages(contact.id);
              setStateDialog(() {});
            }

            Future<void> pickAttachment() async {
              final picked = await _pickMediaByType(messageType);
              if (picked == null) {
                return;
              }
              setStateDialog(() {
                pickedMediaDataUri = picked.$1;
                pickedFileName = picked.$2;
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${contact.firstName} ${contact.lastName}'.trim()),
                        Text(
                          '@${contact.username}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 320,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: thread.isEmpty
                          ? const Center(child: Text('No messages yet'))
                          : ListView.builder(
                              reverse: true,
                              itemCount: thread.length,
                              itemBuilder: (context, index) {
                                final msg = thread[index];
                                final mine = msg.sender?.id == current.id;
                                return _buildWhatsAppBubble(
                                  context: context,
                                  msg: msg,
                                  mine: mine,
                                  showSender: !mine,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Text'),
                          selected: messageType == 'text',
                          onSelected: (_) => setStateDialog(() => messageType = 'text'),
                        ),
                        ChoiceChip(
                          label: const Text('Image'),
                          selected: messageType == 'image',
                          onSelected: (_) => setStateDialog(() => messageType = 'image'),
                        ),
                        ChoiceChip(
                          label: const Text('Video'),
                          selected: messageType == 'video',
                          onSelected: (_) => setStateDialog(() => messageType = 'video'),
                        ),
                        ChoiceChip(
                          label: const Text('File'),
                          selected: messageType == 'file',
                          onSelected: (_) => setStateDialog(() => messageType = 'file'),
                        ),
                      ],
                    ),
                    if (messageType != 'text') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pickedFileName == null
                                  ? 'No attachment selected'
                                  : 'Selected: $pickedFileName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: pickAttachment,
                            icon: const Icon(Icons.attachment_rounded),
                            label: const Text('Pick'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sendController,
                            decoration: const InputDecoration(labelText: 'Type message'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openGroupChat(Group group) async {
    final home = context.read<HomeProvider>();
    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current == null) {
      return;
    }

    final sendController = TextEditingController();
    String? pickedMediaDataUri;
    String? pickedFileName;
    var messageType = 'text';
    var thread = await home.getGroupMessages(group.id);
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> send() async {
              String text = sendController.text.trim();
              if (text.isEmpty && messageType != 'text') {
                text = _defaultMediaCaption(messageType);
              }
              final ok = await home.sendGroupMessage(
                groupId: group.id,
                content: text,
                messageType: messageType,
                fileUrl: pickedMediaDataUri,
                fileName: pickedFileName,
              );
              if (!ok) {
                return;
              }
              sendController.clear();
              pickedMediaDataUri = null;
              pickedFileName = null;
              messageType = 'text';
              thread = await home.getGroupMessages(group.id);
              setStateDialog(() {});
            }

            Future<void> pickAttachment() async {
              final picked = await _pickMediaByType(messageType);
              if (picked == null) {
                return;
              }
              setStateDialog(() {
                pickedMediaDataUri = picked.$1;
                pickedFileName = picked.$2;
              });
            }

            Future<void> addFriends() async {
              await _openAddFriendsDialog(group);
              thread = await home.getGroupMessages(group.id);
              setStateDialog(() {});
            }

            return AlertDialog(
              title: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.group_rounded)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(group.name),
                        Text(
                          '${group.members.length} members',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 320,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: thread.isEmpty
                          ? const Center(child: Text('No group messages yet'))
                          : ListView.builder(
                              reverse: true,
                              itemCount: thread.length,
                              itemBuilder: (context, index) {
                                final msg = thread[index];
                                final mine = msg.sender?.id == current.id;
                                return _buildWhatsAppBubble(
                                  context: context,
                                  msg: msg,
                                  mine: mine,
                                  showSender: !mine,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Text'),
                          selected: messageType == 'text',
                          onSelected: (_) => setStateDialog(() => messageType = 'text'),
                        ),
                        ChoiceChip(
                          label: const Text('Image'),
                          selected: messageType == 'image',
                          onSelected: (_) => setStateDialog(() => messageType = 'image'),
                        ),
                        ChoiceChip(
                          label: const Text('Video'),
                          selected: messageType == 'video',
                          onSelected: (_) => setStateDialog(() => messageType = 'video'),
                        ),
                        ChoiceChip(
                          label: const Text('File'),
                          selected: messageType == 'file',
                          onSelected: (_) => setStateDialog(() => messageType = 'file'),
                        ),
                      ],
                    ),
                    if (messageType != 'text') ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pickedFileName == null
                                  ? 'No attachment selected'
                                  : 'Selected: $pickedFileName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: pickAttachment,
                            icon: const Icon(Icons.attachment_rounded),
                            label: const Text('Pick'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sendController,
                            decoration: const InputDecoration(labelText: 'Type message'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: addFriends,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Add Friends'),
                ),
                TextButton.icon(
                  onPressed: () => home.startGroupVoiceChat(group.id),
                  icon: const Icon(Icons.call),
                  label: const Text('Voice Chat'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAddFriendsDialog(Group group) async {
    final home = context.read<HomeProvider>();
    await home.refreshUsers();
    await home.refreshGroups();
    if (!mounted) {
      return;
    }

    final currentGroup = home.groups.firstWhere(
      (g) => g.id == group.id,
      orElse: () => group,
    );
    final existingIds = currentGroup.members.map((m) => m.user.id).toSet();
    final users = home.allUsers
        .where((u) => u.role == 'student' && !existingIds.contains(u.id))
        .toList();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> addNow() async {
              final ok = await home.addMembersToGroup(
                group: currentGroup,
                userIds: selected.toList(),
              );
              if (!context.mounted) {
                return;
              }
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Some contacts could not be added.')),
                );
              }
              Navigator.pop(context);
            }

            return AlertDialog(
              title: Text('Add Friends to ${currentGroup.name}'),
              content: SizedBox(
                width: 420,
                height: 380,
                child: users.isEmpty
                    ? const Center(child: Text('No more contacts available to add.'))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final checked = selected.contains(user.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  selected.add(user.id);
                                } else {
                                  selected.remove(user.id);
                                }
                              });
                            },
                            title: Text('${user.firstName} ${user.lastName}'.trim()),
                            subtitle: Text('@${user.username}'),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selected.isEmpty ? null : addNow,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateGroupDialog() async {
    final home = context.read<HomeProvider>();
    await home.refreshUsers();
    if (!mounted) {
      return;
    }
    final users = home.allUsers.where((u) => u.role == 'student').toList();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> create() async {
              final ok = await home.createStudentGroup(
                name: nameController.text,
                description: descController.text,
                memberIds: selected.toList(),
              );
              if (!ok) {
                return;
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            }

            return AlertDialog(
              title: const Text('Create Group'),
              content: SizedBox(
                width: 460,
                height: 440,
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Group name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Add Friends'),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final checked = selected.contains(user.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  selected.add(user.id);
                                } else {
                                  selected.remove(user.id);
                                }
                              });
                            },
                            title: Text('${user.firstName} ${user.lastName}'.trim()),
                            subtitle: Text('@${user.username}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: create,
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _messagePreview(Message msg) {
    if (msg.messageType == 'image' && (msg.fileUrl ?? '').isNotEmpty) {
      return msg.content.isNotEmpty ? msg.content : '[Image]';
    }
    if (msg.messageType == 'video' && (msg.fileUrl ?? '').isNotEmpty) {
      return msg.content.isNotEmpty ? msg.content : '[Video]';
    }
    if (msg.messageType == 'file' && (msg.fileUrl ?? '').isNotEmpty) {
      final name = (msg.fileName ?? '').trim();
      return name.isEmpty ? '[File]' : '[File] $name';
    }
    return msg.content;
  }

  Widget _buildWhatsAppBubble({
    required BuildContext context,
    required Message msg,
    required bool mine,
    required bool showSender,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final sender = msg.sender;
    final senderName = sender == null
        ? 'Unknown'
        : '${sender.firstName} ${sender.lastName}'.trim();
    final senderUsername = sender?.username ?? 'user';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? const Color(0xFFDCF8C6) : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSender) ...[
                Text(
                  '$senderName  @$senderUsername',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              if (msg.messageType == 'image' &&
                  (msg.fileUrl ?? '').startsWith('data:image/'))
                _buildDataUriImage(msg.fileUrl!)
              else
                Text(_messagePreview(msg)),
              const SizedBox(height: 3),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatChatTime(msg.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildDataUriImage(String dataUri) {
    final bytes = _decodeDataUriBytes(dataUri);
    if (bytes == null) {
      return const Text('[Image]');
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes,
        height: 170,
        width: 220,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<(String, String)?> _pickMediaByType(String messageType) async {
    if (messageType == 'image') {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return (_toDataUri(bytes, 'image/jpeg'), file.name);
    }
    if (messageType == 'video') {
      final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (file == null) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return (_toDataUri(bytes, 'video/mp4'), file.name);
    }
    if (messageType == 'file') {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      if (picked == null || picked.files.isEmpty) {
        return null;
      }
      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        return null;
      }
      return (_toDataUri(bytes, 'application/octet-stream'), file.name);
    }
    return null;
  }

  String _defaultMediaCaption(String messageType) {
    if (messageType == 'image') return 'Image';
    if (messageType == 'video') return 'Video';
    if (messageType == 'file') return 'File';
    return '';
  }

  String _toDataUri(Uint8List bytes, String mimeType) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Uint8List? _decodeDataUriBytes(String dataUri) {
    final index = dataUri.indexOf(',');
    if (index == -1) {
      return null;
    }
    final payload = dataUri.substring(index + 1);
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _openStartChatPicker() async {
    final home = context.read<HomeProvider>();
    await home.refreshUsers();
    if (!mounted) {
      return;
    }

    final users = home.allUsers;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No users available to chat right now.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Start Chat'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.16),
                    child: Icon(Icons.person, color: scheme.primary),
                  ),
                  title: Text('${u.firstName} ${u.lastName}'.trim()),
                  subtitle: Text('@${u.username} • ${u.role}'),
                  onTap: () {
                    Navigator.pop(context);
                    _openChat(u);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMeetingInviteDialog() async {
    final home = context.read<HomeProvider>();
    await home.refreshUsers();
    if (!mounted) {
      return;
    }

    final users = home.allUsers.where((u) => u.role == 'student').toList();
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students available to invite right now.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final selected = <String>{};
        var callType = 'audio';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> startMeeting() async {
              final invitees = users.where((u) => selected.contains(u.id)).toList();
              if (invitees.isEmpty) {
                return;
              }
              await home.initiateMeeting(callType: callType, invitees: invitees);
              if (context.mounted) {
                Navigator.pop(context);
              }
            }

            return AlertDialog(
              title: const Text('Start Meeting'),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Meeting Type'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Audio'),
                          selected: callType == 'audio',
                          onSelected: (_) => setStateDialog(() => callType = 'audio'),
                        ),
                        ChoiceChip(
                          label: const Text('Video'),
                          selected: callType == 'video',
                          onSelected: (_) => setStateDialog(() => callType = 'video'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Invite Students'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final u = users[index];
                          final checked = selected.contains(u.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setStateDialog(() {
                                if (value == true) {
                                  selected.add(u.id);
                                } else {
                                  selected.remove(u.id);
                                }
                              });
                            },
                            title: Text('${u.firstName} ${u.lastName}'.trim()),
                            subtitle: Text('@${u.username}'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(onPressed: startMeeting, child: const Text('Start Meeting')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openAssistantDialog() async {
    final home = context.read<HomeProvider>();
    final queryController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        String answer = '';
        bool loading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> ask() async {
              if (queryController.text.trim().isEmpty) {
                return;
              }
              setStateDialog(() => loading = true);
              final response = await home.askAssistant(queryController.text.trim());
              setStateDialog(() {
                answer = response ?? 'No response';
                loading = false;
              });
            }

            return AlertDialog(
              title: const Text('Assistant'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: const InputDecoration(labelText: 'Ask something'),
                      minLines: 1,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    if (loading) const CircularProgressIndicator(),
                    if (!loading && answer.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(answer),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                FilledButton(onPressed: ask, child: const Text('Ask')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openStudyMaterialsDialog() async {
    final home = context.read<HomeProvider>();
    final codeController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        List<StudyMaterial> items = [];
        bool loading = false;
        String hint = 'Enter course code and fetch materials';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> load() async {
              final code = codeController.text.trim().toUpperCase();
              if (code.isEmpty) {
                return;
              }
              setStateDialog(() => loading = true);
              final result = await home.getStudyMaterials(code);
              setStateDialog(() {
                items = result;
                hint = result.isEmpty
                    ? 'No study materials found for $code'
                    : 'Showing ${result.length} materials for $code';
                loading = false;
              });
            }

            return AlertDialog(
              title: const Text('Your Study Materials'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'Course Code (e.g., CS101)',
                      ),
                      onSubmitted: (_) => load(),
                    ),
                    const SizedBox(height: 10),
                    Text(hint, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7))),
                    const SizedBox(height: 10),
                    if (loading) const Center(child: CircularProgressIndicator()),
                    if (!loading)
                      SizedBox(
                        height: 320,
                        child: items.isEmpty
                            ? const Center(child: Text('No materials loaded yet.'))
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final subtitle = [
                                    item.materialType,
                                    if (item.subjectName.isNotEmpty) item.subjectName,
                                    if (item.resourceUrl.isNotEmpty)
                                      item.resourceUrl.startsWith('data:') ? 'Attached resource' : item.resourceUrl,
                                  ].join(' | ');
                                  return ListTile(
                                    leading: const Icon(Icons.menu_book_rounded),
                                    title: Text(item.title),
                                    subtitle: Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: load,
                  child: const Text('Fetch Materials'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openUploadNotesDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || (user.role != 'faculty' && user.role != 'admin')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only faculty/admin can upload notes.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final courseCodeController = TextEditingController();
    final subjectController = TextEditingController();
    final semesterController = TextEditingController();
    final tagsController = TextEditingController();
    final urlController = TextEditingController();
    var materialType = 'notes';
    var attachType = 'file';
    String? attachmentDataUri;
    String? attachmentName;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickAttachment() async {
              final picked = await _pickMediaByType(attachType);
              if (picked == null) {
                return;
              }
              setStateDialog(() {
                attachmentDataUri = picked.$1;
                attachmentName = picked.$2;
                urlController.clear();
              });
            }

            Future<void> submit() async {
              final title = titleController.text.trim();
              final courseCode = courseCodeController.text.trim().toUpperCase();
              if (title.isEmpty || courseCode.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and Course Code are required.')),
                );
                return;
              }

              setStateDialog(() => submitting = true);
              final response = await ApiService.createStudyMaterial({
                'title': title,
                'description': descController.text.trim(),
                'courseCode': courseCode,
                'subjectName': subjectController.text.trim(),
                'department': user.department ?? '',
                'semester': semesterController.text.trim(),
                'materialType': materialType,
                'resourceUrl': attachmentDataUri ?? urlController.text.trim(),
                'tags': tagsController.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList(),
              });
              final data = _decode(response.body);
              if (!mounted) {
                return;
              }
              setStateDialog(() => submitting = false);

              if (response.statusCode != 201 || data['success'] != true) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(data['message']?.toString() ?? 'Failed to upload note')),
                );
                return;
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Note uploaded successfully')),
              );
            }

            return AlertDialog(
              title: const Text('Upload Notes'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title *'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: courseCodeController,
                              decoration: const InputDecoration(labelText: 'Course Code *'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: materialType,
                              decoration: const InputDecoration(labelText: 'Type'),
                              items: const [
                                DropdownMenuItem(value: 'notes', child: Text('Notes')),
                                DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                                DropdownMenuItem(value: 'ppt', child: Text('PPT')),
                                DropdownMenuItem(value: 'video', child: Text('Video')),
                                DropdownMenuItem(value: 'link', child: Text('Link')),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setStateDialog(() => materialType = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: subjectController,
                              decoration: const InputDecoration(labelText: 'Subject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: semesterController,
                              decoration: const InputDecoration(labelText: 'Semester'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tagsController,
                        decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: urlController,
                        decoration: const InputDecoration(
                          labelText: 'Resource URL (optional if attachment selected)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('File'),
                            selected: attachType == 'file',
                            onSelected: (_) => setStateDialog(() => attachType = 'file'),
                          ),
                          ChoiceChip(
                            label: const Text('Image'),
                            selected: attachType == 'image',
                            onSelected: (_) => setStateDialog(() => attachType = 'image'),
                          ),
                          ChoiceChip(
                            label: const Text('Video'),
                            selected: attachType == 'video',
                            onSelected: (_) => setStateDialog(() => attachType = 'video'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: pickAttachment,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: const Text('Attach'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        attachmentName ?? 'No attachment selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openHelpSupportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Quick Instructions',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Use Dashboard tiles to open Announcements, Chats, Groups, and Study Materials.'),
                  const Text('2. Pull down in Announcements or Chats to refresh live data.'),
                  const Text('3. Tap any announcement to Like or Comment in real-time.'),
                  const Text('4. Tap any contact in Chats to open direct messaging and send messages.'),
                  const Text('5. Use Profile to edit your details or change password.'),
                  const SizedBox(height: 14),
                  const Text(
                    'App Features',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const _HelpFeature(
                    icon: Icons.campaign_outlined,
                    title: 'Live Announcements',
                    subtitle: 'Read updates, likes, and comments with API sync.',
                  ),
                  const _HelpFeature(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Real-time Messaging',
                    subtitle: 'Direct chat powered by Socket.IO events.',
                  ),
                  const _HelpFeature(
                    icon: Icons.support_agent_rounded,
                    title: 'Exam Topics Chatbot',
                    subtitle: 'Use the floating Exam Bot button to get important topics by subject.',
                  ),
                  const _HelpFeature(
                    icon: Icons.menu_book_rounded,
                    title: 'Study Materials',
                    subtitle: 'Use Dashboard Study Materials card and enter course code to fetch content from database.',
                  ),
                  const _HelpFeature(
                    icon: Icons.account_circle_outlined,
                    title: 'Profile & Security',
                    subtitle: 'Update profile and password from Profile tab.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Need More Help?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Use the Assistant for query-based support, or contact your college admin for account issues.'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openAssistantDialog();
              },
              child: const Text('Open Assistant'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExamTopicsChatbot() async {
    final home = context.read<HomeProvider>();
    final subjectController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        String responseText = '';
        bool loading = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> fetchTopics() async {
              final subject = subjectController.text.trim();
              if (subject.isEmpty) {
                return;
              }
              setStateDialog(() => loading = true);
              final result = await home.getExamTopics(subject);
              setStateDialog(() {
                responseText = result ?? 'No response';
                loading = false;
              });
            }

            return AlertDialog(
              title: const Text('Exam Topics Chatbot'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter subject to get important exam topics:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject (e.g., Data Structures, Physics)',
                      ),
                      onSubmitted: (_) => fetchTopics(),
                    ),
                    const SizedBox(height: 12),
                    if (loading) const Center(child: CircularProgressIndicator()),
                    if (!loading && responseText.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SingleChildScrollView(child: Text(responseText)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                FilledButton(onPressed: fetchTopics, child: const Text('Get Topics')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditProfileDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final dept = TextEditingController(text: user.department ?? '');
    final photo = TextEditingController(text: user.profilePicture ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: first, decoration: const InputDecoration(labelText: 'First name')),
              const SizedBox(height: 10),
              TextField(controller: last, decoration: const InputDecoration(labelText: 'Last name')),
              const SizedBox(height: 10),
              TextField(controller: dept, decoration: const InputDecoration(labelText: 'Department')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final ok = await auth.updateProfile(
                  firstName: first.text.trim(),
                  lastName: last.text.trim(),
                  department: dept.text.trim(),
                  profilePicture: photo.text.trim(),
                );
                if (ok && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditPhotoDialog() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return;
    }

    String pickedPhotoDataUri = user.profilePicture ?? '';
    Uint8List? pickedPhotoPreview = _decodeDataUriBytes(pickedPhotoDataUri);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickPhoto() async {
              final file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (file == null) {
                return;
              }
              final bytes = await file.readAsBytes();
              setStateDialog(() {
                pickedPhotoDataUri = _toDataUri(bytes, 'image/jpeg');
                pickedPhotoPreview = bytes;
              });
            }

            return AlertDialog(
              title: const Text('Change Profile Photo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundImage: pickedPhotoPreview != null ? MemoryImage(pickedPhotoPreview!) : null,
                    child: pickedPhotoPreview == null ? const Icon(Icons.person, size: 44) : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose from Gallery'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final ok = await auth.updateProfile(
                      firstName: user.firstName,
                      lastName: user.lastName,
                      department: user.department ?? '',
                      profilePicture: pickedPhotoDataUri,
                    );
                    if (ok && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Photo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openChangePasswordDialog() async {
    final auth = context.read<AuthProvider>();
    final current = TextEditingController();
    final next = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final ok = await auth.changePassword(
                  currentPassword: current.text,
                  newPassword: next.text,
                );
                if (ok && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }
}

class DashboardPage extends StatelessWidget {
  final String userName;
  final Map<String, dynamic> stats;
  final ValueChanged<int> onQuickAction;

  const DashboardPage({
    super.key,
    required this.userName,
    required this.stats,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalAnnouncements = stats['totalAnnouncements'] ?? 0;
    final unreadMessages = stats['unreadMessages'] ?? 0;
    final totalGroups = stats['totalGroups'] ?? 0;

    return ListView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $userName',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Live campus data is syncing in real-time.',
                style: TextStyle(color: scheme.onSecondary.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TagPill(label: '$totalAnnouncements Announcements'),
                  _TagPill(label: '$unreadMessages Unread Chat'),
                  _TagPill(label: '$totalGroups Groups'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Quick Access'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _QuickTile(
              icon: Icons.campaign_rounded,
              title: 'Announcements',
              subtitle: 'Latest official updates',
              color: scheme.primary,
              onTap: () => onQuickAction(0),
            ),
            _QuickTile(
              icon: Icons.chat_rounded,
              title: 'Messages',
              subtitle: 'Direct & group chat',
              color: scheme.secondary,
              onTap: () => onQuickAction(1),
            ),
            _QuickTile(
              icon: Icons.work_outline_rounded,
              title: 'Placements',
              subtitle: 'Internship updates',
              color: scheme.tertiary,
              onTap: () => onQuickAction(2),
            ),
            _QuickTile(
              icon: Icons.menu_book_rounded,
              title: 'Study Materials',
              subtitle: 'Fetch by course code',
              color: scheme.onSurface,
              onTap: () => onQuickAction(3),
            ),
          ],
        ),
      ],
    );
  }
}

class AnnouncementsPage extends StatelessWidget {
  final List<Announcement> announcements;
  final Future<void> Function() onRefresh;
  final ValueChanged<Announcement> onOpen;
  final VoidCallback onEnterBroadcasts;
  final bool canPostCircular;
  final VoidCallback onPostCircular;

  const AnnouncementsPage({
    super.key,
    required this.announcements,
    required this.onRefresh,
    required this.onOpen,
    required this.onEnterBroadcasts,
    required this.canPostCircular,
    required this.onPostCircular,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (announcements.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BroadcastJoinCard(onEnterBroadcasts: onEnterBroadcasts),
            if (canPostCircular) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onPostCircular,
                  icon: const Icon(Icons.post_add_rounded),
                  label: const Text('Post Circular'),
                ),
              ),
            ],
            const SizedBox(height: 180),
            const Center(child: Text('No announcements yet. Pull down to refresh.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('announcements'),
        padding: const EdgeInsets.all(16),
        children: [
          _BroadcastJoinCard(onEnterBroadcasts: onEnterBroadcasts),
          if (canPostCircular) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onPostCircular,
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('Post Circular'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...announcements.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.18),
                  child: Icon(Icons.campaign_rounded, color: scheme.primary),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(item),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class InternshipPlacementPage extends StatelessWidget {
  final List<Announcement> announcements;
  final Future<void> Function() onRefresh;
  final ValueChanged<Announcement> onOpen;
  final bool canPostCircular;
  final VoidCallback onPostCircular;

  const InternshipPlacementPage({
    super.key,
    required this.announcements,
    required this.onRefresh,
    required this.onOpen,
    required this.canPostCircular,
    required this.onPostCircular,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updates = announcements.where(_isPlacementUpdate).toList();

    if (updates.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (canPostCircular)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onPostCircular,
                  icon: const Icon(Icons.post_add_rounded),
                  label: const Text('Post Circular'),
                ),
              ),
            const SizedBox(height: 180),
            const Center(child: Text('No internship or placement updates yet. Pull down to refresh.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('internship-updates'),
        padding: const EdgeInsets.all(16),
        children: [
          if (canPostCircular)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onPostCircular,
                icon: const Icon(Icons.post_add_rounded),
                label: const Text('Post Circular'),
              ),
            ),
          const SizedBox(height: 10),
          ...updates.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.18),
                  child: Icon(Icons.work_outline_rounded, color: scheme.primary),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onOpen(item),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isPlacementUpdate(Announcement item) {
    final haystack = '${item.title} ${item.content} ${item.category}'.toLowerCase();
    return haystack.contains('internship') ||
        haystack.contains('placement') ||
        haystack.contains('career') ||
        haystack.contains('recruit') ||
        haystack.contains('job');
  }
}

class _BroadcastJoinCard extends StatelessWidget {
  final VoidCallback onEnterBroadcasts;

  const _BroadcastJoinCard({
    required this.onEnterBroadcasts,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondary.withValues(alpha: 0.18),
              child: Icon(Icons.record_voice_over_rounded, color: scheme.secondary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Faculty Broadcasts', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Students can join active broadcasts from Meeting Invites.'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onEnterBroadcasts,
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final User? currentUser;
  final List<User> contacts;
  final List<Group> groups;
  final List<User> allUsers;
  final List<Message> messages;
  final List<CallInvite> incomingCalls;
  final List<CallInvite> outgoingCalls;
  final Future<void> Function() onRefresh;
  final ValueChanged<User> onOpenChat;
  final VoidCallback onStartChat;
  final VoidCallback onCreateGroup;
  final ValueChanged<Group> onOpenGroupChat;
  final VoidCallback onStartMeeting;
  final ValueChanged<CallInvite> onAcceptCall;
  final ValueChanged<CallInvite> onRejectCall;
  final ValueChanged<CallInvite> onEndCall;

  const ChatPage({
    super.key,
    required this.currentUser,
    required this.contacts,
    required this.groups,
    required this.allUsers,
    required this.messages,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.onRefresh,
    required this.onOpenChat,
    required this.onStartChat,
    required this.onCreateGroup,
    required this.onOpenGroupChat,
    required this.onStartMeeting,
    required this.onAcceptCall,
    required this.onRejectCall,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final available = contacts.isEmpty ? allUsers : contacts;
    final role = currentUser?.role ?? '';
    final allGroups = List<Group>.from(groups);
    allGroups.sort((a, b) {
      final aIsCec = a.name.trim().toLowerCase() == 'cec assemble';
      final bIsCec = b.name.trim().toLowerCase() == 'cec assemble';
      if (aIsCec && !bIsCec) return -1;
      if (!aIsCec && bIsCec) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _MeetingCard(
            isFaculty: role == 'faculty' || role == 'admin',
            incomingCalls: incomingCalls,
            outgoingCalls: outgoingCalls,
            onStartMeeting: onStartMeeting,
            onAcceptCall: onAcceptCall,
            onRejectCall: onRejectCall,
            onEndCall: onEndCall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onStartChat,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Start New Chat'),
              ),
              FilledButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Create Group'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final splitView = constraints.maxWidth >= 900;
                if (!splitView) {
                  return ListView(
                    children: [
                      SizedBox(
                        height: 360,
                        child: _buildPersonalPane(context, available),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 360,
                        child: _buildGroupPane(context, allGroups),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _buildPersonalPane(context, available)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGroupPane(context, allGroups)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalPane(BuildContext context, List<User> available) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Personal Chats',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: available.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No personal conversations yet.')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final contact = available[index];
                        final last = messages.firstWhere(
                          (m) =>
                              (m.groupId == null || m.groupId!.isEmpty) &&
                              (m.sender?.id == contact.id || m.receiver?.id == contact.id),
                          orElse: () => Message(
                            id: 'tmp',
                            content: 'Tap to start chatting',
                            isRead: true,
                            isDeleted: false,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: scheme.secondary.withValues(alpha: 0.18),
                            child: Icon(Icons.person, color: scheme.secondary),
                          ),
                          title: Text(
                            '${contact.firstName} ${contact.lastName}'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(last.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => onOpenChat(contact),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupPane(BuildContext context, List<Group> allGroups) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Group Chatrooms',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: allGroups.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No groups yet. Create one to start.')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: allGroups.length,
                      itemBuilder: (context, index) {
                        final group = allGroups[index];
                        final lastGroupMessage = messages.firstWhere(
                          (m) => m.groupId == group.id,
                          orElse: () => Message(
                            id: 'tmp-group-${group.id}',
                            content: 'Group created',
                            isRead: true,
                            isDeleted: false,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: scheme.tertiary.withValues(alpha: 0.2),
                            child: Icon(Icons.groups_rounded, color: scheme.tertiary),
                          ),
                          title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            lastGroupMessage.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => onOpenGroupChat(group),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final bool isFaculty;
  final List<CallInvite> incomingCalls;
  final List<CallInvite> outgoingCalls;
  final VoidCallback onStartMeeting;
  final ValueChanged<CallInvite> onAcceptCall;
  final ValueChanged<CallInvite> onRejectCall;
  final ValueChanged<CallInvite> onEndCall;

  const _MeetingCard({
    required this.isFaculty,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.onStartMeeting,
    required this.onAcceptCall,
    required this.onRejectCall,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isFaculty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Meetings', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    onPressed: onStartMeeting,
                    icon: const Icon(Icons.video_call_rounded),
                    label: const Text('Start Meeting'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (outgoingCalls.isEmpty)
                Text(
                  'No active invites yet.',
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
              if (outgoingCalls.isNotEmpty)
                ...outgoingCalls.map((invite) {
                  final canEnd = invite.status != 'ended' && invite.status != 'rejected';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withValues(alpha: 0.18),
                      child: Icon(Icons.school_rounded, color: scheme.primary),
                    ),
                    title: Text('To ${invite.otherName}'),
                    subtitle: Text(
                      '${invite.displayType} • ${invite.statusLabel}'
                      '${invite.meetingId != null ? ' • ${invite.meetingId}' : ''}',
                    ),
                    trailing: canEnd
                        ? TextButton(
                            onPressed: () => onEndCall(invite),
                            child: const Text('End'),
                          )
                        : null,
                  );
                }),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meeting Invites', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (incomingCalls.isEmpty)
              Text(
                'No meeting invites right now.',
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
            if (incomingCalls.isNotEmpty)
              ...incomingCalls.map((invite) {
                final isPending = invite.status == 'incoming' || invite.status == 'ringing';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: scheme.secondary.withValues(alpha: 0.18),
                    child: Icon(Icons.video_camera_front_rounded, color: scheme.secondary),
                  ),
                  title: Text(invite.otherName),
                  subtitle: Text(
                    '${invite.displayType} • ${invite.statusLabel}'
                    '${invite.meetingId != null ? ' • ${invite.meetingId}' : ''}',
                  ),
                  trailing: isPending
                      ? Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: () => onRejectCall(invite),
                              child: const Text('Decline'),
                            ),
                            FilledButton(
                              onPressed: () => onAcceptCall(invite),
                              child: const Text('Join'),
                            ),
                          ],
                        )
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onEditPhoto;
  final VoidCallback onPrivacy;
  final VoidCallback onHelp;
  final VoidCallback onUploadNotes;

  const ProfilePage({
    super.key,
    required this.onEditProfile,
    required this.onEditPhoto,
    required this.onPrivacy,
    required this.onHelp,
    required this.onUploadNotes,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final user = authProvider.user;
    final userName = (user != null) ? '${user.firstName} ${user.lastName}' : 'User Name';
    final canUploadNotes = user?.role == 'faculty' || user?.role == 'admin';

    return ListView(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: scheme.primary.withValues(alpha: 0.16),
                  backgroundImage: _profileImageProvider(user?.profilePicture),
                  child: (user?.profilePicture == null ||
                          user!.profilePicture!.trim().isEmpty)
                      ? Icon(Icons.person, size: 40, color: scheme.primary)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  user?.role.toUpperCase() ?? 'USER',
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                if (user?.department != null && user!.department!.isNotEmpty)
                  Text(
                    user.department!,
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onEditProfile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined),
                title: const Text('Change Profile Photo'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onEditPhoto,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.security_outlined),
                title: const Text('Privacy Settings'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onPrivacy,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onHelp,
              ),
              if (canUploadNotes) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Upload Study Materials'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: onUploadNotes,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, color: color, size: 18),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;

  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.onSecondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.onSecondary.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: scheme.onSecondary, fontSize: 12),
      ),
    );
  }
}

class _HelpFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HelpFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  subtitle,
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
