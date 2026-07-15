import 'package:flutter/material.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';
import 'buy_crypto_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF2F4F8);

class MyCryptoScreen extends StatefulWidget {
  const MyCryptoScreen({super.key});

  @override
  State<MyCryptoScreen> createState() => _MyCryptoScreenState();
}

class _MyCryptoScreenState extends State<MyCryptoScreen> {
  int _tab = 0;

  bool _loading = true;
  String _error = '';
  List<CryptoWalletBalance> _wallets = [];
  List<CryptoOrderHistory> _orders = [];
  Map<String, CoinInfo> _coinMeta = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final results = await Future.wait([
        CryptoService.getWallets(),
        CryptoService.getOrders(),
        CryptoService.getPrices(),
      ]);
      if (!mounted) return;
      final wallets = results[0] as List<CryptoWalletBalance>;
      final orders = results[1] as List<CryptoOrderHistory>;
      final prices = results[2] as CryptoPricesData;
      setState(() {
        _wallets = wallets.where((w) => w.total > 0).toList();
        _orders = orders;
        _coinMeta = {for (final c in prices.coins) c.symbol: c};
        _loading = false;
      });
    } on AuthException catch (_) {
      if (!mounted) return;
      await redirectToSignIn(context);
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _fmtAmount(double v) {
    if (v == 0) return '0';
    if (v >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(8);
  }

  String _fmtNgn(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return '₦$intPart.${parts[1]}';
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Crypto',
            style: TextStyle(
                color: _kDark, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(child: _tabButton('Holdings', 0)),
                const SizedBox(width: 10),
                Expanded(child: _tabButton('History', 1)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kBlue : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : _kGrey,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }
    if (_error.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 40),
          const SizedBox(height: 12),
          Text(_error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kGrey, fontSize: 14)),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    return _tab == 0 ? _buildHoldings() : _buildHistory();
  }

  Widget _buildHoldings() {
    if (_wallets.isEmpty) {
      return _emptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: "You don't own any crypto yet.",
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _wallets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final w = _wallets[i];
        final meta = _coinMeta[w.coin];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              CoinLogo(
                logoUrl: meta?.logoUrl,
                letter: meta?.letter ?? w.coin.substring(0, 1),
                letterColor: meta?.color ?? _kGrey,
                backgroundColor:
                    (meta?.color ?? _kGrey).withValues(alpha: 0.15),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta?.name ?? w.coin,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _kDark)),
                    const SizedBox(height: 2),
                    Text(w.coin,
                        style: const TextStyle(fontSize: 12, color: _kGrey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtAmount(w.total),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark)),
                  if (w.reserved > 0) ...[
                    const SizedBox(height: 2),
                    Text('${_fmtAmount(w.reserved)} reserved',
                        style:
                            const TextStyle(fontSize: 11, color: _kGrey)),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistory() {
    if (_orders.isEmpty) {
      return _emptyState(
        icon: Icons.history,
        message: 'No crypto orders yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _OrderCard(order: _orders[i], fmtNgn: _fmtNgn, fmtDate: _fmtDate),
    );
  }

  Widget _emptyState({required IconData icon, required String message}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(icon, color: _kGrey, size: 44),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kGrey, fontSize: 14)),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BuyCryptoScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Buy Crypto',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CryptoOrderHistory order;
  final String Function(double) fmtNgn;
  final String Function(String) fmtDate;

  const _OrderCard({
    required this.order,
    required this.fmtNgn,
    required this.fmtDate,
  });

  (Color, Color, String) get _statusStyle {
    switch (order.status) {
      case 'completed':
        return (const Color(0xFF16A34A), const Color(0xFFE7F8EE), 'Completed');
      case 'failed':
        return (const Color(0xFFDC2626), const Color(0xFFFDECEC), 'Failed');
      case 'cancelled':
      case 'expired':
        return (_kGrey, const Color(0xFFF3F4F6), 'Cancelled');
      default:
        return (const Color(0xFFCA8A04), const Color(0xFFFEF6E7), 'Processing');
    }
  }

  String get _title {
    switch (order.orderType) {
      case 'buy':
        return 'Bought ${order.coin}';
      case 'sell':
        return 'Sold ${order.coin}';
      case 'swap':
        return '${order.coin} → ${order.toCoin}';
      default:
        return order.orderType;
    }
  }

  IconData get _icon {
    switch (order.orderType) {
      case 'buy':
        return Icons.arrow_downward_rounded;
      case 'sell':
        return Icons.arrow_upward_rounded;
      case 'swap':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = _statusStyle;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_icon, color: _kBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kDark)),
                const SizedBox(height: 2),
                Text(fmtDate(order.createdAt),
                    style: const TextStyle(fontSize: 12, color: _kGrey)),
                const SizedBox(height: 2),
                Text(order.reference,
                    style: const TextStyle(fontSize: 11, color: _kGrey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtNgn(order.totalNgn),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kDark)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
