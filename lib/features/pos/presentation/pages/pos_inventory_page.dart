import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../bloc/pos_products_bloc.dart';

/// Inventory-focused product stock list for a brand.
class PosInventoryPage extends StatelessWidget {
  const PosInventoryPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosProductsBloc>()
        ..add(PosProductsStarted(brandId)),
      child: _PosInventoryBody(brandId: brandId),
    );
  }
}

class _PosInventoryBody extends StatelessWidget {
  const _PosInventoryBody({required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocBuilder<PosProductsBloc, PosProductsState>(
      builder: (context, state) {
        if (state.status == PosProductsStatus.initial ||
            state.status == PosProductsStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final tracked = state.products
            .where((p) => p.trackInventory)
            .toList(growable: false);

        if (tracked.isEmpty) {
          return Center(
            child: Text(
              'No tracked inventory yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
          itemCount: tracked.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final product = tracked[index];
            final low = product.stockOnHand <= product.reorderLevel;
            return AppListCard(
              onTap: () => context.go(
                AppRoutes.posProductDetail(brandId, product.id),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.sku.isEmpty ? product.category : product.sku,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${MoneyFormat.format(product.stockOnHand)} ${product.unitOfMeasure}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 13,
                              color: low ? AppColors.error : AppColors.text,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        low ? 'Low stock' : 'In stock',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              color: low ? AppColors.error : AppColors.textLight,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
