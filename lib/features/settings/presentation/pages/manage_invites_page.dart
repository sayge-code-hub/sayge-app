import 'package:flutter/material.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../data/datasources/invite_employee_remote_datasource.dart';
import '../../domain/entities/pending_invite.dart';

class ManageInvitesPage extends StatefulWidget {
  const ManageInvitesPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ManageInvitesPage> createState() => _ManageInvitesPageState();
}

class _ManageInvitesPageState extends State<ManageInvitesPage> {
  List<PendingInvite> _invites = const [];
  bool _loading = true;
  String? _error;
  String? _busyEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await sl<InviteEmployeeRemoteDataSource>().listPending();
      if (!mounted) return;
      setState(() {
        _invites = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _invites = const [];
      });
    }
  }

  Future<void> _resend(PendingInvite invite) async {
    setState(() => _busyEmail = invite.email);
    try {
      await sl<InviteEmployeeRemoteDataSource>().resend(invite.email);
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        message: 'Invite resent to ${invite.email}.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Resend invite',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _busyEmail = null);
    }
  }

  Future<void> _revoke(PendingInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Revoke invite'),
        content: Text(
          'Revoke the pending invite for ${invite.email}? '
          'If they never accepted, the account will be removed.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyEmail = invite.email);
    try {
      await sl<InviteEmployeeRemoteDataSource>().revoke(
        email: invite.email,
        userId: invite.id,
      );
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        message: 'Invite revoked for ${invite.email}.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Revoke invite',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _busyEmail = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final pad = EdgeInsets.fromLTRB(
      isDesktop ? 32 : 16,
      isDesktop ? 12 : 8,
      isDesktop ? 32 : 16,
      24,
    );

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: pad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_invites.isEmpty) {
      return Center(
        child: Padding(
          padding: pad,
          child: Text(
            'No pending invites.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: pad,
        itemCount: _invites.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final invite = _invites[index];
          final busy = _busyEmail == invite.email;
          return AppListCard(
            borderRadius: 12,
            padding: AppListCard.sectionPadding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 420;
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                          ),
                    ),
                    if (invite.fullName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        invite.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                  color: AppColors.textLight,
                                ),
                      ),
                    ],
                    if (invite.invitedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Invited ${AppDates.medium.format(invite.invitedAt!)}',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                      ),
                    ],
                  ],
                );
                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => _resend(invite),
                      child: Text(busy ? '…' : 'Resend'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => _revoke(invite),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Revoke'),
                    ),
                  ],
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actions,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    actions,
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
