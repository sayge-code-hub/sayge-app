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
import '../widgets/cafe_pos_chrome.dart';

/// GST / tax display options for the cafe terminal bill.
class CafeTaxSettingsPage extends StatefulWidget {
  const CafeTaxSettingsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeTaxSettingsPage> createState() => _CafeTaxSettingsPageState();
}

class _CafeTaxSettingsPageState extends State<CafeTaxSettingsPage> {
  Cafe? _cafe;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final TextEditingController _gstLabel;

  @override
  void initState() {
    super.initState();
    _gstLabel = TextEditingController(text: 'GST');
    _load();
  }

  @override
  void dispose() {
    _gstLabel.dispose();
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
        _gstLabel.text = found.gstLabel;
        setState(() {
          _cafe = found;
          _loading = false;
        });
      },
    );
  }

  Future<void> _save() async {
    final cafe = _cafe;
    if (cafe == null || _saving) return;
    setState(() => _saving = true);
    final result = await sl<UpsertCafe>()(
      cafe.copyWith(gstLabel: _gstLabel.text.trim()),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => showAppMessageDialog(
        context,
        title: 'Tax',
        message: f.message,
      ),
      (saved) {
        setState(() => _cafe = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax settings saved')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Tax settings access denied.')),
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
        child: CafePosEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn’t load tax settings',
          message: _error ?? 'Unknown error',
          action: AppButton(label: 'Retry', expand: false, onPressed: _load),
        ),
      );
    }

    final cafe = _cafe!;

    return CafePosBackdrop(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: CafePosSpace.page(context),
              children: [
                Material(
                  color: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CafePosSpace.radius),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show GST on bill'),
                          subtitle: const Text('Uses each item’s tax %'),
                          value: cafe.showGstOnBill,
                          onChanged: (v) => setState(
                            () => _cafe = cafe.copyWith(showGstOnBill: v),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Split as CGST + SGST'),
                          subtitle: const Text('Show tax as two equal halves'),
                          value: cafe.gstSplitHalves,
                          onChanged: cafe.showGstOnBill
                              ? (v) => setState(
                                    () =>
                                        _cafe = cafe.copyWith(gstSplitHalves: v),
                                  )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'GST label',
                          controller: _gstLabel,
                          enabled: cafe.showGstOnBill && !cafe.gstSplitHalves,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
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
                child: AppButton(
                  label: _saving ? 'Saving…' : 'Save',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
