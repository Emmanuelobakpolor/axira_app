import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart' show kSessionExpiredError;
import '../../services/giftcard_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/brand_image.dart';
import 'giftcard_pin_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kFieldBg = Color(0xFFF5F6FA);
const _kBorder = Color(0xFFE5E7EB);

class BuyGiftcardFormScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;

  const BuyGiftcardFormScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
  });

  @override
  State<BuyGiftcardFormScreen> createState() => _BuyGiftcardFormScreenState();
}

class _BuyGiftcardFormScreenState extends State<BuyGiftcardFormScreen> {
  String _country = 'United State of America';
  String _countryFlag = 'assets/USA.png';
  String _countryCode = 'US';

  GiftProduct? _selectedProduct;
  List<GiftProduct> _products = [];
  double _rate = 1700;
  bool _loadingProducts = false;
  String? _productsError;

  final _amountController = TextEditingController();

  static const _countries = [
    ('United State of America', 'assets/USA.png', 'US'),
    ('Canada', 'assets/CANADA.png', 'CA'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingProducts = true;
      _productsError = null;
      _products = [];
      _selectedProduct = null;
    });
    try {
      final results = await Future.wait([
        GiftCardService.getRate(),
        GiftCardService.getProducts(widget.brandName, _countryCode),
      ]);
      if (!mounted) return;
      setState(() {
        _rate = results[0] as double;
        _products = results[1] as List<GiftProduct>;
        _loadingProducts = false;
      });
    } on GiftCardException catch (e) {
      if (!mounted) return;
      if (e.message == kSessionExpiredError) {
        await redirectToSignIn(context);
        return;
      }
      setState(() {
        _loadingProducts = false;
        _productsError = e.message;
      });
    }
  }

  double get _nairaAmount {
    if (_selectedProduct != null && !_selectedProduct!.openRange) {
      return _selectedProduct!.unitPriceNgn;
    }
    final v = double.tryParse(_amountController.text) ?? 0;
    return v * _rate;
  }

  bool get _canProceed {
    if (_selectedProduct == null) return false;
    if (_selectedProduct!.openRange) {
      final v = double.tryParse(_amountController.text);
      if (v == null) return false;
      if (_selectedProduct!.minUsd != null && v < _selectedProduct!.minUsd!) return false;
      if (_selectedProduct!.maxUsd != null && v > _selectedProduct!.maxUsd!) return false;
    }
    return true;
  }

  double get _effectiveUsdAmount {
    if (_selectedProduct != null && !_selectedProduct!.openRange) {
      return _selectedProduct!.unitPriceUsd;
    }
    return double.tryParse(_amountController.text) ?? 0;
  }

  void _showCountrySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountrySheet(
        countries: _countries,
        selected: _country,
        onSelect: (name, flag, code) {
          if (code != _countryCode) {
            setState(() {
              _country = name;
              _countryFlag = flag;
              _countryCode = code;
              _selectedProduct = null;
              _amountController.clear();
            });
            Navigator.pop(context);
            _loadAll();
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showPackageSheet() {
    if (_products.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PackageSheet(
        products: _products,
        selected: _selectedProduct,
        onSelect: (p) {
          setState(() {
            _selectedProduct = p;
            if (!p.openRange) {
              _amountController.text = p.unitPriceUsd.toStringAsFixed(0);
            } else {
              _amountController.clear();
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ngnAmount = _nairaAmount;
    final showCustomAmount = _selectedProduct?.openRange == true;

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
          'Buy Gift Card',
          style: TextStyle(color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
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

                  const _FieldLabel('Select Country'),
                  const SizedBox(height: 8),
                  _DropdownRow(
                    onTap: _showCountrySheet,
                    child: Row(
                      children: [
                        Image.asset(_countryFlag, width: 24, height: 24, fit: BoxFit.cover),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_country,
                              style: const TextStyle(fontSize: 14, color: _kDark)),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: _kGrey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('Select Package'),
                  const SizedBox(height: 8),
                  _loadingProducts
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
                        ))
                      : _productsError != null
                          ? _ErrorChip(
                              message: _productsError!,
                              onRetry: _loadAll,
                            )
                          : _DropdownRow(
                              onTap: _products.isEmpty ? () {} : _showPackageSheet,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedProduct == null
                                          ? (_products.isEmpty
                                              ? 'No packages available'
                                              : 'Select package')
                                          : _selectedProduct!.displayLabel,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedProduct == null ? _kGrey : _kDark),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, color: _kGrey),
                                ],
                              ),
                            ),
                  const SizedBox(height: 16),

                  if (_selectedProduct != null) ...[
                    const SizedBox(height: 16),
                    _ProductInfoCard(product: _selectedProduct!),
                  ],
                  const SizedBox(height: 4),
                  if (showCustomAmount) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _FieldLabel('Custom Amount (USD)'),
                        Text(
                          'In Naira: ₦${ngnAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, color: _kGrey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _kFieldBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 14, color: _kDark),
                        decoration: InputDecoration(
                          hintText: _selectedProduct?.minUsd != null
                              ? '\$${_selectedProduct!.minUsd!.toStringAsFixed(0)} – \$${_selectedProduct!.maxUsd!.toStringAsFixed(0)}'
                              : 'Enter amount',
                          hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                              color: _kDark, fontSize: 14, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ] else if (_selectedProduct != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _FieldLabel('You pay'),
                        Text(
                          '≈ ₦${ngnAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _kBlue),
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
                onPressed: _canProceed
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GiftcardPinScreen(
                              brandName: widget.brandName,
                              brandAsset: widget.brandAsset,
                              productId: _selectedProduct!.productId,
                              unitPriceUsd: _effectiveUsdAmount,
                              amountNgn: _nairaAmount,
                              countryCode: _countryCode,
                            ),
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: const Color(0xFFBFD7FC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Brand card ──────────────────────────────────────────────────────────────

class _BrandCard extends StatelessWidget {
  final String name;
  final String asset;
  final VoidCallback onClose;

  const _BrandCard({required this.name, required this.asset, required this.onClose});

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
                      fontSize: 14, fontWeight: FontWeight.w600, color: _kDark)),
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
                child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _DropdownRow extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _DropdownRow({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kFieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: _kDark));
  }
}

class _ErrorChip extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorChip({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 13, color: Color(0xFFB71C1C))),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: _kBlue, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Country bottom sheet ─────────────────────────────────────────────────────

class _CountrySheet extends StatefulWidget {
  final List<(String, String, String)> countries;
  final String selected;
  final void Function(String name, String flag, String code) onSelect;

  const _CountrySheet(
      {required this.countries, required this.selected, required this.onSelect});

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.countries
        .where((c) => c.$1.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select Country',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search Country',
                hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFB0B7C3), size: 18),
                filled: true,
                fillColor: _kFieldBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ...filtered.map((c) => InkWell(
                onTap: () => widget.onSelect(c.$1, c.$2, c.$3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Image.asset(c.$2, width: 28, height: 28, fit: BoxFit.cover),
                      const SizedBox(width: 12),
                      Text(c.$1,
                          style: const TextStyle(fontSize: 14, color: _kDark)),
                      if (c.$1 == widget.selected) ...[
                        const Spacer(),
                        const Icon(Icons.check, color: _kBlue, size: 18),
                      ],
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Product info card ────────────────────────────────────────────────────────

class _ProductInfoCard extends StatelessWidget {
  final GiftProduct product;
  const _ProductInfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercentage > 0;
    final hasFee = product.senderFee > 0 || product.senderFeePercentage > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (product.category.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.category,
                    style: const TextStyle(
                        fontSize: 11, color: _kBlue, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (hasDiscount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${product.discountPercentage.toStringAsFixed(0)}% OFF',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          if (hasFee) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: _kGrey),
                const SizedBox(width: 4),
                Text(
                  product.senderFee > 0
                      ? 'Service fee: \$${product.senderFee.toStringAsFixed(2)}'
                      : 'Service fee: ${product.senderFeePercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: _kGrey),
                ),
              ],
            ),
          ],
          if (product.redeemInstruction.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'How to redeem',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _kDark),
            ),
            const SizedBox(height: 4),
            Text(
              product.redeemInstruction,
              style: const TextStyle(fontSize: 12, color: _kGrey, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Package bottom sheet ─────────────────────────────────────────────────────

class _PackageSheet extends StatefulWidget {
  final List<GiftProduct> products;
  final GiftProduct? selected;
  final ValueChanged<GiftProduct> onSelect;

  const _PackageSheet(
      {required this.products, required this.selected, required this.onSelect});

  @override
  State<_PackageSheet> createState() => _PackageSheetState();
}

class _PackageSheetState extends State<_PackageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((p) => p.displayLabel.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select Package',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _kDark)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                filled: true,
                fillColor: _kFieldBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView(
              shrinkWrap: true,
              children: filtered.map((p) => InkWell(
                    onTap: () => widget.onSelect(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.displayLabel,
                                    style: const TextStyle(fontSize: 14, color: _kDark)),
                                if (!p.openRange)
                                  Text('≈ ₦${p.unitPriceNgn.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12, color: _kGrey)),
                              ],
                            ),
                          ),
                          if (p.productId == widget.selected?.productId &&
                              p.unitPriceUsd == widget.selected?.unitPriceUsd)
                            const Icon(Icons.check, color: _kBlue, size: 18),
                        ],
                      ),
                    ),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
