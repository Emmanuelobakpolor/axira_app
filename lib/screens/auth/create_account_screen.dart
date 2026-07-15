import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'auth_widgets.dart';
import 'verify_otp_screen.dart';
import 'sign_in_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';

// ─── Country data ─────────────────────────────────────────────────────────────

class _Country {
  final String flag;
  final String name;
  final String dialCode;
  const _Country(this.flag, this.name, this.dialCode);
}

const _kCountries = [
  _Country('🇳🇬', 'Nigeria', '+234'),
  _Country('🇬🇭', 'Ghana', '+233'),
  _Country('🇰🇪', 'Kenya', '+254'),
  _Country('🇿🇦', 'South Africa', '+27'),
  _Country('🇪🇬', 'Egypt', '+20'),
  _Country('🇹🇿', 'Tanzania', '+255'),
  _Country('🇺🇬', 'Uganda', '+256'),
  _Country('🇷🇼', 'Rwanda', '+250'),
  _Country('🇸🇳', 'Senegal', '+221'),
  _Country('🇨🇮', 'Côte d\'Ivoire', '+225'),
  _Country('🇨🇲', 'Cameroon', '+237'),
  _Country('🇿🇲', 'Zambia', '+260'),
  _Country('🇿🇼', 'Zimbabwe', '+263'),
  _Country('🇪🇹', 'Ethiopia', '+251'),
  _Country('🇸🇱', 'Sierra Leone', '+232'),
  _Country('🇱🇷', 'Liberia', '+231'),
  _Country('🇬🇧', 'United Kingdom', '+44'),
  _Country('🇺🇸', 'United States', '+1'),
  _Country('🇨🇦', 'Canada', '+1'),
  _Country('🇩🇪', 'Germany', '+49'),
  _Country('🇫🇷', 'France', '+33'),
  _Country('🇮🇹', 'Italy', '+39'),
  _Country('🇪🇸', 'Spain', '+34'),
  _Country('🇳🇱', 'Netherlands', '+31'),
  _Country('🇦🇪', 'UAE', '+971'),
  _Country('🇸🇦', 'Saudi Arabia', '+966'),
  _Country('🇮🇳', 'India', '+91'),
  _Country('🇨🇳', 'China', '+86'),
  _Country('🇧🇷', 'Brazil', '+55'),
  _Country('🇦🇺', 'Australia', '+61'),
];

// ─── Country picker bottom sheet ──────────────────────────────────────────────

void _showCountryPicker(
  BuildContext context, {
  required _Country selected,
  required ValueChanged<_Country> onSelect,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CountryPickerSheet(selected: selected, onSelect: onSelect),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final _Country selected;
  final ValueChanged<_Country> onSelect;
  const _CountryPickerSheet({required this.selected, required this.onSelect});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _search = TextEditingController();
  List<_Country> _filtered = _kCountries;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = _kCountries
          .where((c) =>
              c.name.toLowerCase().contains(lower) ||
              c.dialCode.contains(lower))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Select Country',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 14),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              decoration: InputDecoration(
                hintText: 'Search country or dial code',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kAuthBlue, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSelected = c.dialCode == widget.selected.dialCode && c.name == widget.selected.name;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(c.name, style: const TextStyle(fontSize: 15, color: Color(0xFF111827))),
                  trailing: Text(
                    c.dialCode,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? kAuthBlue : const Color(0xFF6B7280),
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: const Color(0xFFF0F4FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () {
                    widget.onSelect(c);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Create Account Screen ────────────────────────────────────────────────────

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  _Country _selectedCountry = _kCountries.first; // Nigeria default
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _buildPhone() {
    // Strip leading zeros from what the user typed, then prepend dial code
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    final digits = raw.startsWith('0') ? raw.substring(1) : raw;
    return '${_selectedCountry.dialCode}$digits';
  }

  Future<void> _onContinue() async {
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim();

    if (email.isEmpty || rawPhone.isEmpty) {
      showErrorSnackbar(context, 'Please fill in all fields.');
      return;
    }

    final phone = _buildPhone();

    setState(() => _isLoading = true);
    try {
      final result = await AuthService.startSignup(email: email, phone: phone);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            sessionId: result.sessionId,
            email: email,
          ),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        color: kAuthTextDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Welcome. Please enter your details',
                      style: TextStyle(fontSize: 17, color: kAuthTextGrey),
                    ),
                    const SizedBox(height: 32),
                    const AuthFieldLabel('Email Address'),
                    const SizedBox(height: 8),
                    AuthInputField(
                      controller: _emailController,
                      hint: 'example@email.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    const AuthFieldLabel('Phone Number'),
                    const SizedBox(height: 8),
                    _PhoneField(
                      controller: _phoneController,
                      country: _selectedCountry,
                      onCountryTap: () => _showCountryPicker(
                        context,
                        selected: _selectedCountry,
                        onSelect: (c) => setState(() => _selectedCountry = c),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AuthPrimaryButton(
                      label: 'Continue',
                      onPressed: _onContinue,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: kAuthTextGrey, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(color: kAuthBlue, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Phone field with dial code prefix ───────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final _Country country;
  final VoidCallback onCountryTap;

  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kAuthFieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Dial code selector
          GestureDetector(
            onTap: onCountryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    country.dialCode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kAuthTextDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: kAuthTextGrey),
                ],
              ),
            ),
          ),
          // Phone number input
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              // 10 digits, +1 to allow a leading 0 for local-format entry
              // (stripped before the dial code is prepended, see _buildPhone).
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14, color: kAuthTextDark),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '8012345678',
                hintStyle: TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
