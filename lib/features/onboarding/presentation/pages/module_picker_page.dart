import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/billing/billing_access.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/modules/app_modules.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../injection_container.dart';

/// Post-signup: owner picks which product packs to enable.
class ModulePickerPage extends StatefulWidget {
  const ModulePickerPage({super.key});

  @override
  State<ModulePickerPage> createState() => _ModulePickerPageState();
}

class _ModulePickerPageState extends State<ModulePickerPage> {
  final Set<AppModule> _selected = {};
  AppModule? _expanded;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final code in sl<BillingAccess>().enabledModules) {
      final m = AppModule.tryParse(code);
      if (m != null) _selected.add(m);
    }
  }

  void _toggleSelect(AppModule m) {
    if (_busy) return;
    setState(() {
      if (_selected.contains(m)) {
        _selected.remove(m);
      } else {
        _selected.add(m);
      }
      _error = null;
    });
  }

  void _toggleExpand(AppModule m) {
    setState(() {
      _expanded = _expanded == m ? null : m;
    });
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (_selected.isEmpty) {
      setState(() => _error = 'Select at least one module to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sl<BillingAccess>().setModules(_selected.toList(growable: false));
      final user = sl<AuthSession>().user;
      if (!mounted) return;
      if (user == null) {
        context.go(AppRoutes.login);
        return;
      }
      context.go(AppAccess.homeRoute(user));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = Breakpoints.isCompact(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final theme = Theme.of(context);
    final total = _selected.length * AppModule.priceInrPerMonth;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 880 : 520),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                compact ? 16 : 28,
                compact ? 16 : 24,
                compact ? 12 : 20,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/saasify_logo.png',
                            height: compact ? 36 : 44,
                            fit: BoxFit.contain,
                            semanticLabel: 'Saasify',
                          ),
                          SizedBox(height: compact ? 20 : 28),
                          Text(
                            'Choose your modules',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              fontSize: compact ? 24 : 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${AppModule.priceInrPerMonth} per module / month. '
                            'Tap a card to select · '
                            '${kIsWeb ? 'hover' : 'tap again'} for features.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textLight,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: compact ? 20 : 28),
                          if (wide)
                            _WideGrid(
                              selected: _selected,
                              expanded: _expanded,
                              busy: _busy,
                              onSelect: _toggleSelect,
                              onExpand: _toggleExpand,
                              onHoverExpand: (m, hovering) {
                                if (!kIsWeb) return;
                                setState(() {
                                  _expanded = hovering ? m : null;
                                });
                              },
                            )
                          else
                            ...AppModule.values.map(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ModuleCard(
                                  module: m,
                                  selected: _selected.contains(m),
                                  expanded: _expanded == m,
                                  busy: _busy,
                                  onSelect: () => _toggleSelect(m),
                                  onExpand: () => _toggleExpand(m),
                                  onHoverExpand: (hovering) {
                                    if (!kIsWeb) return;
                                    setState(() {
                                      _expanded = hovering ? m : null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_selected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${_selected.length} module${_selected.length == 1 ? '' : 's'} · ₹$total / month',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  AppButton(
                    label: _busy ? 'Saving…' : 'Continue',
                    onPressed: _busy ? null : _continue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideGrid extends StatelessWidget {
  const _WideGrid({
    required this.selected,
    required this.expanded,
    required this.busy,
    required this.onSelect,
    required this.onExpand,
    required this.onHoverExpand,
  });

  final Set<AppModule> selected;
  final AppModule? expanded;
  final bool busy;
  final ValueChanged<AppModule> onSelect;
  final ValueChanged<AppModule> onExpand;
  final void Function(AppModule module, bool hovering) onHoverExpand;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final m in AppModule.values)
          SizedBox(
            width: 270,
            child: _ModuleCard(
              module: m,
              selected: selected.contains(m),
              expanded: expanded == m,
              busy: busy,
              onSelect: () => onSelect(m),
              onExpand: () => onExpand(m),
              onHoverExpand: (h) => onHoverExpand(m, h),
            ),
          ),
      ],
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.module,
    required this.selected,
    required this.expanded,
    required this.busy,
    required this.onSelect,
    required this.onExpand,
    required this.onHoverExpand,
  });

  final AppModule module;
  final bool selected;
  final bool expanded;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onExpand;
  final ValueChanged<bool> onHoverExpand;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.module;
    final selected = widget.selected;
    final showFeatures = widget.expanded || (kIsWeb && _hovered);
    final borderColor = selected
        ? AppColors.text
        : (_hovered ? AppColors.text.withValues(alpha: 0.35) : AppColors.border);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHoverExpand(true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
        widget.onHoverExpand(false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          boxShadow: [
            if (_hovered || selected)
              BoxShadow(
                color: AppColors.text.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.busy
                ? null
                : () {
                    if (kIsWeb) {
                      widget.onSelect();
                    } else {
                      // Mobile: tap toggles selection and reveals features.
                      widget.onSelect();
                      if (!widget.expanded) widget.onExpand();
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.highlight.withValues(alpha: 0.14)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          m.icon,
                          size: 22,
                          color: selected ? AppColors.highlight : AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              m.priceLabel,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.highlight,
                                fontWeight: FontWeight.w700,
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
                            ? AppColors.highlight
                            : AppColors.textLight,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    m.blurb,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textLight,
                      height: 1.35,
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final f in m.features)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: AppColors.highlight,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.text,
                                        height: 1.3,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    crossFadeState: showFeatures
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 180),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
