import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _auth = AuthService();
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  Future<void> _submit() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await _auth.verifyCurrentPasscode(_controller.text.trim());
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Wrong passcode.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = StorageService.currentUser?.name ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, color: AppColors.accent, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Locked',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Enter your passcode to continue as $name',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDim, fontSize: 12),
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(color: AppColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Passcode',
                      labelStyle: TextStyle(color: AppColors.textDim, fontSize: 12),
                      filled: true,
                      fillColor: AppColors.bgCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checking ? null : _submit,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: _checking
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('UNLOCK'),
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
}
