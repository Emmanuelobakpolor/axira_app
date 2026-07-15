import 'package:flutter/material.dart';

/// Circular coin icon. Loads the real logo from [logoUrl] when available and
/// falls back to a colored letter badge while loading, on error, or offline.
class CoinLogo extends StatelessWidget {
  final String? logoUrl;
  final String letter;
  final Color letterColor;
  final Color backgroundColor;
  final double size;

  const CoinLogo({
    super.key,
    required this.logoUrl,
    required this.letter,
    required this.letterColor,
    required this.backgroundColor,
    this.size = 32,
  });

  Widget _fallback() => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: backgroundColor),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            color: letterColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return _fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(),
      ),
    );
  }
}
