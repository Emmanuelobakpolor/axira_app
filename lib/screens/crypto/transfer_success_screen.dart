import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/crypto_service.dart';
import '../../utils/fiat_format.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);

class TransferSuccessScreen extends StatefulWidget {
  final WithdrawalResult result;

  const TransferSuccessScreen({super.key, required this.result});

  @override
  State<TransferSuccessScreen> createState() => _TransferSuccessScreenState();
}

class _TransferSuccessScreenState extends State<TransferSuccessScreen> {
  // Poll the backend while Quidax is still settling the transfer.
  static const _kPollInterval = Duration(seconds: 6);
  static const _kMaxPolls = 30; // ~3 minutes

  late WithdrawalResult result = widget.result;
  Timer? _pollTimer;
  int _polls = 0;

  bool get _isProcessing => result.status == 'processing';
  bool get _isRejected => result.status == 'rejected' || result.status == 'failed';

  @override
  void initState() {
    super.initState();
    if (_isProcessing) {
      _pollTimer = Timer.periodic(_kPollInterval, (_) => _refreshStatus());
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (++_polls > _kMaxPolls) {
      _pollTimer?.cancel();
      return;
    }
    try {
      final latest = await CryptoService.getWithdrawal(result.reference);
      if (!mounted) return;
      setState(() => result = latest);
      if (!_isProcessing) _pollTimer?.cancel();
    } catch (_) {
      // Transient network error — try again on the next tick.
    }
  }

  String get _statusLabel {
    switch (result.status) {
      case 'completed': return 'Completed';
      case 'processing': return 'Processing';
      case 'rejected': return 'Rejected (refunded)';
      case 'failed': return 'Failed';
      default: return result.status;
    }
  }

  String get _shortAddr {
    final a = result.address;
    if (a.length <= 14) return a;
    return '${a.substring(0, 9)}.......${a.substring(a.length - 5)}';
  }

  String _coinStr(double v) => '${formatCoinQty(v)} ${result.coin}';

  String get _dateStr {
    final d = DateTime.tryParse(result.createdAt);
    if (d == null) return result.createdAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} - $hh:$mm';
  }

  void _shareReceipt(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.reference));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reference copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  children: [
                    // ── Status icon ───────────────────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isProcessing
                            ? const Color(0xFFFFF3E0)
                            : _isRejected
                                ? const Color(0xFFFDECEA)
                                : const Color(0xFFE8F5E9),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessing
                                ? const Color(0xFFF59E0B)
                                : _isRejected
                                    ? Colors.red
                                    : const Color(0xFF2E7D32),
                          ),
                          child: Icon(
                              _isProcessing
                                  ? Icons.hourglass_top_rounded
                                  : _isRejected
                                      ? Icons.close_rounded
                                      : Icons.verified,
                              color: Colors.white,
                              size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────────────
                    Text(
                      _isProcessing
                          ? 'Transfer Submitted'
                          : _isRejected
                              ? 'Transfer Failed'
                              : 'Transfer Successful!',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _kDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_isProcessing) ...[
                      const Text(
                        "We're broadcasting this to the network. You'll see the final status in your transaction history shortly.",
                        style: TextStyle(fontSize: 13, color: _kGrey, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_isRejected) ...[
                      const Text(
                        'This transfer could not be completed. The amount has been returned to your wallet.',
                        style: TextStyle(fontSize: 13, color: _kGrey, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Recipient gets',
                      style: TextStyle(fontSize: 14, color: _kGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _coinStr(result.receiveAmount),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _kBlue),
                    ),
                    const SizedBox(height: 28),

                    // ── Detail rows ───────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: [
                          _Row(label: 'Sent To:', value: _shortAddr),
                          const _Divider(),
                          _Row(label: 'Token', value: result.coin),
                          const _Divider(),
                          _Row(
                              label: 'Network',
                              value: result.network.isEmpty
                                  ? 'Default'
                                  : result.network),
                          const _Divider(),
                          _Row(label: 'Amount:', value: _coinStr(result.amount)),
                          const _Divider(),
                          _Row(
                              label: 'Network Fee',
                              value: _coinStr(result.networkFee)),
                          const _Divider(),
                          _Row(
                              label: 'Recipient Gets',
                              value: _coinStr(result.receiveAmount)),
                          const _Divider(),
                          _Row(label: 'Status', value: _statusLabel),
                          if (result.txId.isNotEmpty) ...[
                            const _Divider(),
                            _HashRow(hash: result.txId),
                          ],
                          const _Divider(),
                          _Row(label: 'Reference', value: result.reference),
                          const _Divider(),
                          _Row(label: 'Date', value: _dateStr),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Buttons ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => _shareReceipt(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Copy Reference',
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
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFD7FC),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Done',
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
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _kGrey)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _kDark),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String hash;
  const _HashRow({required this.hash});

  String get _short =>
      hash.length <= 14 ? hash : '${hash.substring(0, 8)}.......${hash.substring(hash.length - 5)}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Transaction Hash',
              style: TextStyle(fontSize: 13, color: _kGrey)),
          Text(
            _short,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kDark,
              decoration: TextDecoration.underline,
            ),
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
      const Divider(height: 1, color: _kBorder);
}
