import 'package:flutter/material.dart';

import '../screens/auth/sign_in_screen.dart';
import '../services/auth_service.dart';

Future<void> redirectToSignIn(BuildContext context) async {
  await AuthService.clearSession();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const SignInScreen()),
    (_) => false,
  );
}
