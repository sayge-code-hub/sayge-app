import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/billing/billing_access.dart';
import '../../../../core/billing/billing_models.dart';
import '../../../../core/billing/billing_remote_datasource.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';

/// Closed-beta billing console (staff). Manual mark paid — no gateway.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _remote = sl<BillingRemoteDataSource>();
  BillingState? _state;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  final _graceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _offerCodeCtrl = TextEditingController();
  final _offerNameCtrl = TextEditingController();
  final _offerPercentCtrl = TextEditingController();
  final _offerFixedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _graceCtrl.dispose();
    _notesCtrl.dispose();
    _offerCodeCtrl.dispose();
    _offerNameCtrl.dispose();
    _offerPercentCtrl.dispose();
    _offerFixedCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await _remote.getState();
      if (!mounted) return;
      _apply(state);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _apply(BillingState state) {
    sl<BillingAccess>().applyState(state);
    _graceCtrl.text = '${state.snapshot.graceDays}';
    _notesCtrl.text = state.manualNotes;
    setState(() {
      _state = state;
      _loading = false;
      _busy = false;
      _error = null;
    });
  }

  Future<void> _run(Future<BillingState> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final state = await action();
      if (!mounted) return;
      _apply(state);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final mapped = mapBillingDbError(
        e,
        _state?.snapshot ?? BillingSnapshot.permissive,
      );
      await showAppMessageDialog(
        context,
        title: 'Billing',
        message: mapped ?? e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  String _inr(double v) {
    if (v == v.roundToDouble()) return '₹${v.round()}';
    return '₹${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final state = _state;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        isDesktop ? 20 : 12,
        isDesktop ? 32 : 16,
        isDesktop ? 32 : 24,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              : _error != null && state == null
                  ? _ErrorPane(message: _error!, onRetry: _reload)
                  : ListView(
                      children: [
                        Row(
                          children: [
                            if (widget.onBack != null)
                              IconButton(
                                onPressed: widget.onBack,
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                            Expanded(
                              child: Text(
                                'Billing',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh',
                              onPressed: _busy ? null : _reload,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Per-company Saasify billing · payment gateway not '
                          'connected yet. Mark periods paid after bank/UPI, or '
                          'use Free self-serve signup.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        if (state != null) ...[
                          _StatusCard(state: state, inr: _inr),
                          const SizedBox(height: 16),
                          _SectionTitle('Plan'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final plan in state.plans)
                                ChoiceChip(
                                  label: Text(
                                    '${plan.name} · ${_inr(plan.priceInr)}/mo · '
                                    '${plan.employeeLimit} emp',
                                  ),
                                  selected:
                                      plan.code == state.snapshot.planCode,
                                  onSelected: _busy
                                      ? null
                                      : (selected) {
                                          if (!selected) return;
                                          _run(() => _remote.setPlan(plan.code));
                                        },
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle('Current period'),
                          const SizedBox(height: 8),
                          if (state.currentPeriod != null)
                            _PeriodCard(
                              period: state.currentPeriod!,
                              busy: _busy,
                              inr: _inr,
                              onMark: (status) => _run(
                                () => _remote.markPeriod(
                                  periodId: state.currentPeriod!.id,
                                  status: status,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          _SectionTitle('Grace & Cafe POS'),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 120,
                                child: AppTextField(
                                  label: 'Grace days',
                                  controller: _graceCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                label: 'Save',
                                expand: false,
                                enabled: !_busy,
                                onPressed: () {
                                  final days =
                                      int.tryParse(_graceCtrl.text.trim());
                                  if (days == null) return;
                                  _run(() => _remote.setGraceDays(days));
                                },
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  Text(
                                    'Cafe POS access',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Switch(
                                    value: state.snapshot.posEnabled,
                                    onChanged: _busy
                                        ? null
                                        : (v) => _run(
                                              () => _remote.setPosEnabled(v),
                                            ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'POS is a future paid add-on. Toggle only enables or '
                            'disables access — no price is charged here.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textLight),
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle('Offers'),
                          const SizedBox(height: 8),
                          if (state.offer != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.success
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Active: ${state.offer!.code}'
                                      '${state.offerPriceInr != null ? ' · ${_inr(state.offerPriceInr!)}' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(_remote.clearOffer),
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (state.offers.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final o in state.offers)
                                  ActionChip(
                                    label: Text(
                                      o.percentOff != null
                                          ? '${o.code} (−${o.percentOff!.round()}%)'
                                          : '${o.code} (${_inr(o.fixedPriceInr ?? 0)})',
                                    ),
                                    onPressed: _busy
                                        ? null
                                        : () => _run(
                                              () => _remote.applyOffer(
                                                offerId: o.id,
                                              ),
                                            ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          AppTextField(
                            label: 'New offer code',
                            controller: _offerCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            label: 'Offer name',
                            controller: _offerNameCtrl,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  label: 'Percent off',
                                  controller: _offerPercentCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppTextField(
                                  label: 'Or fixed ₹ price',
                                  controller: _offerFixedCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: 'Create & apply offer',
                            enabled: !_busy,
                            onPressed: () async {
                              final code = _offerCodeCtrl.text.trim();
                              if (code.isEmpty) return;
                              final pct = double.tryParse(
                                _offerPercentCtrl.text.trim(),
                              );
                              final fixed = double.tryParse(
                                _offerFixedCtrl.text.trim(),
                              );
                              if ((pct == null) == (fixed == null)) {
                                await showAppMessageDialog(
                                  context,
                                  title: 'Offer',
                                  message:
                                      'Set either percent off or a fixed price, not both.',
                                );
                                return;
                              }
                              await _run(() async {
                                final created = await _remote.upsertOffer(
                                  code: code,
                                  name: _offerNameCtrl.text.trim(),
                                  appliesToPlan: state.snapshot.planCode,
                                  percentOff: pct,
                                  fixedPriceInr: fixed,
                                );
                                BillingOffer? match;
                                for (final o in created.offers) {
                                  if (o.code.toUpperCase() ==
                                      code.toUpperCase()) {
                                    match = o;
                                    break;
                                  }
                                }
                                match ??=
                                    created.offers.isEmpty ? null : created.offers.first;
                                if (match == null) return created;
                                return _remote.applyOffer(offerId: match.id);
                              });
                              _offerCodeCtrl.clear();
                              _offerNameCtrl.clear();
                              _offerPercentCtrl.clear();
                              _offerFixedCtrl.clear();
                            },
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle('Internal notes'),
                          const SizedBox(height: 8),
                          AppTextField(
                            label: 'Notes',
                            controller: _notesCtrl,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            label: 'Save notes',
                            enabled: !_busy,
                            onPressed: () => _run(
                              () => _remote.setNotes(_notesCtrl.text),
                            ),
                          ),
                          if (state.periods.length > 1) ...[
                            const SizedBox(height: 24),
                            _SectionTitle('Recent periods'),
                            const SizedBox(height: 8),
                            for (final p in state.periods.skip(1).take(6))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(p.periodYm),
                                subtitle: Text(
                                  '${p.paymentStatus.label} · due ${_inr(p.amountDueInr)}',
                                ),
                                trailing: p.paymentStatus ==
                                        BillingPaymentStatus.unpaid
                                    ? TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _run(
                                                  () => _remote.markPeriod(
                                                    periodId: p.id,
                                                    status:
                                                        BillingPaymentStatus
                                                            .paid,
                                                  ),
                                                ),
                                        child: const Text('Mark paid'),
                                      )
                                    : null,
                              ),
                          ],
                        ],
                      ],
                    ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.inr});

  final BillingState state;
  final String Function(double) inr;

  @override
  Widget build(BuildContext context) {
    final s = state.snapshot;
    final due = state.currentPeriod?.amountDueInr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.planName} · ${s.status.label}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Employees ${s.activeEmployees} / ${s.employeeLimit}'
            '${due != null ? ' · Due ${inr(due)} this period' : ''}',
          ),
          if (s.isPastDue || s.isReadOnly) ...[
            const SizedBox(height: 8),
            Text(
              s.isReadOnly
                  ? BillingRules.readOnlyMessage()
                  : 'Payment past due — writes still allowed during grace'
                      '${state.graceEndsAt != null ? ' (until ${state.graceEndsAt!.toLocal().toString().split('.').first})' : ''}.',
              style: TextStyle(
                color: s.isReadOnly ? AppColors.error : AppColors.highlight,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.busy,
    required this.inr,
    required this.onMark,
  });

  final BillingPeriod period;
  final bool busy;
  final String Function(double) inr;
  final void Function(BillingPaymentStatus status) onMark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${period.periodYm} · ${period.paymentStatus.label}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'List ${inr(period.listPriceInr)} · Due ${inr(period.amountDueInr)}'
            '${period.amountPaidInr > 0 ? ' · Paid ${inr(period.amountPaidInr)}' : ''}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => onMark(BillingPaymentStatus.paid),
                child: const Text('Mark paid'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => onMark(BillingPaymentStatus.waived),
                child: const Text('Waive'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => onMark(BillingPaymentStatus.comped),
                child: const Text('Comp'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => onMark(BillingPaymentStatus.unpaid),
                child: const Text('Mark unpaid'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing is not available yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apply supabase/billing_closed_beta.sql in Supabase (after '
            'security_hardening.sql), then refresh.\n\n$message',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'Retry', expand: false, onPressed: onRetry),
        ],
      ),
    );
  }
}
