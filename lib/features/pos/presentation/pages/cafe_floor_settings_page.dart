import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Number of dine-in tables for the terminal / QR printout.
class CafeFloorSettingsPage extends StatefulWidget {
  const CafeFloorSettingsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeFloorSettingsPage> createState() => _CafeFloorSettingsPageState();
}

class _CafeFloorSettingsPageState extends State<CafeFloorSettingsPage> {
  Cafe? _cafe;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late final TextEditingController _tableCount;

  @override
  void initState() {
    super.initState();
    _tableCount = TextEditingController(text: '16');
    _load();
  }

  @override
  void dispose() {
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
      cafe.copyWith(tableCount: tables.clamp(1, 100)),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (f) => showAppMessageDialog(
        context,
        title: 'Floor',
        message: f.message,
      ),
      (saved) {
        setState(() => _cafe = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor settings saved')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canManageCafeMenu(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Floor settings access denied.')),
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
          title: 'Couldn’t load floor settings',
          message: _error ?? 'Unknown error',
          action: AppButton(label: 'Retry', expand: false, onPressed: _load),
        ),
      );
    }

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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Dine-in tables',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'How many table numbers the terminal and QR printout show. '
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
