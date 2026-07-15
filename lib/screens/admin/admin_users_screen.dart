import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import '../../widgets/error_snackbar.dart';

const _kBlue = Color(0xFF0E24A0);
const _kDark = Color(0xFF111827);
const _kGrey = Color(0xFF9CA3AF);
const _kBorder = Color(0xFFE5E7EB);
const _kBg = Color(0xFFF9FAFB);

String _fmtBalance(String raw) {
  final v = double.tryParse(raw) ?? 0;
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final intStr = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₦$intStr.${parts[1]}';
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<AdminUser> _users = [];
  int _total = 0;
  int _active = 0;
  int _blacklisted = 0;

  bool _loading = true;
  String _loadError = '';
  String _query = '';

  // Which filter tab is selected: 'all' | 'active' | 'blacklisted'
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final result = await AdminService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = result.users;
        _total = result.total;
        _active = result.active;
        _blacklisted = result.blacklisted;
        _loading = false;
      });
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  List<AdminUser> get _filtered {
    var list = _users;
    if (_filter == 'active') list = list.where((u) => u.isActive).toList();
    if (_filter == 'blacklisted') {
      list = list.where((u) => !u.isActive).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.phone.contains(q))
          .toList();
    }
    return list;
  }

  Future<void> _toggleBlacklist(AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: user.isActive ? 'Blacklist User' : 'Restore User',
        message: user.isActive
            ? '${user.fullName} will be blocked from signing in.'
            : '${user.fullName} will be able to sign in again.',
        confirmLabel: user.isActive ? 'Blacklist' : 'Restore',
        destructive: user.isActive,
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final newActive = await AdminService.toggleBlacklist(user.id);
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) {
          _users[idx] = _users[idx].copyWith(isActive: newActive);
          _active = _users.where((u) => u.isActive).length;
          _blacklisted = _users.where((u) => !u.isActive).length;
        }
      });
      _toast(newActive
          ? '${user.fullName} restored.'
          : '${user.fullName} blacklisted.');
    } on AdminException catch (e) {
      if (mounted) showErrorSnackbar(context, e.message);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kBlue,
      behavior: SnackBarBehavior.floating,
    ));
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
          'Users',
          style: TextStyle(
              color: _kDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh, color: _kGrey, size: 20),
              onPressed: _load,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _loadError.isNotEmpty
              ? _ErrorBody(message: _loadError, onRetry: _load)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final list = _filtered;

    return Column(
      children: [
        // ── Stats bar ──────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              _StatChip(
                label: 'All',
                count: _total,
                selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Active',
                count: _active,
                selected: _filter == 'active',
                color: Colors.green,
                onTap: () => setState(() => _filter = 'active'),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Blacklisted',
                count: _blacklisted,
                selected: _filter == 'blacklisted',
                color: Colors.red,
                onTap: () => setState(() => _filter = 'blacklisted'),
              ),
            ],
          ),
        ),

        // ── Search ────────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14, color: _kDark),
            decoration: InputDecoration(
              hintText: 'Search by name, email, or phone',
              hintStyle: const TextStyle(fontSize: 13, color: _kGrey),
              prefixIcon:
                  const Icon(Icons.search, color: _kGrey, size: 20),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const Divider(height: 1, color: _kBorder),

        // ── User list ─────────────────────────────────────────────────────
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Text(
                    _query.isNotEmpty
                        ? 'No users match "$_query"'
                        : 'No users found.',
                    style: const TextStyle(color: _kGrey, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) => _UserTile(
                    user: list[i],
                    onToggle: () => _toggleBlacklist(list[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onToggle;

  const _UserTile({required this.user, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final initials = user.fullName.trim().isNotEmpty
        ? user.fullName.trim().split(' ').map((p) => p[0]).take(2).join()
        : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Avatar / initials
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: user.isActive
                  ? _kBlue.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: user.isActive ? _kBlue : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name / email / balance
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!user.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Blacklisted',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(user.email,
                    style:
                        const TextStyle(fontSize: 12, color: _kGrey)),
                const SizedBox(height: 2),
                Text(
                  'Balance: ${_fmtBalance(user.ngnBalance)}',
                  style: const TextStyle(fontSize: 12, color: _kGrey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Blacklist / restore button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: user.isActive
                    ? Colors.red.withValues(alpha: 0.08)
                    : Colors.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: user.isActive
                      ? Colors.red.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                user.isActive ? 'Blacklist' : 'Restore',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: user.isActive ? Colors.red : Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip (filter tab) ────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.count,
    required this.selected,
    this.color = _kBlue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? color : _kGrey,
          ),
        ),
      ),
    );
  }
}

// ── Confirm dialog ────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: _kDark)),
      content: Text(message,
          style: const TextStyle(fontSize: 14, color: _kGrey)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel',
              style: TextStyle(color: _kGrey, fontSize: 14)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? Colors.red : Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kGrey, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _kBlue),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
