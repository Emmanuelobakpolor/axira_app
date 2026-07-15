import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/error_snackbar.dart';

const _kBlue = Color(0xFF0E24A0);const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBg = Color(0xFFF2F4F8);

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

  // Change these to your actual numbers
  static const String _whatsappNumber = '+2349032558567'; // e.g. +2349012345678
  static const String _phoneNumber = '+2349032558567';

  Future<void> _launchWhatsApp(BuildContext context) async {
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$_whatsappNumber?text=Hi,%20I%20need%20help%20with%20my%20account.",
    );

    try {
      final canLaunch = await canLaunchUrl(whatsappUri);
      if (!context.mounted) return;
      if (canLaunch) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        HapticFeedback.lightImpact();
      } else {
        showErrorSnackbar(context, 'Could not open WhatsApp');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, 'Failed to open WhatsApp');
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    final Uri phoneUri = Uri.parse('tel:$_phoneNumber');

    try {
      final canLaunch = await canLaunchUrl(phoneUri);
      if (!context.mounted) return;
      if (canLaunch) {
        await launchUrl(phoneUri);
        HapticFeedback.lightImpact();
      } else {
        showErrorSnackbar(context, 'Could not make call');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, 'Failed to make call');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBlue,
              ),
              child: const Icon(
                Icons.headset_mic_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Support',
                    style: TextStyle(
                      color: _kDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'We\'re here to help',
                    style: TextStyle(color: _kGrey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              Icon(
                Icons.support_agent_rounded,
                size: 90,
                color: _kBlue.withValues(alpha: 0.9),
              ),

              const SizedBox(height: 24),

              const Text(
                'How would you like to reach us?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _kDark,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Our team usually replies within minutes',
                style: TextStyle(fontSize: 15, color: _kGrey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 50),

              // WhatsApp Button
              _SupportButton(
                icon: Icons.chat_bubble_rounded,
                title: 'Chat on WhatsApp',
                subtitle: _whatsappNumber,
                color: const Color(0xFF25D366),
                onTap: () => _launchWhatsApp(context),
              ),

              const SizedBox(height: 16),

              // Call Button
              _SupportButton(
                icon: Icons.phone_rounded,
                title: 'Call Us Now',
                subtitle: _phoneNumber,
                color: _kBlue,
                onTap: () => _makePhoneCall(context),
              ),

              const Spacer(),

              Text(
                'Available 24/7',
                style: TextStyle(
                  fontSize: 13,
                  color: _kGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SupportButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _kDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 15, color: _kGrey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _kGrey),
            ],
          ),
        ),
      ),
    );
  }
}