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
import '../widgets/cafe_pos_chrome.dart';

/// Configure how guests see the QR menu: cafe name + logo.
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

  late final TextEditingController _name;
  bool _showLogo = true;
  bool _showSearch = true;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
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
        _name.text = found.name;
        setState(() {
          _cafe = found;
          _showLogo = found!.guestShowLogo;
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
    final name = _name.text.trim();
    if (name.isEmpty) {
      await showAppMessageDialog(
        context,
        title: 'Cafe name',
        message: 'Add a cafe name so guests know where they are ordering.',
      );
      return;
    }
    setState(() => _saving = true);
    final result = await sl<UpsertCafe>()(
      cafe.copyWith(
        name: name,
        guestTagline: '',
        guestAccentHex: '',
        guestLayout: GuestMenuLayout.detailed,
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
          const SizedBox(height: 22),
          AppTextField(
            controller: _name,
            label: 'Cafe name',
            hintText: 'e.g. Sayge Demo Cafe',
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
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(CafePosSpace.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F3F1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: logoUrl == null
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.textLight,
                          size: 36,
                        )
                      : Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textLight,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  logoUrl == null ? 'No logo yet' : 'Current logo',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shown on the guest menu while it loads',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textLight.withValues(alpha: 0.95),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _uploading ? null : _pickLogo,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(CafePosSpace.radius),
                          ),
                        ),
                        child: Text(
                          _uploading
                              ? 'Uploading…'
                              : logoUrl == null
                                  ? 'Upload logo'
                                  : 'Replace logo',
                        ),
                      ),
                    ),
                    if (logoUrl != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _uploading ? null : _removeLogo,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(CafePosSpace.radius),
                            ),
                          ),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Show logo on menu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  value: _showLogo,
                  activeThumbColor: AppColors.highlight,
                  onChanged: (v) => setState(() => _showLogo = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show search on menu',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            value: _showSearch,
            activeThumbColor: AppColors.highlight,
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
