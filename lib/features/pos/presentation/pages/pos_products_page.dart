import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_products_bloc.dart';

class PosProductsPage extends StatelessWidget {
  const PosProductsPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<PosProductsBloc>()..add(PosProductsStarted(brandId)),
      child: _PosProductsBody(brandId: brandId),
    );
  }
}

class _PosProductsBody extends StatefulWidget {
  const _PosProductsBody({required this.brandId});

  final String brandId;

  @override
  State<_PosProductsBody> createState() => _PosProductsBodyState();
}

class _PosProductsBodyState extends State<_PosProductsBody> {
  String _query = '';

  List<PosProduct> _filtered(List<PosProduct> products) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          p.labelBrand.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final bloc = context.read<PosProductsBloc>();

    return BlocConsumer<PosProductsBloc, PosProductsState>(
      listenWhen: (prev, next) =>
          (next.successMessage != null &&
              next.successMessage != prev.successMessage) ||
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage),
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
        if (state.status == PosProductsStatus.initial ||
            state.status == PosProductsStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final busy = state.status == PosProductsStatus.saving;
        final products = _filtered(state.products);
        final newProduct = AppButton(
          label: 'New product',
          expand: !isDesktop,
          enabled: !busy,
          onPressed: () =>
              context.go(AppRoutes.posProductAdd(widget.brandId)),
        );

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isDesktop ? 8 : 12,
                horizontal,
                12,
              ),
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(
                          child: AppListSearchField(
                            hintText: 'Search products…',
                            onChanged: (v) => setState(() => _query = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        newProduct,
                      ],
                    )
                  : AppListSearchField(
                      hintText: 'Search products…',
                      onChanged: (v) => setState(() => _query = v),
                    ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: state.products.isEmpty
                  ? Center(
                      child: Text(
                        'No products yet.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textLight,
                            ),
                      ),
                    )
                  : products.isEmpty
                      ? Center(
                          child: Text(
                            'No matching products.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textLight),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            16,
                            horizontal,
                            24,
                          ),
                          itemCount: products.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final thumb = product.primaryImagePath;
                            final url = thumb == null
                                ? null
                                : bloc.imageUrl(thumb);
                            return AppListCard(
                              onTap: busy
                                  ? null
                                  : () => context.go(
                                        AppRoutes.posProductDetail(
                                          widget.brandId,
                                          product.id,
                                        ),
                                      ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: AppColors.surfaceMuted,
                                      child: url == null || url.isEmpty
                                          ? const Icon(
                                              Icons.image_outlined,
                                              color: AppColors.textLight,
                                            )
                                          : Image.network(
                                              url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                Icons.broken_image_outlined,
                                                color: AppColors.textLight,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (product.sku.isNotEmpty)
                                              product.sku,
                                            if (product.category.isNotEmpty)
                                              product.category,
                                            if (product.trackInventory &&
                                                !product.isService)
                                              'Stock ${product.stockOnHand.truncateToDouble() == product.stockOnHand ? product.stockOnHand.toStringAsFixed(0) : product.stockOnHand.toStringAsFixed(2)}',
                                            if (product.isService) 'Service',
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
                                  Text(
                                    MoneyFormat.format(product.sellingPrice),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontSize: 13),
                                  ),
                                  PopupMenuButton<String>(
                                    enabled: !busy,
                                    onSelected: (value) async {
                                      if (value == 'view') {
                                        context.go(
                                          AppRoutes.posProductDetail(
                                            widget.brandId,
                                            product.id,
                                          ),
                                        );
                                      }
                                      if (value == 'edit') {
                                        context.go(
                                          AppRoutes.posProductEdit(
                                            widget.brandId,
                                            product.id,
                                          ),
                                        );
                                      }
                                      if (value == 'delete') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogContext) =>
                                              AlertDialog(
                                            backgroundColor:
                                                AppColors.background,
                                            title: const Text('Delete product'),
                                            content: Text(
                                              'Delete "${product.name}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                  dialogContext,
                                                  false,
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                  dialogContext,
                                                  true,
                                                ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      AppColors.error,
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true && context.mounted) {
                                          context.read<PosProductsBloc>().add(
                                                PosProductDeleted(
                                                  productId: product.id,
                                                  brandId: widget.brandId,
                                                ),
                                              );
                                        }
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'view',
                                        child: Text('View'),
                                      ),
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            if (!isDesktop)
              AppStickyActions(children: [newProduct]),
          ],
        );
      },
    );
  }
}
