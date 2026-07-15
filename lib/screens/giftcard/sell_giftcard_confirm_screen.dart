import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/giftcard_service.dart';
import '../../widgets/brand_image.dart';
import 'transaction_pending_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);

class SellGiftcardConfirmScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;
  final String country;
  final String cardType;
  final double amountUsd;
  final double rateNgn;
  final List<File> images;

  const SellGiftcardConfirmScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
    required this.country,
    required this.cardType,
    required this.amountUsd,
    required this.rateNgn,
    required this.images,
  });

  @override
  State<SellGiftcardConfirmScreen> createState() =>
      _SellGiftcardConfirmScreenState();
}

class _SellGiftcardConfirmScreenState extends State<SellGiftcardConfirmScreen> {
  bool _loading = false;
  String? _error;

  double get _naira => widget.amountUsd * widget.rateNgn;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final ref = await GiftCardService.submitSell(
        brand: widget.brandName,
        brandAsset: widget.brandAsset,
        country: widget.country,
        cardType: widget.cardType,
        amountUsd: widget.amountUsd,
        images: widget.images,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionPendingScreen(reference: ref),
        ),
        (route) => route.isFirst,
      );
    } on GiftCardException catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.message; });
    }
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
          onPressed: _loading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Sell Gift Card',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Column(
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
                      const SizedBox(height: 20),

                      Center(
                        child: Text(
                          '\$${widget.amountUsd.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _kDark),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Column(
                          children: [
                            _Row(
                              label: 'Value in Naira',
                              value: '₦${_naira.toStringAsFixed(0)}',
                            ),
                            const _Divider(),
                            _Row(
                              label: 'Country',
                              value: widget.country,
                            ),
                            const _Divider(),
                            _Row(
                              label: 'Card Type',
                              value: widget.cardType,
                            ),
                            const _Divider(),
                            const _Row(
                              label: 'Transaction Fee',
                              value: '₦0.00',
                            ),
                            const _Divider(),
                            const _Row(
                              label: 'Description',
                              value: 'Giftcard sale',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Your Uploads',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _kDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.images.length} photo${widget.images.length == 1 ? '' : 's'} attached',
                        style: const TextStyle(fontSize: 11, color: _kGrey),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: widget.images
                            .map(
                              (f) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(f,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover),
                              ),
                            )
                            .toList(),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFFB71C1C))),
                        ),
                      ],

                      const SizedBox(height: 24),
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
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      disabledBackgroundColor: const Color(0xFFBFD7FC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sell',
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

          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: _kBlue),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: _kGrey)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kDark)),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFE5E7EB));
}

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
