import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/profile_avatar.dart';

const _kBlue = Color(0xFF0E24A0);const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kDisabled = Color(0xFFBFD7FC);
const _kFieldBg = Color(0xFFF3F4F6);

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _originalName = '';
  String _originalPhone = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _loadError;

  bool get _dirty {
    return _nameCtrl.text.trim() != _originalName ||
        _phoneCtrl.text.trim() != _originalPhone;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final user = await AuthService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _originalName = user.fullName;
        _originalPhone = user.phone;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final user = await AuthService.updateProfilePhoto(File(image.path));

      if (!mounted) return;

      setState(() {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _originalName = user.fullName;
        _originalPhone = user.phone;
        _isUploadingPhoto = false;
      });

      _showSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      showErrorSnackbar(context,e.message);
    }
  }

  Future<void> _saveChanges() async {
    final fullName = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (fullName.length < 2) {
      showErrorSnackbar(context,'Full name must be at least 2 characters.');
      return;
    }

    if (phone.isEmpty) {
      showErrorSnackbar(context,'Phone number is required.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = await AuthService.updateProfile(
        fullName: fullName,
        phone: phone,
      );

      if (!mounted) return;

      setState(() {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _originalName = user.fullName;
        _originalPhone = user.phone;
        _isSaving = false;
      });

      _showSuccess();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnackbar(context,e.message);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
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
              color: _kDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kDark),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUser,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
            color: _kDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickProfilePhoto,
                      child: Padding(
                        // Extends the hit area 28 px below the avatar Stack so
                        // the "Edit picture" badge (bottom: -14) is tappable.
                        padding: const EdgeInsets.only(bottom: 28),
                        child: ValueListenableBuilder<AuthUser?>(
                          valueListenable: AuthService.currentUserNotifier,
                          builder: (context, user, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              ProfileAvatar(
                                user: user,
                                radius: 44,
                                showEditBadge: !_isUploadingPhoto,
                                onTap: null,
                              ),
                              if (_isUploadingPhoto)
                                SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: DecoratedBox(
                                    decoration: const BoxDecoration(
                                      color: Color(0x66000000),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
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
                  const SizedBox(height: 12),
                  _FieldLabel('Full name'),
                  const SizedBox(height: 6),
                  _FilledField(
                    controller: _nameCtrl,
                    keyboardType: TextInputType.name,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  _FieldLabel('Email'),
                  const SizedBox(height: 6),
                  _FilledField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false,
                  ),
                  const SizedBox(height: 20),
                  _FieldLabel('Phone Number'),
                  const SizedBox(height: 6),
                  _FilledField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
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
                onPressed: _dirty && !_isSaving ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: _kDisabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _kDark,
      ),
    );
  }
}

class _FilledField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _FilledField({
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
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: enabled ? _kFieldBg : const Color(0xFFE5E7EB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBlue, width: 1.5),
        ),
      ),
    );
  }
}
