import 'package:flutter/material.dart';
import 'auth/create_account_screen.dart';
import 'auth/sign_in_screen.dart';
import '../services/token_storage.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Background: gentle zoom so the art feels alive without distracting.
  late Animation<double> _bgScale;
  late Animation<double> _bgFade;

  // Diagonal light sweep that glides across the wordmark once.
  late Animation<double> _shimmerPosition;
  late Animation<double> _shimmerOpacity;

  // Glow pulse that breathes behind the mark.
  late Animation<double> _glowPulse;

  // Tagline + loader fade in last.
  late Animation<double> _taglineFade;
  late Animation<double> _taglineSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _bgScale = Tween<double>(begin: 1.12, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _shimmerPosition = Tween<double>(begin: -1.4, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.62, curve: Curves.easeInOut),
      ),
    );

    _shimmerOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.62, curve: Curves.linear),
      ),
    );

    _glowPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeInOut),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );

    _taglineSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (!mounted) return;
      final hasToken = await TokenStorage().hasToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              hasToken ? const DashboardScreen() : const OnboardingScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1C),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Solid navy base matching the artwork's own background, so the
              // square image can sit at a controlled size without stretching
              // to fill (and blowing up) a tall phone screen.
              const ColoredBox(color: Color(0xFF080D1C)),

              // Branded artwork, sized to a sane fraction of the screen and
              // centered, with its edges feathered into the navy background
              // so no rectangular border is ever visible — gently zooming
              // + fading in.
              Center(
                child: Opacity(
                  opacity: _bgFade.value,
                  child: Transform.scale(
                    scale: _bgScale.value,
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      child: AspectRatio(
                        aspectRatio: 0.5,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const RadialGradient(
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.62, 1.0],
                          ).createShader(rect),
                          child: Image.asset(
                            'src/assets/splash_background.jpeg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Diagonal shimmer sweep gliding once across the wordmark.
              IgnorePointer(
                child: Opacity(
                  opacity: _shimmerOpacity.value,
                  child: Align(
                    alignment: Alignment(_shimmerPosition.value, 0),
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 90,
                        height: MediaQuery.of(context).size.height * 1.4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.14),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Breathing glow behind the mark for extra polish.
              Center(
                child: Opacity(
                  opacity: (0.25 + 0.20 * _glowPulse.value).clamp(0.0, 1.0),
                  child: Container(
                    width: 260 + (30 * _glowPulse.value),
                    height: 260 + (30 * _glowPulse.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF3B6BFF).withValues(alpha: 0.55),
                          const Color(0xFF3B6BFF).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Foreground content: tagline + loader, anchored below the
              // wordmark that already sits in the background artwork.
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _taglineSlide.value),
                      child: Opacity(
                        opacity: _taglineFade.value,
                        child: Column(
                          children: [
                            Text(
                              'INVEST. TRADE. GROW.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  const Color(0xFF6E9BFF).withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0E24A0),
        child: SafeArea(
          child: Column(
            children: [
              // Illustration area
              Expanded(
                flex: 55,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size.width * 0.82,
                      height: size.width * 0.82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Container(
                      width: size.width * 0.62,
                      height: size.width * 0.62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Image.asset(
                      'assets/ONBOARDING.png',
                      width: size.width * 0.92,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),

              // Text and CTA area
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Easy Way to\nInvest in Crypto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 45,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A new way to manage and trade all your\ncrypto easily and fastest in the market',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 17,
                          height: 1.55,
                        ),
                      ),
                      const Spacer(),
                      // Get Started → Create Account flow
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CreateAccountScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0E24A0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SignInScreen(),
                            ),
                          ),
                          child: RichText(
                            text: TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'Sign in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
