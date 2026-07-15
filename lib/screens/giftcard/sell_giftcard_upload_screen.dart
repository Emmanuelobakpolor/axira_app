import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/brand_image.dart';
import '../../widgets/error_snackbar.dart';
import 'sell_giftcard_confirm_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class SellGiftcardUploadScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;
  final String country;
  final String cardType;
  final double amountUsd;
  final double rateNgn;

  const SellGiftcardUploadScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
    required this.country,
    required this.cardType,
    required this.amountUsd,
    required this.rateNgn,
  });

  @override
  State<SellGiftcardUploadScreen> createState() =>
      _SellGiftcardUploadScreenState();
}

class _SellGiftcardUploadScreenState extends State<SellGiftcardUploadScreen> {
  final List<File> _images = [];
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (_images.length >= 10) {
      showErrorSnackbar(context, 'Maximum 10 images allowed.');
      return;
    }
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _images.add(File(picked.path)));
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
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
          'Sell Gift Card',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BrandCard(
                    name: widget.brandName,
                    asset: widget.brandAsset,
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Upload Giftcard',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can upload up to 10 photos',
                    style: const TextStyle(fontSize: 11, color: _kGrey),
                  ),
                  const SizedBox(height: 10),

                  if (_images.isEmpty)
                    GestureDetector(
                      onTap: _pickImage,
                      child: const _DashedUploadBox(),
                    )
                  else ...[
                    // Thumbnail grid
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._images.asMap().entries.map((e) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    e.value,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(e.key),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                        if (_images.length < 10)
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Icon(Icons.add,
                                  color: _kGrey, size: 28),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _images.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellGiftcardConfirmScreen(
                              brandName: widget.brandName,
                              brandAsset: widget.brandAsset,
                              country: widget.country,
                              cardType: widget.cardType,
                              amountUsd: widget.amountUsd,
                              rateNgn: widget.rateNgn,
                              images: List.unmodifiable(_images),
                            ),
                          ),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: const Color(0xFFBFD7FC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed upload box ────────────────────────────────────────────────────────

class _DashedUploadBox extends StatelessWidget {
  const _DashedUploadBox();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Color(0x1A0E24A0),
              child: Icon(Icons.camera_alt_outlined, color: _kBlue, size: 26),
            ),
            SizedBox(height: 14),
            Text(
              'Upload image of Giftcard',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kDark),
            ),
            SizedBox(height: 4),
            Text('Tap to choose from gallery',
                style: TextStyle(fontSize: 12, color: _kGrey)),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 16.0;
    final paint = Paint()
      ..color = const Color(0xFF0E24A0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}

// ─── Brand card ───────────────────────────────────────────────────────────────

class _BrandCard extends StatelessWidget {
  final String name;
  final String asset;
  final VoidCallback onClose;

  const _BrandCard(
      {required this.name, required this.asset, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              BrandImage(asset, height: 56),
              const SizedBox(height: 8),
              Text(name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kDark)),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
