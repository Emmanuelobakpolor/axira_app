import 'package:flutter/material.dart';

class BrandImage extends StatelessWidget {
  final String src;
  final double height;
  final double? width;
  final BoxFit fit;

  const BrandImage(
    this.src, {
    super.key,
    this.height = 52,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.card_giftcard,
      size: height * 0.75,
      color: const Color(0xFF9CA3AF),
    );

    if (src.isEmpty) return placeholder;

    if (src.startsWith('http')) {
      return Image.network(
        src,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
      );
    }

    return Image.asset(
      src,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
