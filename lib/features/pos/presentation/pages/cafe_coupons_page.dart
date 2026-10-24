import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_catalog.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafeCouponsPage extends StatefulWidget {
  const CafeCouponsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeCouponsPage> createState() => _CafeCouponsPageState();
}

class _CafeCouponsPageState extends State<CafeCouponsPage> {
  List<CafeCoupon> _coupons = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetCafeCoupons>()(widget.cafeId);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _coupons = list;
        _loading = false;
      }),
    );
  }

  Future<void> _edit([CafeCoupon? existing]) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final value = TextEditingController(
      text: existing == null ? '' : existing.discountValue.toStringAsFixed(
            existing.discountType == CafeDiscountType.percent ? 0 : 2,
          ),
    );
    final minOrder = TextEditingController(
      text: existing == null || existing.minOrderAmount <= 0
          ? ''
          : existing.minOrderAmount.toStringAsFixed(0),
    );
    final maxDisc = TextEditingController(
      text: existing?.maxDiscountAmount == null
          ? ''
          : existing!.maxDiscountAmount!.toStringAsFixed(0),
    );
    final maxUses = TextEditingController(
      text: existing?.maxUses?.toString() ?? '',
    );
    var type = existing?.discountType ?? CafeDiscountType.percent;
    var active = existing?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(existing == null ? 'New coupon' : 'Edit coupon'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Code',
                    controller: code,
                    autofocus: existing == null,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Label (optional)',
                    controller: name,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CafeDiscountType>(
                    // ignore: deprecated_member_use
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final t in CafeDiscountType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocal(() => type = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: type == CafeDiscountType.percent
                        ? 'Percent'
                        : 'Amount',
                    controller: value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Min order (optional)',
                    controller: minOrder,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (type == CafeDiscountType.percent) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Max discount cap (optional)',
                      controller: maxDisc,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Max uses (optional)',
                    controller: maxUses,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Save',
              expand: false,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final dv = double.tryParse(value.text.trim()) ?? -1;
    if (code.text.trim().isEmpty || dv <= 0) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Coupons',
        message: 'Code and a valid discount value are required.',
      );
      return;
    }

    final result = await sl<UpsertCafeCoupon>()(
      CafeCoupon(
        id: existing?.id ?? '',
        cafeId: widget.cafeId,
        code: code.text.trim(),
        name: name.text.trim(),
        discountType: type,
        discountValue: dv,
        minOrderAmount: double.tryParse(minOrder.text.trim()) ?? 0,
        maxDiscountAmount: type == CafeDiscountType.percent
            ? double.tryParse(maxDisc.text.trim())
            : null,
        isActive: active,
        startsAt: existing?.startsAt,
        endsAt: existing?.endsAt,
        maxUses: int.tryParse(maxUses.text.trim()),
        usageCount: existing?.usageCount ?? 0,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) =>
          showAppMessageDialog(context, title: 'Coupons', message: f.message),
      (_) => _reload(),
    );
  }

  Future<void> _delete(CafeCoupon coupon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Delete “${coupon.code}”?'),
        content: const Text('Cashiers will no longer be able to use this code.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Delete',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await sl<DeleteCafeCoupon>()(coupon.id);
    if (!mounted) return;
    result.fold(
      (f) =>
          showAppMessageDialog(context, title: 'Coupons', message: f.message),
      (_) => _reload(),
    );
  }

  String _discountLabel(CafeCoupon c) {
    if (c.discountType == CafeDiscountType.percent) {
      final pct = c.discountValue == c.discountValue.roundToDouble()
          ? c.discountValue.toStringAsFixed(0)
          : c.discountValue.toStringAsFixed(1);
      return '$pct% off';
    }
    return '${MoneyFormat.format(c.discountValue)} off';
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Coupon settings access denied.')),
      );
    }
    if (_loading) {
      return const CafePosBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }
    if (_error != null) {
      return CafePosBackdrop(
        child: CafePosEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn’t load coupons',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    return CafePosBackdrop(
      child: Column(
        children: [
          Expanded(
            child: _coupons.isEmpty
                ? const CafePosEmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No coupons yet',
                    message:
                        'Create codes like SAVE10 for percent or fixed discounts.',
                  )
                : ListView(
                    padding: CafePosSpace.page(context),
                    children: [
                      for (final c in _coupons) ...[
                        Material(
                          color: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CafePosSpace.radius),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            c.code,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  letterSpacing: 0.4,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: c.isActive
                                                  ? AppColors.success
                                                      .withValues(alpha: 0.12)
                                                  : AppColors.surfaceMuted,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              c.isActive
                                                  ? 'Active'
                                                  : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: c.isActive
                                                    ? AppColors.success
                                                    : AppColors.textLight,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          _discountLabel(c),
                                          if (c.name.isNotEmpty) c.name,
                                          if (c.minOrderAmount > 0)
                                            'Min ${MoneyFormat.format(c.minOrderAmount)}',
                                          if (c.maxUses != null)
                                            '${c.usageCount}/${c.maxUses} used',
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textLight,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _edit(c),
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                    color: AppColors.highlight,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(c),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          CafePosStickyAction(
            label: 'Add coupon',
            onPressed: () => _edit(),
          ),
        ],
      ),
    );
  }
}
