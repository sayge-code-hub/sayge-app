import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Full-screen add / edit for a cafe menu item.
class CafeMenuItemPage extends StatefulWidget {
  const CafeMenuItemPage({
    super.key,
    required this.cafeId,
    this.itemId,
  });

  final String cafeId;
  final String? itemId;

  bool get isEditing => itemId != null && itemId!.isNotEmpty;

  @override
  State<CafeMenuItemPage> createState() => _CafeMenuItemPageState();
}

class _CafeMenuItemPageState extends State<CafeMenuItemPage> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _tax = TextEditingController(text: '0');
  List<CafeCategory> _categories = const [];
  String? _categoryId;
  bool _available = true;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  CafeMenuItem? _existing;

  String _baselineName = '';
  String _baselinePrice = '';
  String _baselineTax = '0';
  String? _baselineCategoryId;
  bool _baselineAvailable = true;

  @override
  void initState() {
    super.initState();
    _name.addListener(_markDirty);
    _price.addListener(_markDirty);
    _tax.addListener(_markDirty);
    _load();
  }

  @override
  void dispose() {
    _name.removeListener(_markDirty);
    _price.removeListener(_markDirty);
    _tax.removeListener(_markDirty);
    _name.dispose();
    _price.dispose();
    _tax.dispose();
    super.dispose();
  }

  void _markDirty() {
    final dirty = _name.text != _baselineName ||
        _price.text != _baselinePrice ||
        _tax.text != _baselineTax ||
        _categoryId != _baselineCategoryId ||
        _available != _baselineAvailable;
    if (dirty != _dirty) setState(() => _dirty = dirty);
  }

  void _captureBaseline() {
    _baselineName = _name.text;
    _baselinePrice = _price.text;
    _baselineTax = _tax.text;
    _baselineCategoryId = _categoryId;
    _baselineAvailable = _available;
    _dirty = false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final cats = await sl<GetCafeCategories>()(widget.cafeId);
    if (!mounted) return;
    await cats.fold(
      (f) async => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) async {
        final active = list.where((c) => c.isActive).toList();
        _categories = active;
        if (!widget.isEditing) {
          setState(() {
            _categoryId = active.isNotEmpty ? active.first.id : null;
            _loading = false;
          });
          _captureBaseline();
          return;
        }
        final items = await sl<GetCafeMenuItems>()(widget.cafeId);
        if (!mounted) return;
        items.fold(
          (f) => setState(() {
            _loading = false;
            _error = f.message;
          }),
          (menu) {
            CafeMenuItem? found;
            for (final i in menu) {
              if (i.id == widget.itemId) {
                found = i;
                break;
              }
            }
            if (found == null) {
              setState(() {
                _loading = false;
                _error = 'Item not found.';
              });
              return;
            }
            _existing = found;
            _name.text = found.name;
            _price.text = found.price.toStringAsFixed(2);
            _tax.text = found.taxRate.toStringAsFixed(0);
            _available = found.isAvailable;
            _categoryId = found.categoryId;
            if (!_categories.any((c) => c.id == _categoryId) &&
                _categories.isNotEmpty) {
              _categoryId = _categories.first.id;
            }
            setState(() => _loading = false);
            _captureBaseline();
          },
        );
      },
    );
  }

  Future<void> _leave() async {
    void go() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.posMenu(widget.cafeId));
      }
    }

    if (!_dirty) {
      go();
      return;
    }
    await leaveFormIfConfirmed(context, go);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_categories.isEmpty || _categoryId == null) {
      await showAppMessageDialog(
        context,
        title: 'Menu',
        message: 'Add a category first.',
      );
      return;
    }
    final p = double.tryParse(_price.text.trim()) ?? -1;
    if (_name.text.trim().isEmpty || p < 0) {
      await showAppMessageDialog(
        context,
        title: 'Menu',
        message: 'Name and a valid price are required.',
      );
      return;
    }
    setState(() => _saving = true);
    final result = await sl<UpsertCafeMenuItem>()(
      CafeMenuItem(
        id: _existing?.id ?? '',
        cafeId: widget.cafeId,
        categoryId: _categoryId!,
        name: _name.text.trim(),
        price: p,
        taxRate: double.tryParse(_tax.text.trim()) ?? 0,
        isAvailable: _available,
        isActive: true,
        sortOrder: _existing?.sortOrder ?? 0,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Menu', message: f.message),
      (_) {
        _dirty = false;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.posMenu(widget.cafeId));
        }
      },
    );
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Remove “${existing.name}”?'),
        content: const Text('This item will be removed from the menu.'),
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
    final result = await sl<DeleteCafeMenuItem>()(existing.id);
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Menu', message: f.message),
      (_) {
        _dirty = false;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.posMenu(widget.cafeId));
        }
      },
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
          title: 'Couldn’t load item',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _load),
        ),
      );
    }

    return CafePosBackdrop(
      child: Column(
        children: [
          if (widget.isEditing)
            Padding(
              padding: CafePosSpace.page(context).copyWith(bottom: 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Delete',
                  onPressed: _delete,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: CafePosSpace.page(context),
              children: [
                AppTextField(
                  label: 'Name',
                  controller: _name,
                  autofocus: !widget.isEditing,
                ),
                const SizedBox(height: 14),
                if (_categories.isEmpty)
                  Text(
                    'No categories yet. Add one from Categories.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                  )
                else
                  AppDropdown<String>(
                    label: 'Category',
                    items: [for (final c in _categories) c.id],
                    itemLabel: (id) {
                      for (final c in _categories) {
                        if (c.id == id) return c.name;
                      }
                      return id;
                    },
                    value: _categoryId,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _categoryId = v);
                      _markDirty();
                    },
                  ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Price',
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Tax %',
                  controller: _tax,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available'),
                  value: _available,
                  onChanged: (v) {
                    setState(() => _available = v);
                    _markDirty();
                  },
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.background,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _leave,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        label: _saving ? 'Saving…' : 'Save',
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
