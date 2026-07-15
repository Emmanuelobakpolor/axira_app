import 'package:flutter/material.dart';
import 'auth_widgets.dart';
import '../dashboard_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';

class TransactionPinScreen extends StatefulWidget {
  final String sessionId;
  final String fullName;
  final String password;
  final bool isConfirm;
  final String firstPin;

  const TransactionPinScreen({
    super.key,
    required this.sessionId,
    required this.fullName,
    required this.password,
    this.isConfirm = false,
    this.firstPin = '',
  });

  @override
  State<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends State<TransactionPinScreen> {
  String _pin = '';
  bool _isLoading = false;

  void _onKey(String key) {
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else if (key != '+*#' && _pin.length < 4) {
      setState(() => _pin += key);
    }
  }

  void _onConfirm() {
    if (!widget.isConfirm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionPinScreen(
            sessionId: widget.sessionId,
            fullName: widget.fullName,
            password: widget.password,
            isConfirm: true,
            firstPin: _pin,
          ),
        ),
      );
    } else {
      if (_pin != widget.firstPin) {
        showErrorSnackbar(context, 'PINs do not match. Please try again.');
        setState(() => _pin = '');
        return;
      }
      _completeSignup();
    }
  }

  Future<void> _completeSignup() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.completeSignup(
        sessionId: widget.sessionId,
        fullName: widget.fullName,
        password: widget.password,
        transactionPin: _pin,
      );
      await AuthService.saveAuthResult(result);
      if (!mounted) return;
      _showSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      // The PIN itself is fine — any 4 digits are accepted.
      // Errors here come from password or session validation on the server.
      // Show a clear dialog so the user knows to fix their password, not the PIN,
      // then pop both PIN screens back to SetupProfileScreen.
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFB91C1C), size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your PIN is fine — check your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kAuthTextDark),
                ),
                const SizedBox(height: 8),
                Text(
                  '${e.message}\n\nYou\'ll be taken back to the profile screen so you can update your password.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: kAuthTextGrey, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAuthBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Fix password',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      // Pop confirm-PIN screen and first-PIN screen to land on SetupProfileScreen
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        onProceed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _pin.length == 4;
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height;
    final hPad = sw * 0.062;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55,
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, sh * 0.02, hPad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthBackButton(),
                    SizedBox(height: sh * 0.035),
                    Text(
                      widget.isConfirm
                          ? 'Confirm Transaction Pin'
                          : 'Set Transaction Pin',
                      style: TextStyle(
                        fontSize: (sw * 0.1).clamp(26.0, 44.0),
                        fontWeight: FontWeight.w500,
                        color: kAuthTextDark,
                      ),
                    ),
                    SizedBox(height: sh * 0.007),
                    Text(
                      widget.isConfirm
                          ? 'Enter the four digit number again to confirm your PIN'
                          : 'Enter a four digit number to use for transactions',
                      style: TextStyle(
                        fontSize: (sw * 0.043).clamp(13.0, 18.0),
                        color: kAuthTextGrey,
                      ),
                    ),
                    SizedBox(height: sh * 0.04),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final filled = i < _pin.length;
                        final dotSize = (sw * 0.032).clamp(10.0, 14.0);
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: sw * 0.018),
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? kAuthBlue : Colors.transparent,
                            border: Border.all(
                              color: filled
                                  ? kAuthBlue
                                  : const Color(0xFFD1D5DB),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : AuthPrimaryButton(
                            label: 'Confirm',
                            onPressed: isComplete ? _onConfirm : null,
                          ),
                    SizedBox(height: sh * 0.012),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 45,
              child: _Numpad(onKey: _isLoading ? (_) {} : _onKey),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _Numpad({required this.onKey});

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['+*#', '0', '⌫'],
  ];

  static const _letters = [
    ['', 'ABC', 'DEF'],
    ['GHI', 'JKL', 'MNO'],
    ['PQRS', 'TUV', 'WXYZ'],
    ['', '', ''],
  ];

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final hPad = (sw * 0.015).clamp(4.0, 8.0);
    final vPad = (sw * 0.01).clamp(4.0, 8.0);

    return Container(
      color: const Color(0xFFF1F3F5),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Column(
        children: List.generate(4, (row) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vPad),
              child: Row(
                children: List.generate(3, (col) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad + 1),
                      child: _NumpadKey(
                        number: _keys[row][col],
                        letters: _letters[row][col],
                        onTap: () => onKey(_keys[row][col]),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NumpadKey extends StatelessWidget {
  final String number;
  final String letters;
  final VoidCallback onTap;

  const _NumpadKey({
    required this.number,
    required this.letters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final bool isSpecial = number == '+*#' || number == '⌫';
    final numFontSize = (sw * 0.078).clamp(22.0, 36.0);
    final letterFontSize = (sw * 0.025).clamp(8.0, 12.0);
    final iconSize = (sw * 0.072).clamp(20.0, 32.0);

    if (number == '⌫') {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(Icons.backspace_outlined,
                size: iconSize, color: const Color(0xFF1F2937)),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  number == '+*#' ? '+ * #' : number,
                  style: TextStyle(
                    fontSize:
                        number == '0' ? numFontSize + 4 : numFontSize,
                    fontWeight: FontWeight.w500,
                    color: isSpecial
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF111827),
                    height: 1.0,
                  ),
                ),
                if (letters.isNotEmpty) const SizedBox(height: 2),
                if (letters.isNotEmpty)
                  Text(
                    letters,
                    style: TextStyle(
                      fontSize: letterFontSize,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Success sheet ─────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final VoidCallback onProceed;

  const _SuccessSheet({required this.onProceed});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height;
    final hPad = sw * 0.062;

    return Container(
      margin: EdgeInsets.only(top: sh * 0.19),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(hPad, sh * 0.043, hPad, sh * 0.047),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAuthBlue.withValues(alpha: 0.12),
            ),
            child: Container(
              height: (sw * 0.205).clamp(60.0, 90.0),
              width: (sw * 0.205).clamp(60.0, 90.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kAuthBlue.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: (sw * 0.108).clamp(32.0, 48.0),
              ),
            ),
          ),
          SizedBox(height: sh * 0.028),
          Text(
            'Account Created\nSuccessful!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (sw * 0.056).clamp(18.0, 26.0),
              fontWeight: FontWeight.bold,
              color: kAuthTextDark,
              height: 1.3,
            ),
          ),
          SizedBox(height: sh * 0.012),
          Text(
            'Your account has been created successfully',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (sw * 0.036).clamp(12.0, 16.0),
              color: kAuthTextGrey,
            ),
          ),
          SizedBox(height: sh * 0.038),
          AuthPrimaryButton(label: 'Proceed to Dashboard', onPressed: onProceed),
        ],
      ),
    );
  }
}
