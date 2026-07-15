import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/token_storage.dart';
import 'customer_support_chat_screen.dart';
import 'notifications_screen.dart';
import 'profile_settings_screen.dart';
import 'transaction_history_screen.dart';
import '../auth/sign_in_screen.dart';

const _kBlue = Color(0xFF0E24A0);const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBg = Color(0xFFF2F4F8);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out of Axira?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final storage = TokenStorage();
    final refresh = await storage.getRefresh();

    if (refresh != null && refresh.isNotEmpty) {
      await AuthService.logout(refresh: refresh);
    } else {
      await storage.clear();
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete your Axira account and all of its data. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final password = passwordController.text;
    if (password.isEmpty) return;

    try {
      await AuthService.deleteAccount(password: password);
    } on AuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _kDark,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.account_circle_outlined,
              label: 'Profile Settings',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileSettingsScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              label: 'Transaction History',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notification',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              label: 'Customer Support',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerSupportScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              isRed: true,
              onTap: () => _signOut(context),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.delete_forever_outlined,
              label: 'Delete Account',
              isRed: true,
              onTap: () => _deleteAccount(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isRed;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isRed = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRed ? const Color(0xFFEF4444) : _kBlue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isRed ? color : _kDark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _kGrey, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
