import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/profile_avatar.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kDisabled = Color(0xFFBFD7FC);
const _kFieldBg = Color(0xFFF3F4F6);

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _originalName = '';
  String _originalPhone = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _loadError;

  bool get _dirty =>
      _nameCtrl.text.trim() != _originalName ||
      _phoneCtrl.text.trim() != _originalPhone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final user = await AdminService.getProfile();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _originalName = user.fullName;
        _originalPhone = user.phone;
        _loading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final user = await AdminService.updateProfilePhoto(File(picked.path));
      if (!mounted) return;
      // Push update to the global notifier so the avatar refreshes everywhere
      AuthService.currentUserNotifier.value = user;
      setState(() {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _originalName = user.fullName;
        _originalPhone = user.phone;
      });
      _toast('Photo updated.');
    } on AdminException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.length < 2) {
      showErrorSnackbar(context, 'Name must be at least 2 characters.');
      return;
    }
    if (phone.isEmpty) {
      showErrorSnackbar(context, 'Phone is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await AdminService.updateProfile(fullName: name, phone: phone);
      if (!mounted) return;
      AuthService.currentUserNotifier.value = user;
      setState(() {
        _originalName = user.fullName;
        _originalPhone = user.phone;
      });
      _toast('Profile updated.');
    } on AdminException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Settings',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError != null
              ? _ErrorBody(message: _loadError!, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Center(
                  child: GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickPhoto,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: ValueListenableBuilder<AuthUser?>(
                        valueListenable: AuthService.currentUserNotifier,
                        builder: (_, user, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            ProfileAvatar(
                              user: user,
                              radius: 44,
                              showEditBadge: !_uploadingPhoto,
                              onTap: null,
                            ),
                            if (_uploadingPhoto)
                              const SizedBox(
                                width: 88,
                                height: 88,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color(0x66000000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Admin badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Administrator',
                      style: TextStyle(
                          color: _kBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _Label('Full Name'),
                const SizedBox(height: 6),
                _Field(
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                _Label('Email'),
                const SizedBox(height: 6),
                _Field(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  enabled: false,
                ),
                const SizedBox(height: 20),

                _Label('Phone Number'),
                const SizedBox(height: 6),
                _Field(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _dirty && !_saving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                disabledBackgroundColor: _kDisabled,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white)),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kGrey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: _kDark),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters = const [],
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 15,
          color: enabled ? _kDark : _kGrey,
          fontWeight: FontWeight.w400),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? _kFieldBg : const Color(0xFFE5E7EB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
      ),
    );
  }
}
