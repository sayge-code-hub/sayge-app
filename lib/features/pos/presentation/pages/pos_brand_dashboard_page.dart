import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_hub_tile.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_products_bloc.dart';

/// Brand landing hub: stats + navigation tiles.
class PosBrandDashboardPage extends StatelessWidget {
  const PosBrandDashboardPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosProductsBloc>()
        ..add(PosProductsStarted(brandId)),
      child: _PosBrandDashboardBody(brandId: brandId),
    );
  }
}

class _PosBrandDashboardBody extends StatelessWidget {
  const _PosBrandDashboardBody({required this.brandId});

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

        if (state.status == PosProductsStatus.failure &&
            state.products.isEmpty &&
            state.brand == null) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Text(
                state.errorMessage ?? 'Failed to load brand.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
            ),
          );
        }

        final products = state.products;
        final active = products.where((p) => p.isActive).length;
        final inactive = products.length - active;
        final lowStock = products.where((p) {
          if (!p.trackInventory || !p.isActive) return false;
          return p.stockOnHand <= p.reorderLevel;
        }).length;
        final outOfStock = products.where((p) {
          if (!p.trackInventory || !p.isActive) return false;
          return p.stockOnHand <= 0;
        }).length;
        final categories = products
            .map((p) => p.category.trim().toLowerCase())
            .where((c) => c.isNotEmpty)
            .toSet()
            .length;
        final services = products
            .where((p) => p.productType == PosProductType.service)
            .length;
        final stockValue = products.fold<double>(
          0,
          (sum, p) => sum + (p.stockOnHand * p.currentPurchaseCost),
        );

        final tiles = [
          _HubTileData(
            title: 'All products',
            icon: Icons.inventory_2_outlined,
            path: AppRoutes.posProducts(brandId),
          ),
          _HubTileData(
            title: 'Manage inventory',
            icon: Icons.warehouse_outlined,
            path: AppRoutes.posInventory(brandId),
          ),
          _HubTileData(
            title: 'POS',
            icon: Icons.point_of_sale_outlined,
            path: AppRoutes.posTerminal(brandId),
          ),
          _HubTileData(
            title: 'Analytics',
            icon: Icons.insights_outlined,
            path: AppRoutes.posAnalytics(brandId),
          ),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            isDesktop ? 8 : 12,
            horizontal,
            24,
          ),
          children: [
            _sectionHeading(context, 'Overview'),
            const SizedBox(height: 12),
            _StatsRow(
              isDesktop: isDesktop,
              items: [
                _StatItem(label: 'Products', value: '${products.length}'),
                _StatItem(label: 'Active', value: '$active'),
                _StatItem(label: 'Low stock', value: '$lowStock'),
                _StatItem(
                  label: 'Stock value',
                  value: MoneyFormat.format(stockValue),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _StatsRow(
              isDesktop: isDesktop,
              items: [
                _StatItem(label: 'Inactive', value: '$inactive'),
                _StatItem(label: 'Out of stock', value: '$outOfStock'),
                _StatItem(label: 'Categories', value: '$categories'),
                _StatItem(label: 'Services', value: '$services'),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 20),
            _sectionHeading(context, 'Modules'),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tiles.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 4 : 1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: isDesktop ? 2.8 : 4.2,
              ),
              itemBuilder: (context, index) {
                final tile = tiles[index];
                return AppHubTile(
                  title: tile.title,
                  icon: tile.icon,
                  onTap: () => context.go(tile.path),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeading(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.highlight,
          ),
    );
  }
}

class _HubTileData {
  const _HubTileData({
    required this.title,
    required this.icon,
    required this.path,
  });

  final String title;
  final IconData icon;
  final String path;
}

class _StatItem {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.isDesktop,
    required this.items,
  });

  final bool isDesktop;
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _StatCard(item: items[i])),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < items.length
                        ? _StatCard(item: items[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _StatCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
