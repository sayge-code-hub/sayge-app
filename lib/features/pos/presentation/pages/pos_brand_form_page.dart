import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/pos_entities.dart';
import '../bloc/pos_brands_bloc.dart';

class PosBrandFormPage extends StatelessWidget {
  const PosBrandFormPage({
    super.key,
    this.brandId,
  });

  final String? brandId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosBrandsBloc>()..add(const PosBrandsStarted()),
      child: _PosBrandFormBody(brandId: brandId),
    );
  }
}

class _PosBrandFormBody extends StatefulWidget {
  const _PosBrandFormBody({this.brandId});

  final String? brandId;

  @override
  State<_PosBrandFormBody> createState() => _PosBrandFormBodyState();
}

class _PosBrandFormBodyState extends State<_PosBrandFormBody> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _isActive = true;
  bool _hydrated = false;
  String? _existingId;
  String _existingLogoPath = '';
  Uint8List? _logoBytes;
  String? _logoFileName;
  String? _logoMimeType;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _hydrate(PosBrandsState state) {
    if (_hydrated) return;
    final id = widget.brandId?.trim();
    if (id == null || id.isEmpty) {
      _hydrated = true;
      return;
    }
    for (final brand in state.brands) {
      if (brand.id == id) {
        _existingId = brand.id;
        _name.text = brand.name;
        _description.text = brand.description;
        _isActive = brand.isActive;
        _existingLogoPath = brand.logoPath;
        _hydrated = true;
        return;
      }
    }
    if (state.status == PosBrandsStatus.ready) {
      _hydrated = true;
    }
  }

  Future<void> _pickLogo() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || !mounted) return;
    setState(() {
      _logoBytes = bytes;
      _logoFileName = file.name;
      _logoMimeType = _guessMime(file.extension);
    });
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

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppMessageDialog(
        context,
        title: 'POS',
        message: 'Brand name is required.',
      );
      return;
    }
    context.read<PosBrandsBloc>().add(
          PosBrandSubmitted(
            PosBrand(
              id: _existingId ?? '',
              name: name,
              description: _description.text.trim(),
              logoPath: _existingLogoPath,
              isActive: _isActive,
            ),
            logo: _logoBytes == null
                ? null
                : PosImageUpload(
                    fileName: _logoFileName ?? 'logo.jpg',
                    bytes: _logoBytes!,
                    mimeType: _logoMimeType ?? 'image/jpeg',
                  ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;
    final isEdit = (widget.brandId ?? '').trim().isNotEmpty;
    final bloc = context.read<PosBrandsBloc>();

    return BlocConsumer<PosBrandsBloc, PosBrandsState>(
      listenWhen: (prev, next) =>
          next.status == PosBrandsStatus.success ||
          (next.errorMessage != null &&
              next.errorMessage != prev.errorMessage),
      listener: (context, state) async {
        if (state.errorMessage != null &&
            state.status != PosBrandsStatus.success) {
          await showAppMessageDialog(
            context,
            title: 'POS',
            message: state.errorMessage!,
          );
          return;
        }
        if (state.status == PosBrandsStatus.success && context.mounted) {
          await showAppMessageDialog(
            context,
            title: 'POS',
            message: state.successMessage ?? 'Brand saved',
          );
          if (context.mounted) context.go(AppRoutes.posHub);
        }
      },
      builder: (context, state) {
        _hydrate(state);
        final saving = state.status == PosBrandsStatus.saving;
        final existingLogoUrl = _existingLogoPath.trim().isEmpty
            ? ''
            : bloc.imageUrl(_existingLogoPath);

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                children: [
                  Text(
                    'Logo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 96,
                          height: 96,
                          color: AppColors.surfaceMuted,
                          child: _logoBytes != null
                              ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                              : (existingLogoUrl.isEmpty
                                  ? const Icon(
                                      Icons.storefront_outlined,
                                      color: AppColors.textLight,
                                    )
                                  : Image.network(
                                      existingLogoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.textLight,
                                      ),
                                    )),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: saving ? null : _pickLogo,
                            icon: const Icon(Icons.upload_outlined, size: 18),
                            label: Text(
                              _logoBytes != null ||
                                      _existingLogoPath.trim().isNotEmpty
                                  ? 'Change logo'
                                  : 'Upload logo',
                            ),
                          ),
                          if (_logoBytes != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                        _logoBytes = null;
                                        _logoFileName = null;
                                        _logoMimeType = null;
                                      }),
                              child: const Text('Remove new logo'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Brand name',
                    controller: _name,
                    enabled: !saving,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Description',
                    controller: _description,
                    enabled: !saving,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Active',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: _isActive,
                    activeThumbColor: AppColors.background,
                    activeTrackColor: AppColors.highlight,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
            AppStickyActions(
              children: [
                OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => leaveFormIfConfirmed(
                            context,
                            () => context.canPop()
                                ? context.pop()
                                : context.go(AppRoutes.posHub),
                          ),
                  child: const Text('Cancel'),
                ),
                AppButton(
                  label: saving
                      ? 'Saving…'
                      : (isEdit ? 'Update' : 'Save'),
                  expand: true,
                  isLoading: saving,
                  enabled: !saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
