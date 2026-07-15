import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'transaction_pin_screen.dart';

enum _PasswordStrength { none, weak, good, strong }

class SetupProfileScreen extends StatefulWidget {
  final String sessionId;

  const SetupProfileScreen({super.key, required this.sessionId});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _hasSymbol =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);
  bool get _passwordValid => _hasMinLength && _hasNumber && _hasSymbol;

  _PasswordStrength get _strength {
    final p = _passwordController.text;
    if (p.isEmpty) return _PasswordStrength.none;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[a-z]').hasMatch(p)) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    if (score <= 2) return _PasswordStrength.weak;
    if (score <= 4) return _PasswordStrength.good;
    return _PasswordStrength.strong;
  }

  bool get _confirmMatches =>
      _confirmController.text.isNotEmpty &&
      _confirmController.text == _passwordController.text;

  bool get _canContinue =>
      _nameController.text.trim().length >= 2 &&
      _passwordValid &&
      _confirmMatches;

  void _onContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionPinScreen(
          sessionId: widget.sessionId,
          fullName: _nameController.text.trim(),
          password: _passwordController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const AuthBackButton(),
                    const SizedBox(height: 32),
                    const Text(
                      'Set Up Profile',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color: kAuthTextDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter full name and password for your account',
                      style: TextStyle(fontSize: 17, color: kAuthTextGrey),
                    ),
                    const SizedBox(height: 32),
                    const AuthFieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _nameController,
                      hint: 'Enter your full name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('Password'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _passwordController,
                      hint: 'Enter password',
                      obscure: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kAuthTextGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    _StrengthMeter(strength: _strength),
                    const SizedBox(height: 8),
                    _RuleRow(met: _hasMinLength, label: 'At least 8 characters'),
                    _RuleRow(met: _hasNumber, label: 'Contains a number'),
                    _RuleRow(
                        met: _hasSymbol,
                        label: 'Contains a symbol (e.g. ! @ # \$)'),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _confirmController,
                      hint: 'Re-enter password',
                      obscure: _obscureConfirm,
                      onChanged: (_) => setState(() {}),
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: kAuthTextGrey,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    if (_confirmController.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _RuleRow(
                        met: _confirmMatches,
                        label: _confirmMatches
                            ? 'Passwords match'
                            : "Passwords don't match",
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: AuthPrimaryButton(
                label: 'Continue',
                onPressed: _canContinue ? _onContinue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rule row ───────────────────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  final bool met;
  final String label;
  const _RuleRow({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = met ? const Color(0xFF16A34A) : kAuthTextGrey;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.circle_outlined,
              size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ─── Strength meter ───────────────────────────────────────────────────────────

class _StrengthMeter extends StatelessWidget {
  final _PasswordStrength strength;
  const _StrengthMeter({required this.strength});

  @override
  Widget build(BuildContext context) {
    if (strength == _PasswordStrength.none) return const SizedBox.shrink();

    final String label;
    final Color color;
    final int segments;
    switch (strength) {
      case _PasswordStrength.weak:
        label = 'Weak';
        color = const Color(0xFFDC2626);
        segments = 1;
      case _PasswordStrength.good:
        label = 'Good';
        color = const Color(0xFFF59E0B);
        segments = 2;
      case _PasswordStrength.strong:
        label = 'Strong';
        color = const Color(0xFF16A34A);
        segments = 3;
      case _PasswordStrength.none:
        label = '';
        color = kAuthTextGrey;
        segments = 0;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < segments ? color : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
