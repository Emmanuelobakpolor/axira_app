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

String _fmtUsd(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _fmtNgn(double v) {
  final s = v.toStringAsFixed(0);
  return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

class SellGiftcardFormScreen extends StatefulWidget {
  final String brandName;
  final String brandAsset;

  /// Every active rate for this brand, across countries, card types and
  /// value bands.
  final List<GiftSellRate> rates;

  const SellGiftcardFormScreen({
    super.key,
    required this.brandName,
    required this.brandAsset,
    required this.rates,
  });

  @override
  State<SellGiftcardFormScreen> createState() => _SellGiftcardFormScreenState();
}

class _SellGiftcardFormScreenState extends State<SellGiftcardFormScreen> {
  String? _country;
  String _cardType = '';
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Skip a pick when there's only one option.
    final countries = _countries;
    if (countries.length == 1) _selectCountry(countries.first.code);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  List<({String code, String name, String flag})> get _countries {
    final seen = <String>{};
    return [
      for (final r in widget.rates)
        if (seen.add(r.country))
          (code: r.country, name: r.countryName, flag: r.flag),
    ];
  }

  List<({String value, String label})> get _cardTypes {
    final seen = <String>{};
    return [
      for (final r in widget.rates)
        if (r.country == _country && seen.add(r.cardType))
          (value: r.cardType, label: r.cardTypeLabel),
    ];
  }

  /// Value bands for the chosen country + card type, lowest first.
  List<GiftSellRate> get _bands => widget.rates
      .where((r) => r.country == _country && r.cardType == _cardType)
      .toList()
    ..sort((a, b) => a.minUsd.compareTo(b.minUsd));

  double? get _amount => double.tryParse(_amountController.text);

  GiftSellRate? get _matchedRate {
    final v = _amount;
    if (v == null) return null;
    for (final r in _bands.reversed) {
      if (r.covers(v)) return r;
    }
    return null;
  }

  bool get _canProceed => _matchedRate != null;

  void _selectCountry(String code) {
    _country = code;
    final types = _cardTypes;
    _cardType = types.length == 1 ? types.first.value : '';
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
        onSelect: (code) {
          setState(() => _selectCountry(code));
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCardTypeSheet() {
    if (_country == null) return;
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

  /// Rate line under the amount field: the matched rate, or the accepted
  /// value range when the amount doesn't fit any band.
  Widget _buildRateInfo() {
    final bands = _bands;
    if (bands.isEmpty) return const SizedBox.shrink();

    final matched = _matchedRate;
    final String text;
    final Color color;
    if (matched != null) {
      text = 'Rate: ₦${_fmtNgn(matched.rateNgn)} per \$1';
      color = const Color(0xFF047857);
    } else {
      final ranges = bands
          .map((b) => '\$${_fmtUsd(b.minUsd)}–\$${_fmtUsd(b.maxUsd)}')
          .join(', ');
      text = _amount == null
          ? 'Accepted card values: $ranges'
          : "We don't buy this card at this value. Accepted: $ranges";
      color = _amount == null ? _kGrey : const Color(0xFFB91C1C);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = _countries.where((c) => c.code == _country).firstOrNull;
    final cardType = _cardTypes.where((t) => t.value == _cardType).firstOrNull;
    final matched = _matchedRate;
    final naira = matched == null ? 0.0 : (_amount ?? 0) * matched.rateNgn;

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
                        if (country != null) ...[
                          Text(country.flag,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            country?.name ?? 'Select country',
                            style: TextStyle(
                                fontSize: 14,
                                color: country == null ? _kGrey : _kDark),
                          ),
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
                            cardType?.label ??
                                (_country == null
                                    ? 'Select a country first'
                                    : 'Select card type'),
                            style: TextStyle(
                                fontSize: 14,
                                color: cardType == null ? _kGrey : _kDark),
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
                        'You get: ₦${_fmtNgn(naira)}',
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
                      enabled: _cardType.isNotEmpty,
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
                  _buildRateInfo(),
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
                              rate: matched!,
                              amountUsd: _amount!,
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 16),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _CountrySheet extends StatelessWidget {
  final List<({String code, String name, String flag})> countries;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _CountrySheet(
      {required this.countries,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select Country',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
          ),
          ...countries.map((c) => InkWell(
                onTap: () => onSelect(c.code),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(c.name,
                            style:
                                const TextStyle(fontSize: 14, color: _kDark)),
                      ),
                      if (c.code == selected)
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

class _CardTypeSheet extends StatelessWidget {
  final List<({String value, String label})> cardTypes;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CardTypeSheet(
      {required this.cardTypes,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select Card Type',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
          ),
          ...cardTypes.map((t) => InkWell(
                onTap: () => onSelect(t.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(t.label,
                              style: const TextStyle(
                                  fontSize: 14, color: _kDark))),
                      if (t.value == selected)
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
