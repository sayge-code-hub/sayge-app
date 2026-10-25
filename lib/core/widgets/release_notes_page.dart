import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../release_notes/app_release_notes.dart';
import '../theme/app_colors.dart';

/// Full-screen release history — opened by tapping the version label.
class ReleaseNotesPage extends StatefulWidget {
  const ReleaseNotesPage({super.key});

  @override
  State<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends State<ReleaseNotesPage> {
  String? _runningVersion;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _runningVersion = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _runningVersion?.trim() ?? '';
    final notes = AppReleaseNotes.all;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.text,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Release notes',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    letterSpacing: -0.4,
                                    color: AppColors.text,
                                  ),
                        ),
                      ),
                      if (running.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.highlight.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  AppColors.highlight.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            'Running v$running',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.highlight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Text(
                    'Sayge ships with three-part semver (vMAJOR.MINOR.PATCH). '
                    'Each production deploy bumps the patch automatically.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                          height: 1.45,
                          fontSize: 13,
                        ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isCurrent = running.isNotEmpty &&
                          note.version == running;
                      return _ReleaseCard(
                        note: note,
                        isCurrent: isCurrent,
                        isFirst: index == 0,
                        isLast: index == notes.length - 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.note,
    required this.isCurrent,
    required this.isFirst,
    required this.isLast,
  });

  final AppReleaseNote note;
  final bool isCurrent;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final stamp = DateFormat('d MMM yyyy · HH:mm').format(
      note.releasedAt.toLocal(),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? AppColors.highlight
                        : AppColors.textLight.withValues(alpha: 0.45),
                    border: Border.all(
                      color: AppColors.background,
                      width: 2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.highlight.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isLast
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent
                      ? AppColors.highlight.withValues(alpha: 0.45)
                      : AppColors.border,
                  width: isCurrent ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        note.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: AppColors.text,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.highlight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Current',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        stamp,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final line in note.highlights) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.highlight
                                    .withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppColors.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
