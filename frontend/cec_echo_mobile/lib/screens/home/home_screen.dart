import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/announcement.dart';
import '../../models/call_invite.dart';
import '../../models/message.dart';
import '../../models/study_material.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _bootstrapped = false;

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
      ),
      ChatPage(
        currentUser: user,
        contacts: homeProvider.contacts,
        allUsers: homeProvider.allUsers,
        messages: homeProvider.messages,
        incomingCalls: homeProvider.incomingCalls,
        outgoingCalls: homeProvider.outgoingCalls,
        onRefresh: homeProvider.refreshMessages,
        onOpenChat: _openChat,
        onStartChat: _openStartChatPicker,
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
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'News'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chats'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openExamTopicsChatbot,
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Exam Bot'),
      ),
    );
  }

  void _onQuickAction(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 1);
      return;
    }
    if (index == 1) {
      setState(() => _selectedIndex = 2);
      return;
    }
    if (index == 2) {
      setState(() => _selectedIndex = 2);
      final groups = context.read<HomeProvider>().dashboardStats['totalGroups'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded chats with $groups active groups.')),
      );
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

  Future<void> _openChat(User contact) async {
    final home = context.read<HomeProvider>();
    final auth = context.read<AuthProvider>();
    final current = auth.user;
    if (current == null) {
      return;
    }

    final sendController = TextEditingController();
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
              final ok = await home.sendDirectMessage(
                receiverId: contact.id,
                content: sendController.text,
              );
              if (!ok) {
                return;
              }
              sendController.clear();
              thread = await home.getDirectMessages(contact.id);
              setStateDialog(() {});
            }

            return AlertDialog(
              title: Text('Chat with ${contact.firstName}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 280,
                      child: thread.isEmpty
                          ? const Center(child: Text('No messages yet'))
                          : ListView.builder(
                              reverse: true,
                              itemCount: thread.length,
                              itemBuilder: (context, index) {
                                final msg = thread[index];
                                final mine = msg.sender?.id == current.id;
                                final scheme = Theme.of(context).colorScheme;
                                return Align(
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: mine
                                          ? scheme.primary.withValues(alpha: 0.18)
                                          : scheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(msg.content),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
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
                                    if (item.resourceUrl.isNotEmpty) item.resourceUrl,
                                  ].join(' • ');

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

    final photoController = TextEditingController(text: user.profilePicture ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Profile Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: photoController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL',
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 12),
              if (photoController.text.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    photoController.text.trim(),
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      width: 120,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: const Text('Preview unavailable'),
                    ),
                  ),
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
                  profilePicture: photoController.text.trim(),
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
              icon: Icons.event_available_rounded,
              title: 'Groups',
              subtitle: 'Your active groups',
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

  const AnnouncementsPage({
    super.key,
    required this.announcements,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (announcements.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 180),
            Center(child: Text('No announcements yet. Pull down to refresh.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        key: const ValueKey('announcements'),
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final item = announcements[index];
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
        },
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  final User? currentUser;
  final List<User> contacts;
  final List<User> allUsers;
  final List<Message> messages;
  final List<CallInvite> incomingCalls;
  final List<CallInvite> outgoingCalls;
  final Future<void> Function() onRefresh;
  final ValueChanged<User> onOpenChat;
  final VoidCallback onStartChat;
  final VoidCallback onStartMeeting;
  final ValueChanged<CallInvite> onAcceptCall;
  final ValueChanged<CallInvite> onRejectCall;
  final ValueChanged<CallInvite> onEndCall;

  const ChatPage({
    super.key,
    required this.currentUser,
    required this.contacts,
    required this.allUsers,
    required this.messages,
    required this.incomingCalls,
    required this.outgoingCalls,
    required this.onRefresh,
    required this.onOpenChat,
    required this.onStartChat,
    required this.onStartMeeting,
    required this.onAcceptCall,
    required this.onRejectCall,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = contacts.isEmpty ? allUsers : contacts;
    final role = currentUser?.role ?? '';

    if (contacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 16),
            if (role == 'faculty' || role == 'admin')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MeetingCard(
                  isFaculty: true,
                  incomingCalls: const [],
                  outgoingCalls: outgoingCalls,
                  onStartMeeting: onStartMeeting,
                  onAcceptCall: onAcceptCall,
                  onRejectCall: onRejectCall,
                  onEndCall: onEndCall,
                ),
              ),
            if (role == 'student')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MeetingCard(
                  isFaculty: false,
                  incomingCalls: incomingCalls,
                  outgoingCalls: const [],
                  onStartMeeting: onStartMeeting,
                  onAcceptCall: onAcceptCall,
                  onRejectCall: onRejectCall,
                  onEndCall: onEndCall,
                ),
              ),
            const SizedBox(height: 140),
            const Center(child: Text('No conversations yet. Start a chat now.')),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: onStartChat,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Start Chat'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        key: const ValueKey('chat'),
        padding: const EdgeInsets.all(16),
        itemCount: available.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
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
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: onStartChat,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Start New Chat'),
                ),
                const SizedBox(height: 10),
              ],
            );
          }

          final contact = available[index - 1];
          final last = messages.firstWhere(
            (m) => m.sender?.id == contact.id || m.receiver?.id == contact.id,
            orElse: () => Message(
              id: 'tmp',
              content: 'Tap to start chatting',
              isRead: true,
              isDeleted: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
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
            ),
          );
        },
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

  const ProfilePage({
    super.key,
    required this.onEditProfile,
    required this.onEditPhoto,
    required this.onPrivacy,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final user = authProvider.user;
    final userName = (user != null) ? '${user.firstName} ${user.lastName}' : 'User Name';

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
                  backgroundImage: (user?.profilePicture != null &&
                          user!.profilePicture!.trim().isNotEmpty)
                      ? NetworkImage(user.profilePicture!.trim())
                      : null,
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
