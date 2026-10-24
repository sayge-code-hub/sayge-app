import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/app_storage_urls.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../guest/guest_menu_theme.dart';
import '../widgets/cafe_pos_chrome.dart';

/// Configure how guests see the QR menu: layout, accent, logo, tagline.
class CafeGuestBrandSettingsPage extends StatefulWidget {
  const CafeGuestBrandSettingsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeGuestBrandSettingsPage> createState() =>
      _CafeGuestBrandSettingsPageState();
}

class _CafeGuestBrandSettingsPageState
    extends State<CafeGuestBrandSettingsPage> {
  Cafe? _cafe;
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  late final TextEditingController _tagline;
  late final TextEditingController _accentHex;
  GuestMenuLayout _layout = GuestMenuLayout.night;
  bool _showLogo = true;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tagline = TextEditingController();
    _accentHex = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _tagline.dispose();
    _accentHex.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
      (cafes) {
        Cafe? found;
        for (final c in cafes) {
          if (c.id == widget.cafeId) {
            found = c;
            break;
          }
        }
        if (found == null) {
          setState(() {
            _loading = false;
            _error = 'Cafe not found.';
          });
          return;
        }
        _tagline.text = found.guestTagline;
        _accentHex.text = found.guestAccentHex;
        setState(() {
          _cafe = found;
          _layout = found!.guestLayout;
          _showLogo = found.guestShowLogo;
          _showSearch = found.guestShowSearch;
          _loading = false;
        });
      },
    );
  }

  String? get _logoUrl {
    final path = _cafe?.guestLogoPath.trim() ?? '';
    if (path.isEmpty) return null;
    return AppStorageUrls.publicUrl(
      Supabase.instance.client,
      bucket: 'brand-logos',
      path: path,
    );
  }

  Future<void> _save() async {
    final cafe = _cafe;
    if (cafe == null || _saving) return;
    final hex = _accentHex.text.trim();
    if (hex.isNotEmpty && GuestMenuTheme.parseAccentHex(hex) == null) {
      await showAppMessageDialog(
        context,
        title: 'Accent color',
        message: 'Use a hex like #1B7A4E or leave blank for the default.',
      );
      return;
    }
    setState(() => _saving = true);
    final result = await sl<UpsertCafe>()(
      cafe.copyWith(
        guestTagline: _tagline.text.trim(),
        guestAccentHex: hex.startsWith('#') || hex.isEmpty ? hex : '#$hex',
        guestLayout: _layout,
        guestShowLogo: _showLogo,
        guestShowSearch: _showSearch,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => showAppMessageDialog(
        context,
        title: 'Guest menu look',
        message: f.message,
      ),
      (saved) {
        setState(() => _cafe = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest menu look saved')),
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    if (_uploading) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    final result = await sl<UploadCafeGuestLogo>()(
      cafeId: widget.cafeId,
      bytes: bytes,
      fileName: file.name,
      mimeType: file.extension == 'png'
          ? 'image/png'
          : file.extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg',
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    result.fold(
      (f) => showAppMessageDialog(
        context,
        title: 'Logo',
        message: f.message,
      ),
      (saved) {
        setState(() {
          _cafe = saved;
          _showLogo = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded')),
        );
      },
    );
  }

  Future<void> _removeLogo() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final result = await sl<ClearCafeGuestLogo>()(widget.cafeId);
    if (!mounted) return;
    setState(() => _uploading = false);
    result.fold(
      (f) => showAppMessageDialog(
        context,
        title: 'Logo',
        message: f.message,
      ),
      (saved) => setState(() => _cafe = saved),
    );
  }

  Future<void> _preview() async {
    final origin = AppConfig.appPublicUrl;
    if (origin.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Preview',
        message: 'Set APP_PUBLIC_URL so the guest menu link can open.',
      );
      return;
    }
    final uri = Uri.parse(
      '$origin${AppRoutes.guestMenuCafe(widget.cafeId)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Guest menu settings access denied.')),
      );
    }
    if (_loading) {
      return const CafePosBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }
    if (_error != null || _cafe == null) {
      return CafePosBackdrop(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Something went wrong.'),
                const SizedBox(height: 16),
                AppButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }

    final logoUrl = _logoUrl;
    final previewAccent =
        GuestMenuTheme.parseAccentHex(_accentHex.text) ?? AppColors.highlight;

    return CafePosBackdrop(
      child: ListView(
        padding: CafePosSpace.page(context),
        children: [
          Text(
            'How guests see your QR menu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick a layout, brand color, and logo. Changes apply the next '
            'time someone opens the menu.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 22),
          Text(
            'Layout',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          ...GuestMenuLayout.values.map((layout) {
            final selected = _layout == layout;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: selected
                    ? previewAccent.withValues(alpha: 0.1)
                    : AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CafePosSpace.radius),
                  side: BorderSide(
                    color: selected ? previewAccent : AppColors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _layout = layout),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Row(
                      children: [
                        _LayoutThumb(layout: layout, accent: previewAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                layout.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                layout.blurb,
                                style: TextStyle(
                                  color: AppColors.textLight.withValues(
                                    alpha: 0.95,
                                  ),
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected
                              ? previewAccent
                              : AppColors.textLight.withValues(alpha: 0.5),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
          Text(
            'Accent color',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in GuestMenuTheme.accentPresets)
                _AccentChip(
                  label: preset.$1,
                  hex: preset.$2,
                  selected: _accentHex.text.trim().toUpperCase() ==
                          preset.$2.toUpperCase() ||
                      (_accentHex.text.trim().isEmpty &&
                          preset.$2 == '#FF6B4A' &&
                          (_cafe?.guestAccentHex.isEmpty ?? true)),
                  onTap: () => setState(() => _accentHex.text = preset.$2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _accentHex,
            label: 'Custom hex (optional)',
            hintText: '#1B7A4E',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text(
            'Logo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(CafePosSpace.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0EE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoUrl == null
                      ? Icon(
                          Icons.storefront_rounded,
                          color: previewAccent,
                          size: 28,
                        )
                      : Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textLight,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Show logo on menu',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        value: _showLogo,
                        activeThumbColor: previewAccent,
                        onChanged: (v) => setState(() => _showLogo = v),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _uploading ? null : _pickLogo,
                            child: Text(
                              logoUrl == null ? 'Upload logo' : 'Replace',
                            ),
                          ),
                          if (logoUrl != null)
                            TextButton(
                              onPressed: _uploading ? null : _removeLogo,
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _tagline,
            label: 'Tagline',
            hintText: 'What are you craving?',
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show search on menu',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Guests can filter items by name',
              style: TextStyle(
                color: AppColors.textLight.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            value: _showSearch,
            activeThumbColor: previewAccent,
            onChanged: (v) => setState(() => _showSearch = v),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: _saving ? 'Saving…' : 'Save look',
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Preview guest menu'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CafePosSpace.radius),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.push(AppRoutes.posQr(widget.cafeId)),
            child: const Text('Print / download QR codes'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _LayoutThumb extends StatelessWidget {
  const _LayoutThumb({required this.layout, required this.accent});

  final GuestMenuLayout layout;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        color: switch (layout) {
          GuestMenuLayout.night => const Color(0xFF1A1714),
          GuestMenuLayout.fresh => const Color(0xFFF7F7F5),
          GuestMenuLayout.gallery => const Color(0xFFF0EEEA),
        },
      ),
      padding: const EdgeInsets.all(6),
      child: switch (layout) {
        GuestMenuLayout.night => Column(
            children: [
              Container(
                height: 18,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        GuestMenuLayout.fresh => Column(
            children: [
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(right: i < 2 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? accent
                            : accent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E2DE),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        GuestMenuLayout.gallery => Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      },
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({
    required this.label,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = GuestMenuTheme.parseAccentHex(hex) ?? AppColors.highlight;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.background,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
