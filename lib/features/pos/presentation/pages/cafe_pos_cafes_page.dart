import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_catalog.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Staff: list/create cafes. Cafe roles redirect to their scoped cafe.
class CafePosCafesPage extends StatefulWidget {
  const CafePosCafesPage({super.key});

  @override
  State<CafePosCafesPage> createState() => _CafePosCafesPageState();
}

class _CafePosCafesPageState extends State<CafePosCafesPage> {
  List<Cafe> _cafes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = sl<AuthSession>().user;
    final scoped = AppAccess.cafeIdOf(user);
    if (user != null && AppAccess.isCafeRole(user) && scoped != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppAccess.homeRoute(user));
      });
      return;
    }
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetCafes>()();
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _cafes = list;
        _loading = false;
      }),
    );
  }

  Future<void> _createCafe() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('New cafe'),
        content: AppTextField(
          label: 'Cafe name',
          controller: name,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Create',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final result = await sl<UpsertCafe>()(
      Cafe(id: '', name: name.text.trim()),
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'POS', message: f.message),
      (cafe) => context.go(AppRoutes.posCafe(cafe.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (user != null && AppAccess.isCafeRole(user)) {
      final scoped = AppAccess.cafeIdOf(user);
      return CafePosBackdrop(
        child: Center(
          child: Text(
            scoped == null
                ? 'Your account is not linked to a cafe.'
                : 'Opening your cafe…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ),
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
          title: 'Couldn’t load cafes',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    final active = _cafes.where((c) => c.isActive).toList(growable: false);
    // Tablet + monitor: toolbar CTA. Mobile: sticky bottom (same as invoices/expenses).
    final stickyBottom = Breakpoints.isCompact(context);
    final addCafe = AppButton(
      label: 'Add cafe',
      expand: stickyBottom,
      onPressed: _createCafe,
    );

    if (active.isEmpty) {
      return CafePosBackdrop(
        child: Column(
          children: [
            if (!stickyBottom)
              Padding(
                padding: CafePosSpace.page(context).copyWith(bottom: 0),
                child: CafePosPageHeader(
                  title: 'Your cafes',
                  subtitle: 'Open a cafe to run menu, terminal, and kitchen.',
                  trailing: addCafe,
                ),
              ),
            const Expanded(
              child: CafePosEmptyState(
                icon: Icons.storefront_outlined,
                title: 'Set up your first cafe',
                message:
                    'Create a cafe to manage menu, take orders, and run the kitchen.',
              ),
            ),
            if (stickyBottom)
              CafePosStickyAction(label: 'Add cafe', onPressed: _createCafe),
          ],
        ),
      );
    }

    return CafePosBackdrop(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: CafePosSpace.page(context).copyWith(bottom: 8),
                  sliver: SliverToBoxAdapter(
                    child: CafePosPageHeader(
                      title: 'Your cafes',
                      subtitle:
                          'Open a cafe to run menu, terminal, and kitchen.',
                      trailing: stickyBottom ? null : addCafe,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    CafePosSpace.page(context).left,
                    8,
                    CafePosSpace.page(context).right,
                    stickyBottom ? 16 : 24,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.crossAxisExtent;
                      final cross = w >= 900
                          ? 4
                          : w >= 600
                              ? 3
                              : Breakpoints.isDesktop(context)
                                  ? 3
                                  : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.05,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cafe = active[index];
                            return _CafeTile(
                              cafe: cafe,
                              onTap: () =>
                                  context.go(AppRoutes.posCafe(cafe.id)),
                            );
                          },
                          childCount: active.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (stickyBottom)
            CafePosStickyAction(label: 'Add cafe', onPressed: _createCafe),
        ],
      ),
    );
  }
}

class _CafeTile extends StatelessWidget {
  const _CafeTile({required this.cafe, required this.onTap});

  final Cafe cafe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CafePosSpace.radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CafePosMonogram(label: cafe.name, size: 48),
              const Spacer(),
              Text(
                cafe.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to open',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
