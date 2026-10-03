import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_brands_bloc.dart';

class PosBrandsPage extends StatelessWidget {
  const PosBrandsPage({
    super.key,
    this.forceHub = false,
  });

  /// Kept for route compatibility; hub always shows brand cards.
  final bool forceHub;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosBrandsBloc>()..add(const PosBrandsStarted()),
      child: const _PosBrandsBody(),
    );
  }
}

class _PosBrandsBody extends StatelessWidget {
  const _PosBrandsBody();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final bloc = context.read<PosBrandsBloc>();

    return BlocConsumer<PosBrandsBloc, PosBrandsState>(
      listenWhen: (prev, next) =>
          (next.successMessage != null &&
              next.successMessage != prev.successMessage) ||
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage),
      listener: (context, state) async {
        final message = state.errorMessage ?? state.successMessage;
        if (message == null) return;
        if (state.errorMessage != null &&
            state.status == PosBrandsStatus.success) {
          return;
        }
        await showAppMessageDialog(
          context,
          title: 'POS',
          message: message,
        );
      },
      builder: (context, state) {
        final busy = state.status == PosBrandsStatus.saving;
        final addBrand = AppButton(
          label: 'Add brand',
          expand: !isDesktop,
          enabled: !busy,
          onPressed: () => context.go(AppRoutes.posBrandAdd),
        );

        if (state.status == PosBrandsStatus.initial ||
            state.status == PosBrandsStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (state.status == PosBrandsStatus.failure && state.brands.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.errorMessage ?? 'Failed to load brands.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Retry',
                    expand: false,
                    onPressed: () => context
                        .read<PosBrandsBloc>()
                        .add(const PosBrandsStarted()),
                  ),
                ],
              ),
            ),
          );
        }

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
                        const Spacer(),
                        addBrand,
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: state.brands.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontal),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No brands yet. Add a brand to start managing products.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textLight),
                            ),
                            if (!isDesktop) ...[
                              const SizedBox(height: 16),
                              addBrand,
                            ],
                          ],
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        0,
                        horizontal,
                        24,
                      ),
                      itemCount: state.brands.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 3 : 1,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isDesktop ? 0.92 : 1.35,
                      ),
                      itemBuilder: (context, index) {
                        final brand = state.brands[index];
                        final logoUrl = brand.logoPath.trim().isEmpty
                            ? ''
                            : bloc.imageUrl(brand.logoPath);
                        return _BrandCard(
                          brand: brand,
                          logoUrl: logoUrl,
                          enabled: !busy,
                          onOpen: () =>
                              context.go(AppRoutes.posBrand(brand.id)),
                          onEdit: () =>
                              context.go(AppRoutes.posBrandEdit(brand.id)),
                          onDelete: () => _confirmDelete(context, brand),
                        );
                      },
                    ),
            ),
            if (!isDesktop && state.brands.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: addBrand,
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, PosBrand brand) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Delete brand'),
        content: Text(
          'Delete "${brand.name}" and all its products? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<PosBrandsBloc>().add(PosBrandDeleted(brand.id));
    }
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.brand,
    required this.logoUrl,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.enabled,
  });

  final PosBrand brand;
  final String logoUrl;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final created = brand.createdAt;
    final createdLabel = created == null
        ? null
        : 'Created ${AppDates.medium.format(created.toLocal())}';

    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onOpen : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: logoUrl.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.storefront_outlined,
                              size: 40,
                              color: AppColors.textLight,
                            ),
                          )
                        : Image.network(
                            logoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: AppColors.background.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        enabled: enabled,
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz, size: 18),
                      ),
                    ),
                  ),
                  if (!brand.isActive)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'Inactive',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        brand.description.trim().isEmpty
                            ? 'No description'
                            : brand.description.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          height: 1.35,
                          color: brand.description.trim().isEmpty
                              ? AppColors.textLight.withValues(alpha: 0.75)
                              : AppColors.textLight,
                        ),
                      ),
                    ),
                    if (createdLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        createdLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
