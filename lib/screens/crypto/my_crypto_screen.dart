import 'package:flutter/material.dart';

import '../../services/auth_service.dart' show AuthException;
import '../../services/crypto_service.dart';
import '../../utils/features.dart';
import '../../utils/fiat_format.dart';
import '../../utils/session_guard.dart';
import '../../widgets/coin_logo.dart';
import 'buy_crypto_screen.dart';
import 'deposit_crypto_screen.dart';
import 'transfer_crypto_screen.dart';

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
  List<CryptoDepositRecord> _deposits = [];
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
        // Best-effort — don't hide holdings/orders if deposits fail to load.
        CryptoService.getDeposits()
            .catchError((_) => <CryptoDepositRecord>[]),
      ]);
      if (!mounted) return;
      final wallets = results[0] as List<CryptoWalletBalance>;
      final orders = results[1] as List<CryptoOrderHistory>;
      final prices = results[2] as CryptoPricesData;
      final deposits = results[3] as List<CryptoDepositRecord>;
      setState(() {
        _wallets = wallets.where((w) => w.total > 0).toList();
        _orders = orders;
        _deposits = deposits;
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
        title: const Text(
          'My Crypto',
          style: TextStyle(
            color: _kDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
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
          Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kGrey, fontSize: 14),
          ),
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
      itemCount: _wallets.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == 0) return _buildPortfolioTotal();
        final w = _wallets[index - 1];
        final meta = _coinMeta[w.coin];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openHoldingActions(w, meta),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  CoinLogo(
                    logoUrl: meta?.logoUrl,
                    letter: meta?.letter ?? w.coin.substring(0, 1),
                    letterColor: meta?.color ?? _kGrey,
                    backgroundColor: (meta?.color ?? _kGrey).withValues(
                      alpha: 0.15,
                    ),
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta?.name ?? w.coin,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          w.coin,
                          style: const TextStyle(fontSize: 12, color: _kGrey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtAmount(w.total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                        ),
                      ),
                      if (meta != null && meta.priceUsd > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          formatUsd(w.total * meta.priceUsd),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kDark,
                          ),
                        ),
                      ],
                      if (meta != null && meta.priceNgn > 0) ...[
                        const SizedBox(height: 1),
                        Text(
                          formatNgn(w.total * meta.priceNgn),
                          style: const TextStyle(fontSize: 11, color: _kGrey),
                        ),
                      ],
                      if (w.reserved > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtAmount(w.reserved)} reserved',
                          style: const TextStyle(fontSize: 11, color: _kGrey),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: _kGrey, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioTotal() {
    double usd = 0, ngn = 0;
    for (final w in _wallets) {
      final meta = _coinMeta[w.coin];
      if (meta == null) continue;
      usd += w.total * meta.priceUsd;
      ngn += w.total * meta.priceNgn;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total crypto value',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            formatUsd(usd),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '≈ ${formatNgn(ngn)}',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _openHoldingActions(CryptoWalletBalance w, CoinInfo? meta) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta?.name ?? w.coin,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Available: ${_fmtAmount(w.available)} ${w.coin}',
                style: const TextStyle(fontSize: 13, color: _kGrey),
              ),
              if (fiatValueLine(w.available, meta).isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  fiatValueLine(w.available, meta),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _HoldingAction(
                icon: Icons.sell_outlined,
                title: 'Sell ${w.coin} for Naira',
                subtitle: 'Get paid into your NGN wallet',
                enabled: w.available > 0,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pushAndReload(
                    BuyCryptoScreen(initialSell: true, initialCoin: w.coin),
                  );
                },
              ),
              const SizedBox(height: 10),
              _HoldingAction(
                icon: Icons.north_east_rounded,
                title: 'Send ${w.coin} to a wallet',
                subtitle: 'Transfer to an external address',
                enabled: w.available > 0,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pushAndReload(TransferCryptoScreen(initialCoin: w.coin));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pushAndReload(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  Widget _buildHistory() {
    // Orders and deposits come from different endpoints — merge them
    // newest first. Pending deposits may lack a date; keep them on top.
    DateTime when(String iso) =>
        DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(1 << 52);
    final entries = <(DateTime, Widget)>[
      for (final o in _orders)
        (
          when(o.createdAt),
          _OrderCard(order: o, fmtNgn: _fmtNgn, fmtDate: _fmtDate),
        ),
      for (final d in _deposits)
        (
          when(d.createdAt),
          _DepositCard(deposit: d, fmtAmount: _fmtAmount, fmtDate: _fmtDate),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    if (entries.isEmpty) {
      return _emptyState(icon: Icons.history, message: 'No crypto activity yet.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => entries[i].$2,
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
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kGrey, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              // With buying off, the way in is depositing crypto to sell.
              MaterialPageRoute(
                builder: (_) => kBuyCryptoEnabled
                    ? const BuyCryptoScreen()
                    : const DepositCryptoScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              kBuyCryptoEnabled ? 'Buy Crypto' : 'Receive Crypto',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DepositCard extends StatelessWidget {
  final CryptoDepositRecord deposit;
  final String Function(double) fmtAmount;
  final String Function(String) fmtDate;

  const _DepositCard({
    required this.deposit,
    required this.fmtAmount,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final pending = deposit.status == 'pending';
    final (fg, bg, label) = pending
        ? (const Color(0xFFCA8A04), const Color(0xFFFEF6E7), 'Confirming')
        : (const Color(0xFF16A34A), const Color(0xFFE7F8EE), 'Completed');
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
            child: const Icon(Icons.call_received_rounded, color: _kBlue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Received ${deposit.coin}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
                if (deposit.createdAt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fmtDate(deposit.createdAt),
                    style: const TextStyle(fontSize: 12, color: _kGrey),
                  ),
                ],
                if (deposit.txId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    deposit.txId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _kGrey),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${fmtAmount(deposit.amount)} ${deposit.coin}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
        return (_kGrey, const Color(0xFFF3F4F6), 'Cancelled');
      case 'expired':
        return (_kGrey, const Color(0xFFF3F4F6), 'Expired');
      case 'waiting_deposit':
        return (
          const Color(0xFFCA8A04),
          const Color(0xFFFEF6E7),
          'Awaiting deposit',
        );
      case 'pending_payment':
        return (
          const Color(0xFFCA8A04),
          const Color(0xFFFEF6E7),
          'Awaiting payment',
        );
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
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fmtDate(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: _kGrey),
                ),
                const SizedBox(height: 2),
                Text(
                  order.reference,
                  style: const TextStyle(fontSize: 11, color: _kGrey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtNgn(order.totalNgn),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable option in a holding's action sheet.
class _HoldingAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _HoldingAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: const Color(0xFFEBF2FF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _kBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _kDark)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _kBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
