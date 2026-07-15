import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/giftcard_service.dart';
import '../../widgets/brand_image.dart';
import 'sell_giftcard_upload_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kFieldBg = Color(0xFFF5F6FA);
const _kBorder = Color(0xFFE5E7EB);

class SellGiftcardFormScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;

  const SellGiftcardFormScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
  });

  @override
  State<SellGiftcardFormScreen> createState() => _SellGiftcardFormScreenState();
}

class _SellGiftcardFormScreenState extends State<SellGiftcardFormScreen> {
  String _country = 'United State of America';
  String _countryFlag = 'assets/USA.png';
  String _cardType = '';
  double _rate = 1700;
  final _amountController = TextEditingController();

  static const _countries = [
    ('United State of America', 'assets/USA.png'),
    ('Canada', 'assets/CANADA.png'),
  ];

  static const _cardTypes = ['Physical Card', 'E-Code', 'Digital Card'];

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    try {
      final r = await GiftCardService.getRate();
      if (mounted) setState(() => _rate = r);
    } catch (_) {}
  }

  double get _nairaAmount {
    final v = double.tryParse(_amountController.text) ?? 0;
    return v * _rate;
  }

  bool get _canProceed {
    final v = double.tryParse(_amountController.text);
    return _cardType.isNotEmpty && v != null && v >= 1;
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
        onSelect: (name, flag) {
          setState(() {
            _country = name;
            _countryFlag = flag;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCardTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CardTypeSheet(
        cardTypes: _cardTypes,
        selected: _cardType,
        onSelect: (type) {
          setState(() => _cardType = type);
          Navigator.pop(context);
        },
      ),
    );
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
        title: const Text('Sell Gift Card',
            style: TextStyle(
                color: _kDark, fontSize: 18, fontWeight: FontWeight.bold)),
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
                        Image.asset(_countryFlag,
                            width: 24, height: 24, fit: BoxFit.cover),
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

                  const _FieldLabel('Card Type'),
                  const SizedBox(height: 8),
                  _DropdownRow(
                    onTap: _showCardTypeSheet,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _cardType.isEmpty ? 'Select card type' : _cardType,
                            style: TextStyle(
                                fontSize: 14,
                                color: _cardType.isEmpty ? _kGrey : _kDark),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: _kGrey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _FieldLabel('Card Value (\$)'),
                      Text(
                        'In Naira: ₦${_nairaAmount.toStringAsFixed(0)}',
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
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'))
                      ],
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 14, color: _kDark),
                      decoration: const InputDecoration(
                        hintText: 'Enter card value',
                        hintStyle:
                            TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(
                            color: _kDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
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
                            builder: (_) => SellGiftcardUploadScreen(
                              brandName: widget.brandName,
                              brandAsset: widget.brandAsset,
                              country: _country,
                              cardType: _cardType,
                              amountUsd: double.parse(_amountController.text),
                              rateNgn: _rate,
                            ),
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  disabledBackgroundColor: const Color(0xFFBFD7FC),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Next',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _DropdownRow extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _DropdownRow({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

class _CountrySheet extends StatefulWidget {
  final List<(String, String)> countries;
  final String selected;
  final void Function(String name, String flag) onSelect;

  const _CountrySheet(
      {required this.countries,
      required this.selected,
      required this.onSelect});

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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search Country',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFFB0B7C3), size: 18),
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
                onTap: () => widget.onSelect(c.$1, c.$2),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Image.asset(c.$2,
                          width: 28, height: 28, fit: BoxFit.cover),
                      const SizedBox(width: 12),
                      Text(c.$1,
                          style:
                              const TextStyle(fontSize: 14, color: _kDark)),
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

class _CardTypeSheet extends StatefulWidget {
  final List<String> cardTypes;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CardTypeSheet(
      {required this.cardTypes,
      required this.selected,
      required this.onSelect});

  @override
  State<_CardTypeSheet> createState() => _CardTypeSheetState();
}

class _CardTypeSheetState extends State<_CardTypeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.cardTypes
        .where((t) => t.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            child: Text('Select Card Type',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle:
                    const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
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
          ...filtered.map((type) => InkWell(
                onTap: () => widget.onSelect(type),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(type,
                              style: const TextStyle(
                                  fontSize: 14, color: _kDark))),
                      if (type == widget.selected)
                        const Icon(Icons.check, color: _kBlue, size: 18),
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
