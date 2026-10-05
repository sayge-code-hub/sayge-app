import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Circular employee photo with initials fallback.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 18,
    this.fontSize,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final double? fontSize;

  static String initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim() ?? '';
    final hasPhoto = url.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.text.withValues(alpha: 0.08),
      backgroundImage: hasPhoto ? NetworkImage(url) : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto
          ? null
          : Text(
              initialsFor(name),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: fontSize ?? (radius * 0.67),
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
            ),
    );
  }
}
