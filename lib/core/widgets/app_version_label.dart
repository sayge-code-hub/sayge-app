import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../router/app_routes.dart';
import '../theme/app_colors.dart';

/// Displays the app version from package metadata, e.g. `v1.0.2`.
///
/// Always three-part semver (`major.minor.patch`) — never a `+build` suffix.
/// Tap to open curated release notes.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
    this.fontSize = 12,
  });

  final AlignmentGeometry alignment;
  final TextAlign textAlign;
  final double fontSize;

  static Future<PackageInfo>? _cached;

  static Future<PackageInfo> _info() =>
      _cached ??= PackageInfo.fromPlatform();

  void _openNotes(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc == AppRoutes.whatsNew) return;
    context.push(AppRoutes.whatsNew);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version;
        if (version == null || version.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: alignment,
          child: Tooltip(
            message: 'Release notes',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openNotes(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v$version',
                        textAlign: textAlign,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: fontSize,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.history_edu_outlined,
                        size: fontSize + 1,
                        color: AppColors.textLight.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
