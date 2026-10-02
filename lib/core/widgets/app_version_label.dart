import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';

/// Displays the app version from package metadata, e.g. `v1.0.0`.
///
/// Does not include the build number. Version is read from [pubspec.yaml]
/// via [PackageInfo] — do not hardcode.
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        if (version == null || version.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: alignment,
          child: Text(
            'v$version',
            textAlign: textAlign,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: fontSize,
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
          ),
        );
      },
    );
  }
}
