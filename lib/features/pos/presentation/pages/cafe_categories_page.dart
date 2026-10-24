import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_catalog.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Manage cafe menu categories — add, rename, remove.
class CafeCategoriesPage extends StatefulWidget {
  const CafeCategoriesPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeCategoriesPage> createState() => _CafeCategoriesPageState();
}

class _CafeCategoriesPageState extends State<CafeCategoriesPage> {
  List<CafeCategory> _categories = const [];
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
    final result = await sl<GetCafeCategories>()(widget.cafeId);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _categories = list.where((c) => c.isActive).toList();
        _loading = false;
      }),
    );
  }

  Future<void> _upsert([CafeCategory? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(existing == null ? 'New category' : 'Edit category'),
        content: AppTextField(
          label: 'Name',
          controller: name,
          autofocus: true,
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
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final result = await sl<UpsertCafeCategory>()(
      CafeCategory(
        id: existing?.id ?? '',
        cafeId: widget.cafeId,
        name: name.text.trim(),
        sortOrder: existing?.sortOrder ?? _categories.length,
        isActive: true,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) =>
          showAppMessageDialog(context, title: 'Categories', message: f.message),
      (_) => _reload(),
    );
  }

  Future<void> _delete(CafeCategory category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Remove “${category.name}”?'),
        content: const Text(
          'Items keep their data but this category is removed from filters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Remove',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final result = await sl<DeleteCafeCategory>()(category.id);
    if (!mounted) return;
    result.fold(
      (f) =>
          showAppMessageDialog(context, title: 'Categories', message: f.message),
      (_) => _reload(),
    );
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
          title: 'Couldn’t load categories',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    return CafePosBackdrop(
      child: Column(
        children: [
          Expanded(
            child: _categories.isEmpty
                ? const CafePosEmptyState(
                    icon: Icons.category_outlined,
                    title: 'No categories',
                    message: 'Add categories to organize your menu.',
                  )
                : ListView(
                    padding: CafePosSpace.page(context),
                    children: [
                      CafePosPageHeader(
                        title: 'Categories',
                        subtitle: 'Edit names or remove unused ones',
                      ),
                      const SizedBox(height: 16),
                      for (final c in _categories) ...[
                        Material(
                          color: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CafePosSpace.radius),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _upsert(c),
                                  icon: Icon(
                                    Icons.edit_rounded,
                                    size: 20,
                                    color: AppColors.highlight,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
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
            label: 'Add category',
            onPressed: () => _upsert(),
          ),
        ],
      ),
    );
  }
}
