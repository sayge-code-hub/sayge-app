import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

class CafeMenuPage extends StatefulWidget {
  const CafeMenuPage({super.key, required this.clientId});

  final String clientId;

  @override
  State<CafeMenuPage> createState() => _CafeMenuPageState();
}

class _CafeMenuPageState extends State<CafeMenuPage> {
  List<CafeCategory> _categories = const [];
  List<CafeMenuItem> _items = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

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
    final cats = await sl<GetCafeCategories>()(widget.clientId);
    final items = await sl<GetCafeMenuItems>()(widget.clientId);
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

  Future<void> _addCategory() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: AppTextField(label: 'Name', controller: name, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Add',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final result = await sl<UpsertCafeCategory>()(
      CafeCategory(
        id: '',
        clientId: widget.clientId,
        name: name.text.trim(),
        sortOrder: _categories.length,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Menu', message: f.message),
      (_) => _reload(),
    );
  }

  Future<void> _editItem([CafeMenuItem? existing]) async {
    if (_categories.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Menu',
        message: 'Add a category first.',
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final price = TextEditingController(
      text: existing == null ? '' : existing.price.toStringAsFixed(2),
    );
    final tax = TextEditingController(
      text: existing == null ? '0' : existing.taxRate.toStringAsFixed(0),
    );
    var categoryId = existing?.categoryId ?? _categories.first.id;
    var available = existing?.isAvailable ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New item' : 'Edit item'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Name', controller: name),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final c in _categories)
                      if (c.isActive)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => categoryId = v);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Price',
                  controller: price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Tax %',
                  controller: tax,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  value: available,
                  onChanged: (v) => setLocal(() => available = v),
                ),
              ],
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
    final p = double.tryParse(price.text.trim()) ?? -1;
    if (name.text.trim().isEmpty || p < 0) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Menu',
        message: 'Name and a valid price are required.',
      );
      return;
    }
    final result = await sl<UpsertCafeMenuItem>()(
      CafeMenuItem(
        id: existing?.id ?? '',
        clientId: widget.clientId,
        categoryId: categoryId,
        name: name.text.trim(),
        price: p,
        taxRate: double.tryParse(tax.text.trim()) ?? 0,
        isAvailable: available,
        isActive: true,
        sortOrder: existing?.sortOrder ?? _items.length,
      ),
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Menu', message: f.message),
      (_) => _reload(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.clientId)) {
      return const Center(child: Text('Menu management is not allowed.'));
    }
    final isDesktop = Breakpoints.isDesktop(context);
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              AppButton(label: 'Retry', expand: false, onPressed: _reload),
            ],
          ),
        ),
      );
    }

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _items
        : _items
            .where(
              (i) =>
                  i.name.toLowerCase().contains(q) ||
                  i.categoryName.toLowerCase().contains(q),
            )
            .toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            12,
            isDesktop ? 32 : 16,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppListSearchField(
                  hintText: 'Search menu…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add category',
                onPressed: _addCategory,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                tooltip: 'Add item',
                onPressed: () => _editItem(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (_categories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
              children: [
                for (final c in _categories.where((c) => c.isActive))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(label: Text(c.name)),
                  ),
              ],
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No menu items yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    12,
                    isDesktop ? 32 : 16,
                    24,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return AppListCard(
                      onTap: () => _editItem(item),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    item.categoryName,
                                    if (!item.isAvailable) 'Unavailable',
                                  ].where((e) => e.isNotEmpty).join(' · '),
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
                            MoneyFormat.format(item.price),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
