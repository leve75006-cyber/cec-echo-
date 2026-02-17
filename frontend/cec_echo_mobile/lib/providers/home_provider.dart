import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/announcement.dart';
import '../models/call_invite.dart';
import '../models/message.dart';
import '../models/study_material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class HomeProvider with ChangeNotifier {
  User? _currentUser;
  io.Socket? _socket;
  Timer? _pollTimer;

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  List<Announcement> _announcements = [];
  List<Message> _messages = [];
  List<User> _allUsers = [];
  List<CallInvite> _incomingCalls = [];
  List<CallInvite> _outgoingCalls = [];
  Map<String, dynamic> _dashboardStats = {
    'totalAnnouncements': 0,
    'unreadMessages': 0,
    'totalGroups': 0,
  };

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<Announcement> get announcements => _announcements;
  List<Message> get messages => _messages;
  List<User> get allUsers => _allUsers;
  List<CallInvite> get incomingCalls => List.unmodifiable(_incomingCalls);
  List<CallInvite> get outgoingCalls => List.unmodifiable(_outgoingCalls);
  User? get currentUser => _currentUser;
  Map<String, dynamic> get dashboardStats => _dashboardStats;

  List<User> get contacts {
    if (_currentUser == null) {
      return [];
    }
    final map = <String, User>{};
    for (final msg in _messages) {
      final sender = msg.sender;
      final receiver = msg.receiver;

      if (sender != null && sender.id != _currentUser!.id) {
        map[sender.id] = sender;
      }
      if (receiver != null && receiver.id != _currentUser!.id) {
        map[receiver.id] = receiver;
      }
    }
    return map.values.toList();
  }

  Future<void> initialize(User user) async {
    if (_isInitialized && _currentUser?.id == user.id) {
      return;
    }

    _currentUser = user;
    _isLoading = true;
    _error = null;
    notifyListeners();

    await refreshDashboard().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();

    _connectSocket();
    _startPolling();

    unawaited(_warmInitialData());
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshDashboard(),
      refreshAnnouncements(),
      refreshMessages(),
      refreshUsers(),
    ]);
  }

  Future<void> _warmInitialData() async {
    await Future.wait([
      refreshAnnouncements(),
      refreshMessages(),
      refreshUsers(),
    ]);
  }

  Future<void> refreshDashboard() async {
    try {
      final response = await ApiService.getStudentDashboard();
      final jsonData = _decode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        final stats =
            (jsonData['data']?['stats'] ?? {}) as Map<String, dynamic>;
        _dashboardStats = {
          'totalAnnouncements': stats['totalAnnouncements'] ?? 0,
          'unreadMessages': stats['unreadMessages'] ?? 0,
          'totalGroups': stats['totalGroups'] ?? 0,
        };
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshAnnouncements() async {
    try {
      final response = await ApiService.getAnnouncements();
      final jsonData = _decode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        final items = (jsonData['data'] as List<dynamic>? ?? []);
        _announcements = items
            .whereType<Map<String, dynamic>>()
            .map(Announcement.fromJson)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshMessages() async {
    try {
      final response = await ApiService.getMessages();
      final jsonData = _decode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        final items = (jsonData['data'] as List<dynamic>? ?? []);
        _messages = items
            .whereType<Map<String, dynamic>>()
            .map(Message.fromJson)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshUsers() async {
    try {
      final response = await ApiService.getStudentUsers();
      final jsonData = _decode(response.body);

      if (response.statusCode == 200 && jsonData['success'] == true) {
        final items = (jsonData['data'] as List<dynamic>? ?? []);
        _allUsers = items
            .whereType<Map<String, dynamic>>()
            .map(User.fromJson)
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<List<Message>> getDirectMessages(String userId) async {
    final response = await ApiService.getDirectMessages(userId);
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final items = (jsonData['data'] as List<dynamic>? ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList();
    }

    return [];
  }

  Future<bool> sendDirectMessage({
    required String receiverId,
    required String content,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      return false;
    }

    final response = await ApiService.sendMessage({
      'receiver': receiverId,
      'content': text,
      'messageType': 'text',
    });

    final jsonData = _decode(response.body);
    if (response.statusCode == 201 && jsonData['success'] == true) {
      final raw = jsonData['data'];
      if (raw is Map<String, dynamic>) {
        _messages.insert(0, Message.fromJson(raw));
        notifyListeners();
      }

      _socket?.emit('private-message', {
        'senderId': _currentUser?.id,
        'receiverId': receiverId,
        'content': text,
        'messageType': 'text',
      });

      await refreshDashboard();
      return true;
    }
    return false;
  }

  Future<void> toggleLike(String announcementId) async {
    final response = await ApiService.likeAnnouncement(announcementId);
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final updated = jsonData['data'];
      if (updated is Map<String, dynamic>) {
        final index = _announcements.indexWhere((a) => a.id == announcementId);
        if (index != -1) {
          _announcements[index] = Announcement.fromJson(updated);
          notifyListeners();
        } else {
          await refreshAnnouncements();
        }
      }
    }
  }

  Future<void> addComment(String announcementId, String content) async {
    if (content.trim().isEmpty) {
      return;
    }

    final response = await ApiService.addComment(
      announcementId,
      content.trim(),
    );
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final updated = jsonData['data'];
      if (updated is Map<String, dynamic>) {
        final index = _announcements.indexWhere((a) => a.id == announcementId);
        if (index != -1) {
          _announcements[index] = Announcement.fromJson(updated);
          notifyListeners();
        } else {
          await refreshAnnouncements();
        }
      }
    }
  }

  Future<String?> askAssistant(String query) async {
    final response = await ApiService.getAdvancedChatbotResponse(query);
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final data = jsonData['data'];
      if (data is Map<String, dynamic>) {
        return data['response']?.toString() ?? data.toString();
      }
      return jsonData['message']?.toString();
    }

    return jsonData['message']?.toString() ?? 'No response from assistant';
  }

  Future<String?> getExamTopics(String subject) async {
    final response = await ApiService.getExamTopics(subject);
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final data = jsonData['data'];
      if (data is Map<String, dynamic>) {
        return data['response']?.toString() ?? '';
      }
    }

    return jsonData['message']?.toString() ?? 'No response from exam assistant';
  }

  Future<List<StudyMaterial>> getStudyMaterials(String courseCode) async {
    final code = courseCode.trim().toUpperCase();
    if (code.isEmpty) {
      return [];
    }

    final response = await ApiService.getStudyMaterials(code);
    final jsonData = _decode(response.body);

    if (response.statusCode == 200 && jsonData['success'] == true) {
      final items = (jsonData['data'] as List<dynamic>? ?? []);
      return items
          .whereType<Map<String, dynamic>>()
          .map(StudyMaterial.fromJson)
          .toList();
    }

    return [];
  }

  void clearSession() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _announcements = [];
    _messages = [];
    _allUsers = [];
    _incomingCalls = [];
    _outgoingCalls = [];
    _dashboardStats = {
      'totalAnnouncements': 0,
      'unreadMessages': 0,
      'totalGroups': 0,
    };
    _isInitialized = false;
    _currentUser = null;
    notifyListeners();
  }

  void _connectSocket() {
    if (_currentUser == null) {
      return;
    }

    _socket?.disconnect();
    _socket?.dispose();

    _socket = io.io(
      ApiService.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join-room', _currentUser!.id);
      _socket!.emit('set-online-status', _currentUser!.id);
    });

    _socket!.off('incoming-call');
    _socket!.off('call-initiated');
    _socket!.off('call-accepted');
    _socket!.off('call-rejected');
    _socket!.off('call-terminated');
    _socket!.off('call-error');

    _socket!.on('receive-private-message', (payload) {
      if (payload is Map<String, dynamic>) {
        _messages.insert(0, Message.fromJson(payload));
        notifyListeners();
      }
    });

    _socket!.on('message-sent', (payload) {
      if (payload is Map<String, dynamic>) {
        final sent = Message.fromJson(payload);
        final exists = _messages.any((m) => m.id == sent.id);
        if (!exists) {
          _messages.insert(0, sent);
          notifyListeners();
        }
      }
    });

    _socket!.on('incoming-call', (payload) {
      if (payload is Map<String, dynamic>) {
        final callerInfo = payload['callerInfo'] as Map<String, dynamic>? ?? {};
        final callId = payload['callId']?.toString() ?? '';
        final fromId = payload['from']?.toString() ?? '';
        final callType = payload['callType']?.toString() ?? 'audio';
        final meetingId = payload['meetingId']?.toString();
        final name = callerInfo['name']?.toString() ?? 'Faculty';
        _upsertIncomingCall(
          CallInvite(
            callId: callId,
            otherId: fromId,
            otherName: name,
            callType: callType,
            meetingId: meetingId,
            isIncoming: true,
            createdAt: DateTime.now(),
            status: 'incoming',
          ),
        );
      }
    });

    _socket!.on('call-initiated', (payload) {
      if (payload is Map<String, dynamic>) {
        final callId = payload['callId']?.toString() ?? '';
        final toId = payload['to']?.toString() ?? '';
        final callType = payload['callType']?.toString() ?? 'audio';
        final meetingId = payload['meetingId']?.toString();
        final calleeInfo = payload['calleeInfo'] as Map<String, dynamic>? ?? {};
        final name = calleeInfo['name']?.toString() ?? 'Student';
        _upsertOutgoingCall(
          CallInvite(
            callId: callId,
            otherId: toId,
            otherName: name,
            callType: callType,
            meetingId: meetingId,
            isIncoming: false,
            createdAt: DateTime.now(),
            status: 'ringing',
          ),
        );
      }
    });

    _socket!.on('call-accepted', (payload) {
      if (payload is Map<String, dynamic>) {
        final callId = payload['callId']?.toString() ?? '';
        _updateCallStatus(callId, 'accepted');
      }
    });

    _socket!.on('call-rejected', (payload) {
      if (payload is Map<String, dynamic>) {
        final callId = payload['callId']?.toString() ?? '';
        _updateCallStatus(callId, 'rejected');
      }
    });

    _socket!.on('call-terminated', (payload) {
      if (payload is Map<String, dynamic>) {
        final callId = payload['callId']?.toString() ?? '';
        _updateCallStatus(callId, 'ended');
      }
    });

    _socket!.on('call-error', (payload) {
      if (payload is Map<String, dynamic>) {
        _error = payload['message']?.toString();
        notifyListeners();
      }
    });

    _socket!.connect();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      refreshDashboard();
      refreshAnnouncements();
      refreshMessages();
    });
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

  Future<void> initiateMeeting({
    required String callType,
    required List<User> invitees,
  }) async {
    if (_currentUser == null || _socket == null) {
      return;
    }
    if (_currentUser!.role != 'faculty' && _currentUser!.role != 'admin') {
      _error = 'Only faculty can start meetings.';
      notifyListeners();
      return;
    }

    final meetingId =
        '${_currentUser!.id}-${DateTime.now().millisecondsSinceEpoch}';
    for (final invitee in invitees) {
      _socket!.emit('call-user', {
        'to': invitee.id,
        'from': _currentUser!.id,
        'callType': callType,
        'meetingId': meetingId,
      });
    }
  }

  void acceptCall(CallInvite invite) {
    if (_socket == null) {
      return;
    }
    _socket!.emit('accept-call', {
      'callId': invite.callId,
      'to': invite.otherId,
      'answer': null,
    });
    _updateCallStatus(invite.callId, 'accepted');
  }

  void rejectCall(CallInvite invite) {
    if (_socket == null) {
      return;
    }
    _socket!.emit('reject-call', {
      'callId': invite.callId,
      'to': invite.otherId,
    });
    _updateCallStatus(invite.callId, 'rejected');
  }

  void endCall(CallInvite invite) {
    if (_socket == null) {
      return;
    }
    _socket!.emit('terminate-call', {
      'callId': invite.callId,
      'to': invite.otherId,
    });
    _updateCallStatus(invite.callId, 'ended');
  }

  void _upsertIncomingCall(CallInvite invite) {
    final index = _incomingCalls.indexWhere((c) => c.callId == invite.callId);
    if (index == -1) {
      _incomingCalls.insert(0, invite);
    } else {
      _incomingCalls[index] = _incomingCalls[index].copyWith(
        status: invite.status,
        otherName: invite.otherName,
        callType: invite.callType,
        meetingId: invite.meetingId,
      );
    }
    notifyListeners();
  }

  void _upsertOutgoingCall(CallInvite invite) {
    final index = _outgoingCalls.indexWhere((c) => c.callId == invite.callId);
    if (index == -1) {
      _outgoingCalls.insert(0, invite);
    } else {
      _outgoingCalls[index] = _outgoingCalls[index].copyWith(
        status: invite.status,
        otherName: invite.otherName,
        callType: invite.callType,
        meetingId: invite.meetingId,
      );
    }
    notifyListeners();
  }

  void _updateCallStatus(String callId, String status) {
    final incomingIndex = _incomingCalls.indexWhere((c) => c.callId == callId);
    if (incomingIndex != -1) {
      _incomingCalls[incomingIndex] = _incomingCalls[incomingIndex].copyWith(
        status: status,
      );
    }
    final outgoingIndex = _outgoingCalls.indexWhere((c) => c.callId == callId);
    if (outgoingIndex != -1) {
      _outgoingCalls[outgoingIndex] = _outgoingCalls[outgoingIndex].copyWith(
        status: status,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
}
