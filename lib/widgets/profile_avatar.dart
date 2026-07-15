import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ProfileAvatar extends StatelessWidget {
  final AuthUser? user;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 36,
    this.onTap,
    this.showEditBadge = false,
  });

  String get _initials {
    final parts = user?.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList() ?? [];

    if (parts.isEmpty) return 'A';

    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';

    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photo = user?.profilePhoto;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: hasPhoto ? null : const Color(0xFF0E24A0),
      backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
      child: hasPhoto
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.45,
                fontWeight: FontWeight.bold,
              ),
            ),
    );

    final child = showEditBadge
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                bottom: -14,
                left: -18,
                right: -18,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 12, color: Color(0xFF0E24A0)),
                        SizedBox(width: 4),
                        Text(
                          'Edit picture',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : avatar;

    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
