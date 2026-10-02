import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/app_colors.dart';

/// Displays the app version from package metadata, e.g. `v1.0.0`.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        if (version == null) {
          return const SizedBox.shrink();
        }

        return Text(
          'v$version',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
        );
      },
    );
  }
}
