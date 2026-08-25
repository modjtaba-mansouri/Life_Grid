import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLoggedIn;
  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _nameController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _birthdayController = TextEditingController();
  String _gender = 'Prefer not to say';
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final name = _nameController.text.trim();
    final passcode = _passcodeController.text.trim();
    final result = _isSignUp
        ? await _auth.signUp(
            name: name,
            gender: _gender,
            birthday: _birthdayController.text.trim(),
            passcode: passcode,
          )
        : await _auth.logIn(name: name, passcode: passcode);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success && result.user != null) {
      StorageService.currentUser = result.user;
      widget.onLoggedIn(result.user!);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'LIFE GRID',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isSignUp ? 'Create your account' : 'Log in',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                  const SizedBox(height: 28),
                  _field(_nameController, 'Name'),
                  const SizedBox(height: 12),
                  if (_isSignUp) ...[
                    _genderDropdown(),
                    const SizedBox(height: 12),
                    _field(_birthdayController, 'Birthday (e.g. 18/05/2001)'),
                    const SizedBox(height: 12),
                  ],
                  _field(_passcodeController, 'Passcode', obscure: true),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'CREATE ACCOUNT' : 'LOG IN'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                            }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Log in'
                          : 'New here? Create an account',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textDim, fontSize: 12),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _genderDropdown() {
    const options = ['Female', 'Male', 'Other', 'Prefer not to say'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _gender,
          isExpanded: true,
          dropdownColor: AppColors.bgElevated,
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          items: options
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v ?? _gender),
        ),
      ),
    );
  }
}
