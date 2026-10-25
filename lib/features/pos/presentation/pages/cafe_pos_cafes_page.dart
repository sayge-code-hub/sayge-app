import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/app_storage_urls.dart';
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
                child: Align(alignment: Alignment.centerRight, child: addCafe),
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
                if (!stickyBottom)
                  SliverPadding(
                    padding: CafePosSpace.page(context).copyWith(bottom: 8),
                    sliver: SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: addCafe,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    CafePosSpace.page(context).left,
                    stickyBottom ? CafePosSpace.page(context).top : 8,
                    CafePosSpace.page(context).right,
                    stickyBottom ? 16 : 24,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.crossAxisExtent;
                      final cross = w >= 1100
                          ? 4
                          : w >= 780
                              ? 3
                              : w >= 480
                                  ? 2
                                  : 1;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cross,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 116,
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

  String? get _logoUrl {
    final path = cafe.guestLogoPath.trim();
    if (path.isEmpty || !cafe.guestShowLogo) return null;
    return AppStorageUrls.publicUrl(
      Supabase.instance.client,
      bucket: 'brand-logos',
      path: path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final started = cafe.createdAt;
    final meta = <String>[
      if (started != null) 'Started ${AppDates.medium.format(started)}',
      '${cafe.tableCount} tables',
      if (cafe.showGstOnBill) cafe.gstLabel,
    ];

    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              CafePosLogoMark(
                name: cafe.name,
                logoUrl: _logoUrl,
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cafe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            height: 1.2,
                            color: AppColors.text,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11.5,
                            height: 1.3,
                            color: AppColors.textLight,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.highlight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cafe.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.highlight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textLight.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
