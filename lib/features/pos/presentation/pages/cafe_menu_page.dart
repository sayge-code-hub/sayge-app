import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_catalog.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafeMenuPage extends StatefulWidget {
  const CafeMenuPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeMenuPage> createState() => _CafeMenuPageState();
}

class _CafeMenuPageState extends State<CafeMenuPage> {
  List<CafeCategory> _categories = const [];
  List<CafeMenuItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CafeMenuPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cats = await sl<GetCafeCategories>()(widget.cafeId);
    final items = await sl<GetCafeMenuItems>()(widget.cafeId);
    if (!mounted) return;
    cats.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) {
        items.fold(
          (f) => setState(() {
            _loading = false;
            _error = f.message;
          }),
          (menu) => setState(() {
            _categories = list;
            _items = menu;
            _loading = false;
          }),
        );
      },
    );
  }

  List<CafeCategory> get _activeCats =>
      _categories.where((c) => c.isActive).toList(growable: false);

  List<CafeMenuItem> get _visible {
    var list = _items.where((i) => i.isActive).toList();
    if (_categoryFilter != null) {
      list = list.where((i) => i.categoryId == _categoryFilter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (i) =>
                i.name.toLowerCase().contains(q) ||
                i.categoryName.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  Future<void> _openEdit([CafeMenuItem? item]) async {
    final path = item == null
        ? AppRoutes.posMenuAdd(widget.cafeId)
        : AppRoutes.posMenuEdit(widget.cafeId, item.id);
    await context.push(path);
    if (mounted) _reload();
  }

  Future<void> _openCategories() async {
    await context.push(AppRoutes.posCategories(widget.cafeId));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Menu management is not allowed.')),
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
          title: 'Couldn’t load menu',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    final visible = _visible;
    final hasItems = _items.where((i) => i.isActive).isNotEmpty;

    return CafePosBackdrop(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: CafePosSpace.page(context).copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CafePosCategoryBar(
                    categories: _activeCats,
                    selectedId: _categoryFilter,
                    onSelected: (id) =>
                        setState(() => _categoryFilter = id),
                  ),
                  const SizedBox(height: 12),
                  AppListSearchField(
                    hintText: 'Search menu items…',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: CafePosProductGrid(
                      items: visible,
                      mode: CafePosProductCardMode.edit,
                      onItemTap: _openEdit,
                      showUnavailable: true,
                      empty: CafePosEmptyState(
                        icon: Icons.restaurant_menu_outlined,
                        title: hasItems ? 'No matches' : 'No menu yet',
                        message: hasItems
                            ? 'Try another search or category.'
                            : 'Add a category, then create your first item.',
                        action: !hasItems
                            ? AppButton(
                                label: 'Categories',
                                expand: false,
                                onPressed: _openCategories,
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CafePosStickyAction(
            label: 'Add item',
            onPressed: () => _openEdit(),
          ),
        ],
      ),
    );
  }
}
