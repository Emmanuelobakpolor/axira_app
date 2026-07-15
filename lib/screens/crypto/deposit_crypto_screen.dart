import 'package:flutter/material.dart';

import '../../services/crypto_service.dart';
import '../../widgets/coin_logo.dart';
import 'deposit_address_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kDisabled = Color(0xFFBFD7FC);

// ─── Main Screen ──────────────────────────────────────────────────────────────

class DepositCryptoScreen extends StatefulWidget {
  const DepositCryptoScreen({super.key});

  @override
  State<DepositCryptoScreen> createState() => _DepositCryptoScreenState();
}

class _DepositCryptoScreenState extends State<DepositCryptoScreen> {
  bool _isCrypto = true;
  bool _loading = true;
  String _loadError = '';
  List<CoinInfo> _coins = [];

  CoinInfo? _token;
  String _network = '';

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final data = await CryptoService.getPrices();
      if (!mounted) return;
      setState(() {
        _coins = data.coins;
        _loading = false;
      });
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  bool get _needsNetwork =>
      _token != null && kCryptoMultiChainNetworks.containsKey(_token!.symbol);

  bool get _canContinue =>
      _token != null && (!_needsNetwork || _network.isNotEmpty);

  void _openTokenSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        builder: (_, ctrl) => _TokenPickerSheet(
          coins: _coins,
          selected: _token,
          scrollCtrl: ctrl,
          onSelect: (tok) {
            setState(() {
              _token = tok;
              _network = '';
            });
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _openChainSheet() {
    if (_token == null) return;
    final chains = kCryptoMultiChainNetworks[_token!.symbol] ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, ctrl) => _ChainPickerSheet(
          chains: chains,
          selected: _network,
          scrollCtrl: ctrl,
          onSelect: (c) {
            setState(() => _network = c);
            Navigator.pop(context);
          },
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _onContinue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DepositAddressScreen(
          coin: _token!,
          network: _network,
        ),
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
        title: const Text(
          'Deposit Crypto',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: _kGrey, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCoins,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Crypto / Fiat Toggle ────────────────────────────────
                _CryptoFiatToggle(
                  isCrypto: _isCrypto,
                  onCrypto: () => setState(() => _isCrypto = true),
                  onFiat: () => setState(() => _isCrypto = false),
                ),
                const SizedBox(height: 24),

                // ── Select Token ────────────────────────────────────────
                GestureDetector(
                  onTap: _openTokenSheet,
                  child: _DropdownRow(
                    child: _token == null
                        ? const Text('Select Token',
                            style: TextStyle(fontSize: 14, color: _kGrey))
                        : Row(
                            children: [
                              CoinLogo(
                                logoUrl: _token!.logoUrl,
                                letter: _token!.letter,
                                letterColor: _token!.color,
                                backgroundColor:
                                    _token!.color.withValues(alpha: 0.15),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(_token!.symbol,
                                  style: const TextStyle(
                                      fontSize: 14, color: _kDark)),
                            ],
                          ),
                  ),
                ),

                // ── Select Network (only for multi-chain coins) ─────────
                if (_needsNetwork) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _openChainSheet,
                    child: _DropdownRow(
                      child: _network.isEmpty
                          ? const Text('Select Network',
                              style: TextStyle(fontSize: 14, color: _kGrey))
                          : Text(_network,
                              style: const TextStyle(
                                  fontSize: 14, color: _kDark)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Buttons ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canContinue ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    disabledBackgroundColor: _kBlue.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kDisabled,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancel Transaction',
                    style: TextStyle(
                        color: _kBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Crypto / Fiat Toggle ─────────────────────────────────────────────────────

class _CryptoFiatToggle extends StatelessWidget {
  final bool isCrypto;
  final VoidCallback onCrypto;
  final VoidCallback onFiat;
  const _CryptoFiatToggle(
      {required this.isCrypto,
      required this.onCrypto,
      required this.onFiat});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onCrypto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCrypto ? _kBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Crypto',
                  style: TextStyle(
                    color: isCrypto ? Colors.white : _kGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onFiat,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: !isCrypto ? _kBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Fiat',
                  style: TextStyle(
                    color: !isCrypto ? Colors.white : _kGrey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dropdown Row ─────────────────────────────────────────────────────────────

class _DropdownRow extends StatelessWidget {
  final Widget child;
  const _DropdownRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          const Icon(Icons.keyboard_arrow_down, color: _kGrey),
        ],
      ),
    );
  }
}

// ─── Token Picker Sheet ───────────────────────────────────────────────────────

class _TokenPickerSheet extends StatefulWidget {
  final List<CoinInfo> coins;
  final CoinInfo? selected;
  final ScrollController scrollCtrl;
  final ValueChanged<CoinInfo> onSelect;
  final VoidCallback onClose;
  const _TokenPickerSheet({
    required this.coins,
    required this.selected,
    required this.scrollCtrl,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<_TokenPickerSheet> createState() => _TokenPickerSheetState();
}

class _TokenPickerSheetState extends State<_TokenPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.coins
        : widget.coins
            .where((t) =>
                t.symbol.toLowerCase().contains(q) ||
                t.name.toLowerCase().contains(q))
            .toList();

    return Column(
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Token',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _kDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Kindly select the token you'll love to receive",
                      style:
                          const TextStyle(fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Search ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14, color: _kDark),
            decoration: InputDecoration(
              hintText: 'Search token name',
              hintStyle:
                  const TextStyle(color: Color(0xFFB0B7C3), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFFB0B7C3), size: 18),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),

        // ── Token list ────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No coins match your search.',
                      style: TextStyle(fontSize: 13, color: _kGrey)),
                )
              : ListView.separated(
                  controller: widget.scrollCtrl,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  itemBuilder: (_, i) {
                    final tok = filtered[i];
                    final isSelected = widget.selected?.symbol == tok.symbol;
                    return InkWell(
                      onTap: () => widget.onSelect(tok),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CoinLogo(
                              logoUrl: tok.logoUrl,
                              letter: tok.letter,
                              letterColor: tok.color,
                              backgroundColor:
                                  tok.color.withValues(alpha: 0.15),
                              size: 36,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(tok.symbol,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _kDark)),
                                  Text(tok.name,
                                      style: const TextStyle(
                                          fontSize: 12, color: _kGrey)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check,
                                  color: _kBlue, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Chain Picker Sheet ───────────────────────────────────────────────────────

class _ChainPickerSheet extends StatelessWidget {
  final List<String> chains;
  final String selected;
  final ScrollController scrollCtrl;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;
  const _ChainPickerSheet({
    required this.chains,
    required this.selected,
    required this.scrollCtrl,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Network',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _kDark),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Choose the network to deposit on',
                      style: TextStyle(fontSize: 12, color: _kGrey),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      size: 16, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),

        // ── Chain cards ───────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: chains.length,
            itemBuilder: (_, i) {
              final ch = chains[i];
              final isSelected = selected == ch;
              return GestureDetector(
                onTap: () => onSelect(ch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFEBF2FF)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _kBlue : _kBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    ch,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _kBlue : _kDark),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
