import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_product_form_bloc.dart';

class PosProductFormPage extends StatelessWidget {
  const PosProductFormPage({
    super.key,
    required this.brandId,
    this.productId,
  });

  final String brandId;
  final String? productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosProductFormBloc>()
        ..add(
          PosProductFormStarted(
            brandId: brandId,
            productId: productId,
          ),
        ),
      child: _PosProductFormBody(
        brandId: brandId,
        productId: productId,
      ),
    );
  }
}

class _AttrDraft {
  _AttrDraft({this.name = '', this.value = ''});
  String name;
  String value;
}

class _AttrField extends StatefulWidget {
  const _AttrField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<_AttrField> createState() => _AttrFieldState();
}

class _AttrFieldState extends State<_AttrField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: widget.label,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
    );
  }
}

class _PosProductFormBody extends StatefulWidget {
  const _PosProductFormBody({
    required this.brandId,
    this.productId,
  });

  final String brandId;
  final String? productId;

  @override
  State<_PosProductFormBody> createState() => _PosProductFormBodyState();
}

class _PosProductFormBodyState extends State<_PosProductFormBody> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController();
  final _labelBrand = TextEditingController();
  final _shortDescription = TextEditingController();
  final _description = TextEditingController();
  final _purchaseCost = TextEditingController();
  final _sellingPrice = TextEditingController();
  final _mrp = TextEditingController();
  final _taxRate = TextEditingController(text: '0');
  final _openingStock = TextEditingController(text: '0');
  final _reorderLevel = TextEditingController(text: '0');
  final _unitsPerPack = TextEditingController(text: '1');
  final _barcode = TextEditingController();

  PosProductType _productType = PosProductType.product;
  bool _priceIncludesTax = true;
  bool _trackInventory = true;
  String _unit = 'Piece';
  bool _isActive = true;
  bool _seeded = false;
  final List<_AttrDraft> _attributes = [];
  final List<_PendingImage> _pendingUploads = [];
  final Set<String> _removedImageIds = {};

  bool get _isEdit => (widget.productId ?? '').trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _category.dispose();
    _labelBrand.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _purchaseCost.dispose();
    _sellingPrice.dispose();
    _mrp.dispose();
    _taxRate.dispose();
    _openingStock.dispose();
    _reorderLevel.dispose();
    _unitsPerPack.dispose();
    _barcode.dispose();
    super.dispose();
  }

  void _seed(PosProduct product) {
    if (_seeded || product.id.isEmpty) return;
    _seeded = true;
    _name.text = product.name;
    _sku.text = product.sku;
    _category.text = product.category;
    _labelBrand.text = product.labelBrand;
    _shortDescription.text = product.shortDescription;
    _description.text = product.description;
    _purchaseCost.text = _num(product.currentPurchaseCost);
    _sellingPrice.text = _num(product.sellingPrice);
    _mrp.text = product.mrp <= 0 ? '' : _num(product.mrp);
    _taxRate.text = _num(product.taxRate);
    _openingStock.text = _num(product.openingStock);
    _reorderLevel.text = _num(product.reorderLevel);
    _unitsPerPack.text = _num(product.unitsPerPack);
    _barcode.text = product.barcode;
    _productType = product.productType;
    _priceIncludesTax = product.priceIncludesTax;
    _trackInventory = product.trackInventory;
    _unit = product.unitOfMeasure.isEmpty ? 'Piece' : product.unitOfMeasure;
    _isActive = product.isActive;
    _attributes
      ..clear()
      ..addAll(
        product.attributes.map(
          (a) => _AttrDraft(name: a.name, value: a.value),
        ),
      );
  }

  String _num(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _pickImages() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final pending = <_PendingImage>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      pending.add(
        _PendingImage(
          bytes: bytes,
          fileName: file.name,
          mimeType: _guessMime(file.extension),
        ),
      );
    }
    if (pending.isEmpty || !mounted) return;
    setState(() => _pendingUploads.addAll(pending));
  }

  String _guessMime(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  void _submit(PosProduct? existing) {
    if (!_formKey.currentState!.validate()) return;
    final selling = double.tryParse(_sellingPrice.text.trim());
    if (selling == null) {
      showAppMessageDialog(
        context,
        title: 'POS',
        message: 'Enter a valid selling price.',
      );
      return;
    }

    final isService = _productType == PosProductType.service;
    final track = isService ? false : _trackInventory;

    final kept = (existing?.images ?? [])
        .where((img) => !_removedImageIds.contains(img.id))
        .map(
          (img) => PosImageUpload(
            fileName: img.fileName,
            bytes: const [],
            existingPath: img.storagePath,
            existingId: img.id,
          ),
        )
        .toList();
    final uploads = [
      ...kept,
      ..._pendingUploads.map(
        (e) => PosImageUpload(
          fileName: e.fileName,
          bytes: e.bytes,
          mimeType: e.mimeType,
        ),
      ),
    ];

    final attrs = <PosProductAttribute>[];
    for (final draft in _attributes) {
      final name = draft.name.trim();
      final value = draft.value.trim();
      if (name.isEmpty || value.isEmpty) continue;
      attrs.add(
        PosProductAttribute(
          id: '',
          productId: existing?.id ?? '',
          name: name,
          value: value,
        ),
      );
    }

    context.read<PosProductFormBloc>().add(
          PosProductFormSubmitted(
            product: PosProduct(
              id: existing?.id ?? widget.productId ?? '',
              brandId: widget.brandId,
              name: _name.text.trim(),
              sku: _sku.text.trim(),
              category: _category.text.trim(),
              labelBrand: _labelBrand.text.trim(),
              productType: _productType,
              shortDescription: _shortDescription.text.trim(),
              description: _description.text.trim(),
              currentPurchaseCost:
                  double.tryParse(_purchaseCost.text.trim()) ?? 0,
              sellingPrice: selling,
              mrp: double.tryParse(_mrp.text.trim()) ?? 0,
              taxRate: double.tryParse(_taxRate.text.trim()) ?? 0,
              priceIncludesTax: _priceIncludesTax,
              trackInventory: track,
              unitOfMeasure: isService ? 'Service' : _unit,
              openingStock: double.tryParse(_openingStock.text.trim()) ?? 0,
              reorderLevel: double.tryParse(_reorderLevel.text.trim()) ?? 0,
              unitsPerPack: double.tryParse(_unitsPerPack.text.trim()) ?? 1,
              stockOnHand: existing?.stockOnHand ??
                  (double.tryParse(_openingStock.text.trim()) ?? 0),
              barcode: _barcode.text.trim(),
              isActive: _isActive,
              images: existing?.images ?? const [],
              attributes: existing?.attributes ?? const [],
            ),
            images: uploads,
            attributes: attrs,
          ),
        );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 12));
      spaced.add(children[i]);
    }

    return Container(
      width: double.infinity,
      padding: AppListCard.sectionPadding,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.highlight,
                ),
          ),
          const SizedBox(height: 16),
          ...spaced,
        ],
      ),
    );
  }

  Widget _sectionRow({
    required bool isDesktop,
    required Widget left,
    Widget? right,
  }) {
    if (!isDesktop || right == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          if (right != null) ...[
            const SizedBox(height: 12),
            right,
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final bloc = context.read<PosProductFormBloc>();
    final isService = _productType == PosProductType.service;
    final showInventory = !isService && _trackInventory;

    return BlocConsumer<PosProductFormBloc, PosProductFormState>(
      listenWhen: (prev, next) =>
          (next.successMessage != null &&
              next.successMessage != prev.successMessage) ||
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage),
      listener: (context, state) async {
        if (state.errorMessage != null) {
          await showAppMessageDialog(
            context,
            title: 'POS',
            message: state.errorMessage!,
          );
          return;
        }
        if (state.successMessage != null) {
          await showAppMessageDialog(
            context,
            title: 'POS',
            message: state.successMessage!,
          );
          if (!context.mounted) return;
          final id = state.product?.id;
          if (id != null && id.isNotEmpty) {
            context.go(AppRoutes.posProductDetail(widget.brandId, id));
          } else {
            context.go(AppRoutes.posProducts(widget.brandId));
          }
        }
      },
      builder: (context, state) {
        if (state.status == PosProductFormStatus.initial ||
            state.status == PosProductFormStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }
        if (state.product != null) _seed(state.product!);

        final busy = state.status == PosProductFormStatus.saving;
        final existingImages = (state.product?.images ?? [])
            .where((img) => !_removedImageIds.contains(img.id))
            .toList();

        final cancel = OutlinedButton(
          onPressed: busy
              ? null
              : () => leaveFormIfConfirmed(context, () {
                    if (_isEdit) {
                      context.go(
                        AppRoutes.posProductDetail(
                          widget.brandId,
                          widget.productId!,
                        ),
                      );
                    } else {
                      context.go(AppRoutes.posProducts(widget.brandId));
                    }
                  }),
          child: const Text('Cancel'),
        );
        final save = AppButton(
          label: busy ? 'Saving…' : (_isEdit ? 'Update' : 'Save'),
          expand: !isDesktop,
          isLoading: busy,
          enabled: !busy,
          onPressed: () => _submit(state.product),
        );

        final basicCard = _sectionCard(
          title: 'Basic Information',
          children: [
            AppTextField(
              controller: _name,
              label: 'Product name *',
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppTextField(
              controller: _sku,
              label: 'SKU / Product code *',
              enabled: !busy,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppTextField(
              controller: _category,
              label: 'Category *',
              enabled: !busy,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppTextField(
              controller: _labelBrand,
              label: 'Brand',
              enabled: !busy,
            ),
            AppDropdown<PosProductType>(
              label: 'Product type *',
              value: _productType,
              items: PosProductType.values,
              itemLabel: (t) =>
                  t == PosProductType.service ? 'Service' : 'Product',
              enabled: !busy,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _productType = v;
                  if (v == PosProductType.service) {
                    _trackInventory = false;
                    _unit = 'Service';
                  }
                });
              },
            ),
            AppTextField(
              controller: _shortDescription,
              label: 'Short description',
              enabled: !busy,
              maxLines: 2,
            ),
          ],
        );

        final pricingCard = _sectionCard(
          title: 'Pricing',
          children: [
            AppTextField(
              controller: _purchaseCost,
              label: 'Purchase cost / current cost',
              enabled: !busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            AppTextField(
              controller: _sellingPrice,
              label: 'Selling price *',
              enabled: !busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppTextField(
              controller: _mrp,
              label: 'MRP',
              enabled: !busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            AppTextField(
              controller: _taxRate,
              label: 'Tax rate (%)',
              enabled: !busy,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Price includes tax',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _priceIncludesTax,
              activeThumbColor: AppColors.background,
              activeTrackColor: AppColors.highlight,
              onChanged:
                  busy ? null : (v) => setState(() => _priceIncludesTax = v),
            ),
          ],
        );

        final inventoryCard = _sectionCard(
          title: 'Inventory',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Track inventory',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _trackInventory,
              activeThumbColor: AppColors.background,
              activeTrackColor: AppColors.highlight,
              onChanged:
                  busy ? null : (v) => setState(() => _trackInventory = v),
            ),
            AppDropdown<String>(
              label: 'Unit of measure *',
              value: PosUnits.values.contains(_unit) ? _unit : 'Other',
              items: PosUnits.values,
              itemLabel: (u) => u,
              enabled: !busy,
              onChanged: (v) {
                if (v != null) setState(() => _unit = v);
              },
            ),
            if (showInventory) ...[
              AppTextField(
                controller: _openingStock,
                label: 'Opening stock',
                enabled: !busy && !_isEdit,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              AppTextField(
                controller: _reorderLevel,
                label: 'Reorder level',
                enabled: !busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              AppTextField(
                controller: _unitsPerPack,
                label: 'Units per pack',
                enabled: !busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        );

        final attributesCard = _sectionCard(
          title: 'Attributes',
          children: [
            ...List.generate(_attributes.length, (i) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AttrField(
                      key: ValueKey(
                        'attr-name-$i-${_attributes[i].hashCode}',
                      ),
                      label: 'Attribute name',
                      initial: _attributes[i].name,
                      enabled: !busy,
                      onChanged: (v) => _attributes[i].name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AttrField(
                      key: ValueKey(
                        'attr-value-$i-${_attributes[i].hashCode}',
                      ),
                      label: 'Value',
                      initial: _attributes[i].value,
                      enabled: !busy,
                      onChanged: (v) => _attributes[i].value = v,
                    ),
                  ),
                  IconButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _attributes.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ],
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() => _attributes.add(_AttrDraft())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add attribute'),
              ),
            ),
          ],
        );

        final descriptionCard = _sectionCard(
          title: 'Description',
          children: [
            AppTextField(
              controller: _description,
              label: 'Description',
              enabled: !busy,
              maxLines: 6,
            ),
          ],
        );

        final mediaCard = _sectionCard(
          title: 'Media & status',
          children: [
            AppTextField(
              controller: _barcode,
              label: 'Barcode',
              enabled: !busy,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Active',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _isActive,
              activeThumbColor: AppColors.background,
              activeTrackColor: AppColors.highlight,
              onChanged: busy ? null : (v) => setState(() => _isActive = v),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...existingImages.map((img) {
                  final url = bloc.imageUrl(img.storagePath);
                  return _ImageThumb(
                    url: url,
                    onRemove: busy
                        ? null
                        : () => setState(() => _removedImageIds.add(img.id)),
                  );
                }),
                ..._pendingUploads.asMap().entries.map((entry) {
                  return _ImageThumb(
                    bytes: entry.value.bytes,
                    onRemove: busy
                        ? null
                        : () => setState(
                              () => _pendingUploads.removeAt(entry.key),
                            ),
                  );
                }),
                InkWell(
                  onTap: busy ? null : _pickImages,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surfaceMuted,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    isDesktop ? 8 : 12,
                    horizontal,
                    24,
                  ),
                  children: [
                    _sectionRow(
                      isDesktop: isDesktop,
                      left: basicCard,
                      right: pricingCard,
                    ),
                    const SizedBox(height: 12),
                    if (!isService) ...[
                      _sectionRow(
                        isDesktop: isDesktop,
                        left: inventoryCard,
                        right: attributesCard,
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      attributesCard,
                      const SizedBox(height: 12),
                    ],
                    _sectionRow(
                      isDesktop: isDesktop,
                      left: descriptionCard,
                      right: mediaCard,
                    ),
                  ],
                ),
              ),
            ),
            AppStickyActions(children: [cancel, save]),
          ],
        );
      },
    );
  }
}

class _PendingImage {
  const _PendingImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({this.url, this.bytes, this.onRemove});
  final String? url;
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 88,
            height: 88,
            color: AppColors.surfaceMuted,
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.cover)
                : (url == null || url!.isEmpty)
                    ? const Icon(Icons.image_outlined,
                        color: AppColors.textLight)
                    : Image.network(
                        url!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textLight,
                        ),
                      ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
