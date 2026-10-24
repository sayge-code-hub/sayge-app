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
  late final TextEditingController _tableCount;

  @override
  void initState() {
    super.initState();
    _gstLabel = TextEditingController(text: 'GST');
    _tableCount = TextEditingController(text: '16');
    _load();
  }

  @override
  void dispose() {
    _gstLabel.dispose();
    _tableCount.dispose();
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
        _tableCount.text = '${found.tableCount}';
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
    final tables = int.tryParse(_tableCount.text.trim()) ?? cafe.tableCount;
    setState(() => _saving = true);
    final result = await sl<UpsertCafe>()(
      cafe.copyWith(
        gstLabel: _gstLabel.text.trim(),
        tableCount: tables.clamp(1, 100),
      ),
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
                const CafePosPageHeader(
                  title: 'Tax & floor',
                  subtitle: 'GST on the bill and dine-in table count',
                ),
                const SizedBox(height: 20),
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
                        Text(
                          'GST on bill',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Uses each menu item’s tax %. Run cafe_pos_gst_settings.sql if save fails.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                        ),
                        const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Material(
                  color: AppColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CafePosSpace.radius),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Dine-in tables',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How many table numbers the terminal shows. '
                          'Run cafe_pos_tables.sql if save fails.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Number of tables',
                          controller: _tableCount,
                          keyboardType: TextInputType.number,
                        ),
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
                  label: _saving ? 'Saving…' : 'Save settings',
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
