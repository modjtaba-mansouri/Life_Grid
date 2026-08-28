import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLoggedIn;
  LoginScreen({super.key, required this.onLoggedIn});

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
            padding: EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'LIFE GRID',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _isSignUp ? 'Create your account' : 'Log in',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                  SizedBox(height: 28),
                  _field(_nameController, 'Name'),
                  SizedBox(height: 12),
                  if (_isSignUp) ...[
                    _genderDropdown(),
                    SizedBox(height: 12),
                    _field(_birthdayController, 'Birthday (e.g. 18/05/2001)'),
                    SizedBox(height: 12),
                  ],
                  _field(_passcodeController, 'Passcode', obscure: true),
                  SizedBox(height: 8),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: _loading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'CREATE ACCOUNT' : 'LOG IN'),
                    ),
                  ),
                  SizedBox(height: 12),
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
                      style: TextStyle(color: AppColors.textDim, fontSize: 12),
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
      style: TextStyle(color: AppColors.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textDim, fontSize: 12),
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _genderDropdown() {
    final options = ['Female', 'Male', 'Other', 'Prefer not to say'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
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
          style: TextStyle(color: AppColors.text, fontSize: 14),
          items: options
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v ?? _gender),
        ),
      ),
    );
  }
}
