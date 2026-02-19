import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../home/home_screen.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  final _facultyFormKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _department = TextEditingController();
  final _regNo = TextEditingController();
  final _studentDeleteRegNo = TextEditingController();
  final _noteTitle = TextEditingController();
  final _noteDesc = TextEditingController();
  final _noteCourseCode = TextEditingController();
  final _noteSubject = TextEditingController();
  final _noteDepartment = TextEditingController();
  final _noteSemester = TextEditingController();
  final _noteTags = TextEditingController();
  final _noteUrl = TextEditingController();
  String _noteMaterialType = 'notes';
  String? _pickedNoteDataUri;
  String? _pickedNoteName;

  bool _loading = true;
  String? _error;
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalGroups = 0;
  int _totalAnnouncements = 0;
  List<User> _faculties = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboardRes = await ApiService.getAdminDashboard();
      final usersRes = await ApiService.getAdminUsers();

      final dashboardJson = _decode(dashboardRes.body);
      final usersJson = _decode(usersRes.body);

      if (dashboardRes.statusCode != 200 || dashboardJson['success'] != true) {
        throw Exception(dashboardJson['message'] ?? 'Failed to load dashboard');
      }
      if (usersRes.statusCode != 200 || usersJson['success'] != true) {
        throw Exception(usersJson['message'] ?? 'Failed to load users');
      }

      final stats = (dashboardJson['data']?['stats'] ?? {}) as Map<String, dynamic>;
      final users = (usersJson['data']?['users'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();

      setState(() {
        _totalUsers = (stats['totalUsers'] ?? 0) as int;
        _activeUsers = (stats['activeUsers'] ?? 0) as int;
        _totalGroups = (stats['totalGroups'] ?? 0) as int;
        _totalAnnouncements = (stats['totalAnnouncements'] ?? 0) as int;
        _faculties = users.where((u) => u.role == 'faculty').toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createFaculty() async {
    if (!_facultyFormKey.currentState!.validate()) return;
    final payload = {
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'department': _department.text.trim(),
      'registrationNumber': _regNo.text.trim(),
    };
    final response = await ApiService.createFaculty(payload);
    final jsonData = _decode(response.body);
    if (response.statusCode != 201 || jsonData['success'] != true) {
      _showSnack(jsonData['message'] ?? 'Failed to create faculty');
      return;
    }
    _username.clear();
    _email.clear();
    _password.clear();
    _firstName.clear();
    _lastName.clear();
    _department.clear();
    _regNo.clear();
    await _load();
    _showSnack('Faculty created');
  }

  Future<void> _deleteFaculty(User faculty) async {
    final response = await ApiService.deleteFaculty(faculty.id);
    final jsonData = _decode(response.body);
    if (response.statusCode != 200 || jsonData['success'] != true) {
      _showSnack(jsonData['message'] ?? 'Failed to delete faculty');
      return;
    }
    await _load();
    _showSnack('Faculty deleted');
  }

  Future<void> _deleteStudentByRegNo() async {
    final regNo = _studentDeleteRegNo.text.trim();
    if (regNo.isEmpty) {
      _showSnack('Enter a registration number');
      return;
    }
    final response = await ApiService.deleteStudentByRegNo(regNo);
    final jsonData = _decode(response.body);
    if (response.statusCode != 200 || jsonData['success'] != true) {
      _showSnack(jsonData['message'] ?? 'Failed to delete student');
      return;
    }
    _studentDeleteRegNo.clear();
    await _load();
    _showSnack('Student deleted');
  }

  Future<void> _cleanupExpiredStudents() async {
    final response = await ApiService.cleanupExpiredCecAssembleStudents();
    final jsonData = _decode(response.body);
    if (response.statusCode != 200 || jsonData['success'] != true) {
      _showSnack(jsonData['message'] ?? 'Cleanup failed');
      return;
    }
    final removed = jsonData['data']?['removedCount'] ?? 0;
    await _load();
    _showSnack('Cleanup complete. Removed: $removed');
  }

  Future<void> _pickNoteFile() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Unable to read selected file');
      return;
    }
    final ext = (file.extension ?? '').toLowerCase();
    final mime = _mimeTypeFromExt(ext);
    setState(() {
      _pickedNoteDataUri = _toDataUri(bytes, mime);
      _pickedNoteName = file.name;
      _noteUrl.text = '';
    });
  }

  String _mimeTypeFromExt(String ext) {
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc') return 'application/msword';
    if (ext == 'docx') {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (ext == 'ppt') return 'application/vnd.ms-powerpoint';
    if (ext == 'pptx') {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (ext == 'txt') return 'text/plain';
    return 'application/octet-stream';
  }

  String _toDataUri(Uint8List bytes, String mimeType) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  Future<void> _uploadNote() async {
    final title = _noteTitle.text.trim();
    final code = _noteCourseCode.text.trim().toUpperCase();
    if (title.isEmpty || code.isEmpty) {
      _showSnack('Title and Course Code are required');
      return;
    }

    final resourceUrl = _pickedNoteDataUri ?? _noteUrl.text.trim();

    final response = await ApiService.createStudyMaterial({
      'title': title,
      'description': _noteDesc.text.trim(),
      'courseCode': code,
      'subjectName': _noteSubject.text.trim(),
      'department': _noteDepartment.text.trim(),
      'semester': _noteSemester.text.trim(),
      'materialType': _noteMaterialType,
      'resourceUrl': resourceUrl,
      'tags': _noteTags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
    });
    final jsonData = _decode(response.body);
    if (response.statusCode != 201 || jsonData['success'] != true) {
      _showSnack(jsonData['message'] ?? 'Failed to upload note');
      return;
    }

    _noteTitle.clear();
    _noteDesc.clear();
    _noteCourseCode.clear();
    _noteSubject.clear();
    _noteDepartment.clear();
    _noteSemester.clear();
    _noteTags.clear();
    _noteUrl.clear();
    setState(() {
      _pickedNoteDataUri = null;
      _pickedNoteName = null;
      _noteMaterialType = 'notes';
    });
    _showSnack('Note uploaded successfully');
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _department.dispose();
    _regNo.dispose();
    _studentDeleteRegNo.dispose();
    _noteTitle.dispose();
    _noteDesc.dispose();
    _noteCourseCode.dispose();
    _noteSubject.dispose();
    _noteDepartment.dispose();
    _noteSemester.dispose();
    _noteTags.dispose();
    _noteUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null || user.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Admin access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        actions: [
          IconButton(
            tooltip: 'Open main portal',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
            },
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _statCard('Total Users', _totalUsers.toString()),
                        _statCard('Active Users', _activeUsers.toString()),
                        _statCard('Announcements', _totalAnnouncements.toString()),
                        _statCard('Groups', _totalGroups.toString()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Upload Notes', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteTitle,
                              decoration: const InputDecoration(labelText: 'Title *'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteDesc,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(labelText: 'Description'),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _noteCourseCode,
                                    decoration: const InputDecoration(labelText: 'Course Code *'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _noteMaterialType,
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
                                      setState(() => _noteMaterialType = value);
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
                                    controller: _noteSubject,
                                    decoration: const InputDecoration(labelText: 'Subject'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _noteDepartment,
                                    decoration: const InputDecoration(labelText: 'Department'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _noteSemester,
                                    decoration: const InputDecoration(labelText: 'Semester'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _noteTags,
                                    decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteUrl,
                              decoration: const InputDecoration(labelText: 'Resource URL (optional if file selected)'),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickNoteFile,
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: const Text('Attach File'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _pickedNoteName ?? 'No file attached',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            FilledButton(
                              onPressed: _uploadNote,
                              child: const Text('Upload Note'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delete Student By Registration Number',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _studentDeleteRegNo,
                                    decoration: const InputDecoration(
                                      labelText: 'e.g. CEC23CS065',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _deleteStudentByRegNo,
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: _cleanupExpiredStudents,
                              child: const Text('Cleanup Expired CEC ASSEMBLE Students'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Form(
                          key: _facultyFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add Faculty', style: TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _username,
                                decoration: const InputDecoration(labelText: 'Username'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email'),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Password'),
                                validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstName,
                                      decoration: const InputDecoration(labelText: 'First Name'),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastName,
                                      decoration: const InputDecoration(labelText: 'Last Name'),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _department,
                                decoration: const InputDecoration(labelText: 'Department (optional)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _regNo,
                                decoration: const InputDecoration(labelText: 'Employee ID (optional)'),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _createFaculty,
                                child: const Text('Create Faculty'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Faculty (${_faculties.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            if (_faculties.isEmpty) const Text('No faculty records'),
                            ..._faculties.map((f) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${f.firstName} ${f.lastName}'.trim()),
                                  subtitle: Text('${f.email}${f.registrationNumber != null && f.registrationNumber!.isNotEmpty ? ' • ${f.registrationNumber}' : ''}'),
                                  trailing: TextButton(
                                    onPressed: () => _deleteFaculty(f),
                                    child: const Text('Delete'),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _statCard(String title, String value) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
