import 'package:flutter/material.dart';
import '../../services/auth_service.dart' show AuthService, kSessionExpiredError;
import '../../services/wallet_service.dart';
import '../auth/sign_in_screen.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);

const _kTabs = ['All', 'Deposits', 'Withdrawals'];
const _kFilters = ['This Week', 'This Month', 'Custom'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _activeTab = 0;
  bool _showFilter = false;
  String _activeFilter = 'This Week';

  List<WalletTransaction> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final txns = await WalletService.getTransactions();
      if (!mounted) return;
      setState(() { _all = txns; _loading = false; });
    } on WalletException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    }
  }

  List<WalletTransaction> get _filtered {
    if (_activeTab == 1) return _all.where((t) => t.txType == 'deposit').toList();
    if (_activeTab == 2) return _all.where((t) => t.txType == 'withdrawal').toList();
    return _all;
  }

  // Group transactions into labelled buckets keyed by display date string
  Map<String, List<WalletTransaction>> _grouped(List<WalletTransaction> txns) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<WalletTransaction>> groups = {};
    for (final t in txns) {
      final d = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = _formatGroupDate(t.createdAt);
      }
      groups.putIfAbsent(label, () => []).add(t);
    }
    return groups;
  }

  static String _formatGroupDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'am' : 'pm';
    return '$h:$m$ampm';
  }

  static String _formatAmount(WalletTransaction t) {
    final sign = t.txType == 'deposit' ? '+' : '-';
    final parts = t.amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},',
    );
    return '$sign₦$intPart.${parts[1]}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return _kBlue;
      case 'pending':   return const Color(0xFFF59E0B);
      case 'failed':    return Colors.red;
      default:          return _kGrey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed': return 'Completed';
      case 'pending':   return 'Pending';
      case 'failed':    return 'Failed';
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { if (_showFilter) setState(() => _showFilter = false); },
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
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
            'Transaction History',
            style: TextStyle(color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                // ── Tabs + filter row ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: List.generate(
                              _kTabs.length,
                              (i) => _TabChip(
                                label: _kTabs[i],
                                active: _activeTab == i,
                                onTap: () => setState(() => _activeTab = i),
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showFilter = !_showFilter),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _kBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _kBorder),
                          ),
                          child: const Icon(Icons.tune_rounded, size: 18, color: _kDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),

                // ── Content ───────────────────────────────────────────────
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? _ErrorView(message: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _load(); })
                          : _buildList(),
                ),
              ],
            ),

            // ── Filter popup ──────────────────────────────────────────────
            if (_showFilter)
              Positioned(
                top: 50,
                right: 12,
                child: _FilterPopup(
                  activeFilter: _activeFilter,
                  onSelect: (f) => setState(() { _activeFilter = f; _showFilter = false; }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 48, color: _kGrey),
            const SizedBox(height: 12),
            Text(
              _activeTab == 0 ? 'No transactions yet' : 'No ${_kTabs[_activeTab].toLowerCase()} yet',
              style: const TextStyle(color: _kGrey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final groups = _grouped(items);
    return RefreshIndicator(
      onRefresh: () async { setState(() => _loading = true); await _load(); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          for (final entry in groups.entries) ...[
            _GroupHeader(entry.key),
            ...entry.value.map((t) => _TxnRow(
              type: t.txType == 'deposit' ? 'Deposit' : 'Withdrawal',
              statusLabel: _statusLabel(t.status),
              statusColor: _statusColor(t.status),
              amount: _formatAmount(t),
              date: '${_formatGroupDate(t.createdAt)} ${_formatTime(t.createdAt)}',
              isPositive: t.txType == 'deposit',
            )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ─── Tab chip ─────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: active ? _kBlue : Colors.transparent, width: 2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? _kBlue : _kGrey,
          ),
        ),
      ),
    );
  }
}

// ─── Group header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: _kGrey, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─── Transaction row ──────────────────────────────────────────────────────────

class _TxnRow extends StatelessWidget {
  final String type;
  final String statusLabel;
  final Color statusColor;
  final String amount;
  final String date;
  final bool isPositive;

  const _TxnRow({
    required this.type,
    required this.statusLabel,
    required this.statusColor,
    required this.amount,
    required this.date,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kDark)),
                const SizedBox(height: 2),
                Text(statusLabel, style: TextStyle(fontSize: 13, color: statusColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? const Color(0xFF16A34A) : _kDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(date, style: const TextStyle(fontSize: 12, color: _kGrey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter popup ─────────────────────────────────────────────────────────────

class _FilterPopup extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onSelect;
  const _FilterPopup({required this.activeFilter, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _kFilters
              .map((f) => _FilterOption(label: f, checked: activeFilter == f, onTap: () => onSelect(f)))
              .toList(),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;
  const _FilterOption({required this.label, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: checked ? _kBlue : const Color(0xFFD1D5DB), width: 1.5),
                color: checked ? _kBlue : Colors.transparent,
              ),
              child: checked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: checked ? _kDark : _kGrey,
                fontWeight: checked ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isSessionExpired = message == kSessionExpiredError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: const TextStyle(color: _kGrey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isSessionExpired
                  ? () async {
                      final nav = Navigator.of(context);
                      await AuthService.clearSession();
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                        (_) => false,
                      );
                    }
                  : onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue, elevation: 0),
              child: Text(isSessionExpired ? 'Sign In' : 'Retry',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
