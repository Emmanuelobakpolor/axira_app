import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import 'sign_in_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0 = identifier, 1 = OTP, 2 = new password
  String _sessionId = '';
  String _maskedIdentifier = '';
  bool _isLoading = false;

  // Step 0
  final _identifierCtrl = TextEditingController();

  // Step 1
  final List<TextEditingController> _otpCtrl =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(4, (_) => FocusNode());
  String get _otp => _otpCtrl.map((c) => c.text).join();

  // Step 2
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    for (final c in _otpCtrl) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // Mask email as j***e@domain.com, phone as *****6789
  String _mask(String s) {
    if (s.contains('@')) {
      final at = s.indexOf('@');
      final local = s.substring(0, at);
      final masked = local.length <= 2
          ? local
          : '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}';
      return '$masked${s.substring(at)}';
    }
    return s.length <= 4
        ? s
        : '${'*' * (s.length - 4)}${s.substring(s.length - 4)}';
  }

  // ── Step 0: send OTP ────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final id = _identifierCtrl.text.trim();
    if (id.isEmpty) {
      showErrorSnackbar(context,'Enter your email or phone number.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final sid = await AuthService.forgotPassword(id);
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _maskedIdentifier = _mask(id);
        _step = 1;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context,e.message);
    }
  }

  // ── Step 1: verify OTP ──────────────────────────────────────────────────────

  void _onOtpChange(int i, String v) {
    if (v.length == 1 && i < 3) _otpFocus[i + 1].requestFocus();
    if (v.isEmpty && i > 0) _otpFocus[i - 1].requestFocus();
    setState(() {});
  }

  void _clearOtp() {
    for (final c in _otpCtrl) {
      c.clear();
    }
    if (_otpFocus.isNotEmpty) _otpFocus[0].requestFocus();
    setState(() {});
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.verifyResetOtp(sessionId: _sessionId, otp: _otp);
      if (!mounted) return;
      setState(() {
        _step = 2;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context,e.message);
      _clearOtp();
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final sid =
          await AuthService.forgotPassword(_identifierCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _sessionId = sid;
        _isLoading = false;
      });
      _clearOtp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('New code sent.'),
        behavior: SnackBarBehavior.floating,
      ));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context,e.message);
    }
  }

  // ── Step 2: set new password ────────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final pw = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pw.length < 8) {
      showErrorSnackbar(context,'Password must be at least 8 characters.');
      return;
    }
    if (pw != confirm) {
      showErrorSnackbar(context,'Passwords do not match.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.resetPassword(
          sessionId: _sessionId, newPassword: pw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset! Please sign in.'),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showErrorSnackbar(context,e.message);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: [_buildStep0, _buildStep1, _buildStep2][_step](),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                AuthBackButton(onPressed: () => Navigator.maybePop(context)),
                const SizedBox(height: 32),
                const Text(
                  'Forgot Password',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: kAuthTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Enter your email or phone and we'll send you a verification code.",
                  style: TextStyle(fontSize: 17, color: kAuthTextGrey),
                ),
                const SizedBox(height: 32),
                const AuthFieldLabel('Email or Phone Number'),
                const SizedBox(height: 8),
                AuthInputField(
                  controller: _identifierCtrl,
                  hint: 'example@email.com or +2348000000000',
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AuthPrimaryButton(label: 'Send Code', onPressed: _sendOtp),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    final isComplete = _otp.length == 4;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                AuthBackButton(
                  onPressed: () =>
                      setState(() {
                        _step = 0;
                        _clearOtp();
                      }),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Enter Code',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: kAuthTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We sent a 4-digit code to $_maskedIdentifier',
                  style: const TextStyle(fontSize: 17, color: kAuthTextGrey),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (i) => _OtpBox(
                      controller: _otpCtrl[i],
                      focusNode: _otpFocus[i],
                      onChanged: (v) => _onOtpChange(i, v),
                      isFilled: _otpCtrl[i].text.isNotEmpty,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _resendOtp,
                    child: const Text(
                      "Didn't receive code? Resend",
                      style: TextStyle(color: kAuthBlue, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AuthPrimaryButton(
                  label: 'Verify',
                  onPressed: isComplete ? _verifyOtp : null,
                ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final canSubmit =
        _passwordCtrl.text.isNotEmpty && _confirmCtrl.text.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                AuthBackButton(
                    onPressed: () => setState(() => _step = 1)),
                const SizedBox(height: 32),
                const Text(
                  'New Password',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w500,
                    color: kAuthTextDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create a new password for your account.',
                  style: TextStyle(fontSize: 17, color: kAuthTextGrey),
                ),
                const SizedBox(height: 32),
                const AuthFieldLabel('New Password'),
                const SizedBox(height: 8),
                AuthInputField(
                  controller: _passwordCtrl,
                  hint: 'Min. 8 characters',
                  obscure: _obscurePass,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: kAuthTextGrey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthFieldLabel('Confirm Password'),
                const SizedBox(height: 8),
                AuthInputField(
                  controller: _confirmCtrl,
                  hint: 'Re-enter your password',
                  obscure: _obscureConfirm,
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
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AuthPrimaryButton(
                  label: 'Reset Password',
                  onPressed: canSubmit ? _resetPassword : null,
                ),
        ),
      ],
    );
  }
}

// OTP input box (mirrors VerifyOtpScreen._OtpBox)
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isFilled;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isFilled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 58,
      decoration: BoxDecoration(
        color: kAuthFieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFilled ? kAuthBlue : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: kAuthTextDark,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
