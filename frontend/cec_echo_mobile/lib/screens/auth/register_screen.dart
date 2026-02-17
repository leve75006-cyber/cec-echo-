import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  bool _isSubmitting = false;
  String _role = 'student';

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withValues(alpha: 0.18),
              scheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: themeProvider.isDark ? 'Light mode' : 'Dark mode',
                  icon: Icon(
                    themeProvider.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  onPressed: themeProvider.toggleTheme,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Create Account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 40),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Join CEC ECHO and start collaborating in real-time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(labelText: 'Username'),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Username is required';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Username must be at least 3 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameController,
                                        decoration:
                                            const InputDecoration(labelText: 'First Name'),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameController,
                                        decoration: const InputDecoration(labelText: 'Last Name'),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                        .hasMatch(value.trim())) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _role,
                                  decoration: const InputDecoration(labelText: 'Role'),
                                  items: const [
                                    DropdownMenuItem(value: 'student', child: Text('Student')),
                                    DropdownMenuItem(value: 'faculty', child: Text('Faculty')),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _role = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _departmentController,
                                  decoration:
                                      const InputDecoration(labelText: 'Department (optional)'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _registrationNumberController,
                                  decoration: InputDecoration(
                                    labelText: _role == 'faculty'
                                        ? 'Employee ID (optional)'
                                        : 'Registration Number (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: const InputDecoration(labelText: 'Password'),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (value.length < 6) {
                                      return 'At least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                if (_isSubmitting)
                                  const LinearProgressIndicator()
                                else
                                  ElevatedButton(
                                    onPressed: _submit,
                                    child: const Text(
                                      'Create Account',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                if (authProvider.errorMessage != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: scheme.error),
                                    ),
                                    child: Text(
                                      authProvider.errorMessage!,
                                      style: TextStyle(color: scheme.onErrorContainer),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final payload = <String, dynamic>{
      'username': _usernameController.text.trim(),
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'role': _role,
      if (_departmentController.text.trim().isNotEmpty)
        'department': _departmentController.text.trim(),
      if (_registrationNumberController.text.trim().isNotEmpty)
        'registrationNumber': _registrationNumberController.text.trim(),
    };

    final success = await authProvider.register(payload);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'Registration failed'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }
}
