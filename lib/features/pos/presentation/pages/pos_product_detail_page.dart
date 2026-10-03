import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_product_detail_bloc.dart';

class PosProductDetailPage extends StatelessWidget {
  const PosProductDetailPage({
    super.key,
    required this.brandId,
    required this.productId,
  });

  final String brandId;
  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosProductDetailBloc>()
        ..add(PosProductDetailStarted(productId)),
      child: _PosProductDetailBody(
        brandId: brandId,
        productId: productId,
      ),
    );
  }
}

class _PosProductDetailBody extends StatelessWidget {
  const _PosProductDetailBody({
    required this.brandId,
    required this.productId,
  });

  final String brandId;
  final String productId;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocConsumer<PosProductDetailBloc, PosProductDetailState>(
      listenWhen: (prev, next) =>
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage) ||
          (next.successMessage != null &&
              next.successMessage != prev.successMessage),
      listener: (context, state) async {
        final message = state.errorMessage ?? state.successMessage;
        if (message != null) {
          await showAppMessageDialog(
            context,
            title: 'POS',
            message: message,
          );
        }
      },
      builder: (context, state) {
        if (state.status == PosProductDetailStatus.initial ||
            state.status == PosProductDetailStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }
        final detail = state.detail;
        if (detail == null) {
          return Center(
            child: Text(
              state.errorMessage ?? 'Product not found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        final product = detail.product;
        final effective = detail.effectiveSellingPrice;
        final busy = state.status == PosProductDetailStatus.saving;

        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                AppButton(
                  label: 'Edit',
                  expand: false,
                  enabled: !busy,
                  onPressed: () => context.go(
                    AppRoutes.posProductEdit(brandId, productId),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (product.sku.isNotEmpty) product.sku,
                if (product.category.isNotEmpty) product.category,
                product.productType == PosProductType.service
                    ? 'Service'
                    : 'Product',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
            const SizedBox(height: 20),
            _MetricRow(
              items: [
                _Metric('Selling price', MoneyFormat.format(product.sellingPrice)),
                _Metric(
                  'Effective price',
                  MoneyFormat.format(effective),
                ),
                _Metric(
                  'Purchase cost',
                  MoneyFormat.format(product.currentPurchaseCost),
                ),
                if (product.trackInventory && !product.isService)
                  _Metric(
                    'Stock',
                    product.stockOnHand.truncateToDouble() ==
                            product.stockOnHand
                        ? product.stockOnHand.toStringAsFixed(0)
                        : product.stockOnHand.toStringAsFixed(2),
                  ),
              ],
            ),
            _Section(
              title: 'Overview',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.labelBrand.isNotEmpty)
                    _kv('Brand', product.labelBrand),
                  if (product.mrp > 0)
                    _kv('MRP', MoneyFormat.format(product.mrp)),
                  _kv('Tax rate', '${product.taxRate}%'),
                  _kv(
                    'Price includes tax',
                    product.priceIncludesTax ? 'Yes' : 'No',
                  ),
                  if (product.shortDescription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(product.shortDescription),
                  ],
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (product.attributes.isNotEmpty)
              _Section(
                title: 'Attributes',
                child: Column(
                  children: [
                    for (final a in product.attributes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(a.name)),
                            Text(
                              a.value,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            _Section(
              title: 'Promotions',
              trailing: TextButton(
                onPressed: busy
                    ? null
                    : () => _showPromoDialog(context, product),
                child: const Text('Add'),
              ),
              child: detail.priceRules.isEmpty
                  ? Text(
                      'No promotions yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    )
                  : Column(
                      children: [
                        for (final rule in detail.priceRules)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(rule.name),
                            subtitle: Text(
                              '${AppDates.short.format(rule.startAt.toLocal())}'
                              ' – ${AppDates.short.format(rule.endAt.toLocal())}'
                              '${rule.isCurrentlyActive() ? ' · Active' : ''}',
                            ),
                            trailing: Text(
                              MoneyFormat.format(
                                rule.resolvedPrice(product.sellingPrice),
                              ),
                            ),
                            onLongPress: busy
                                ? null
                                : () => context
                                    .read<PosProductDetailBloc>()
                                    .add(
                                      PosPriceRuleRemoved(
                                        ruleId: rule.id,
                                        productId: productId,
                                      ),
                                    ),
                          ),
                      ],
                    ),
            ),
            if (product.trackInventory && !product.isService)
              _Section(
                title: 'Purchase history',
                trailing: TextButton(
                  onPressed: busy
                      ? null
                      : () => _showPurchaseDialog(context, product),
                  child: const Text('Record'),
                ),
                child: detail.purchases.isEmpty
                    ? Text(
                        'No purchases recorded.',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textLight,
                                ),
                      )
                    : Column(
                        children: [
                          for (final purchase in detail.purchases)
                            for (final item in purchase.items)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${AppDates.medium.format(purchase.purchaseDate)}'
                                  '${purchase.supplierName.isEmpty ? '' : ' · ${purchase.supplierName}'}',
                                ),
                                subtitle: Text(
                                  '${item.quantity} @ ${MoneyFormat.format(item.unitCost)}',
                                ),
                                trailing: Text(
                                  MoneyFormat.format(item.totalCost),
                                ),
                              ),
                        ],
                      ),
              ),
            _Section(
              title: 'Activity / Audit history',
              child: detail.audit.isEmpty
                  ? Text(
                      'No activity yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textLight,
                          ),
                    )
                  : Column(
                      children: [
                        for (final entry in detail.audit)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry.action),
                            subtitle: Text(
                              [
                                if (entry.performedAt != null)
                                  AppDates.medium.format(
                                    entry.performedAt!.toLocal(),
                                  ),
                                if (entry.performedByEmail.isNotEmpty)
                                  entry.performedByEmail,
                                if (entry.oldValue.isNotEmpty ||
                                    entry.newValue.isNotEmpty)
                                  '${entry.oldValue} → ${entry.newValue}',
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: const TextStyle(color: AppColors.textLight),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  Future<void> _showPurchaseDialog(
    BuildContext context,
    PosProduct product,
  ) async {
    final qty = TextEditingController(text: '1');
    final cost = TextEditingController(
      text: product.currentPurchaseCost > 0
          ? product.currentPurchaseCost.toString()
          : '',
    );
    final supplier = TextEditingController();
    final invoice = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Record purchase'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: qty,
                label: 'Quantity',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: cost,
                label: 'Unit purchase price',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: supplier, label: 'Supplier'),
              const SizedBox(height: 12),
              AppTextField(controller: invoice, label: 'Invoice number'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final quantity = double.tryParse(qty.text.trim()) ?? 0;
    final unitCost = double.tryParse(cost.text.trim()) ?? -1;
    context.read<PosProductDetailBloc>().add(
          PosPurchaseRecorded(
            PosPurchaseDraft(
              brandId: brandId,
              productId: productId,
              quantity: quantity,
              unitCost: unitCost,
              purchaseDate: DateTime.now(),
              supplierName: supplier.text.trim(),
              invoiceNumber: invoice.text.trim(),
            ),
          ),
        );
  }

  Future<void> _showPromoDialog(
    BuildContext context,
    PosProduct product,
  ) async {
    final name = TextEditingController();
    final value = TextEditingController(text: '10');
    var type = PosDiscountType.percentage;
    final start = DateTime.now();
    final end = DateTime.now().add(const Duration(days: 14));
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text('Add promotion'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(controller: name, label: 'Promotion name'),
                const SizedBox(height: 12),
                AppDropdown<PosDiscountType>(
                  label: 'Discount type',
                  value: type,
                  items: PosDiscountType.values,
                  itemLabel: (t) {
                    switch (t) {
                      case PosDiscountType.percentage:
                        return 'Percentage';
                      case PosDiscountType.fixedAmount:
                        return 'Fixed amount';
                      case PosDiscountType.fixedPrice:
                        return 'Fixed selling price';
                    }
                  },
                  onChanged: (v) {
                    if (v != null) setLocal(() => type = v);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: value,
                  label: type == PosDiscountType.percentage
                      ? 'Discount %'
                      : 'Value',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final discountValue = double.tryParse(value.text.trim()) ?? 0;
    context.read<PosProductDetailBloc>().add(
          PosPriceRuleSaved(
            PosPriceRule(
              id: '',
              brandId: brandId,
              productId: productId,
              name: name.text.trim().isEmpty
                  ? 'Promotion'
                  : name.text.trim(),
              discountType: type,
              discountValue: discountValue,
              finalPrice:
                  type == PosDiscountType.fixedPrice ? discountValue : null,
              startAt: start,
              endAt: end,
              isActive: true,
              priority: 10,
            ),
          ),
        );
  }
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
