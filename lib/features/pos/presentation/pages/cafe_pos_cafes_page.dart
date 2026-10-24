import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

/// Staff: list/create cafes. Cafe roles redirect to their scoped cafe.
class CafePosCafesPage extends StatefulWidget {
  const CafePosCafesPage({super.key});

  @override
  State<CafePosCafesPage> createState() => _CafePosCafesPageState();
}

class _CafePosCafesPageState extends State<CafePosCafesPage> {
  List<Cafe> _cafes = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = sl<AuthSession>().user;
    final scoped = AppAccess.cafeIdOf(user);
    if (user != null && AppAccess.isCafeRole(user) && scoped != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppAccess.homeRoute(user));
      });
      return;
    }
    _reload();
  }

  Future<void> _reload() async {
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
      (list) => setState(() {
        _cafes = list;
        _loading = false;
      }),
    );
  }

  Future<void> _createCafe() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New cafe'),
        content: AppTextField(
          label: 'Cafe name',
          controller: name,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          AppButton(
            label: 'Create',
            expand: false,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final result = await sl<UpsertCafe>()(
      Cafe(id: '', name: name.text.trim()),
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'POS', message: f.message),
      (cafe) {
        context.go(AppRoutes.posCafe(cafe.id));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (user != null && AppAccess.isCafeRole(user)) {
      final scoped = AppAccess.cafeIdOf(user);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            scoped == null
                ? 'Your account is not linked to a cafe. Ask an admin to set users.cafe_id.'
                : 'Opening your cafe…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ),
      );
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

    final active = _cafes.where((c) => c.isActive).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: Text(
                  'Select a cafe to manage menu, terminal, and kitchen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                ),
              ),
              AppButton(
                label: 'New cafe',
                expand: false,
                onPressed: _createCafe,
              ),
            ],
          ),
        ),
        Expanded(
          child: active.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No cafes yet. Create one to start Cafe POS.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textLight,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Create cafe',
                          expand: false,
                          onPressed: _createCafe,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    8,
                    isDesktop ? 32 : 16,
                    24,
                  ),
                  itemCount: active.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final cafe = active[index];
                    return AppListCard(
                      onTap: () => context.go(AppRoutes.posCafe(cafe.id)),
                      child: Text(
                        cafe.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
