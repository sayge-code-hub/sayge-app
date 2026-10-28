import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/platform_ops/platform_ops_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_password_field.dart';
import '../../../../injection_container.dart';

/// Fixed-password entry — black / white, full-width chrome.
class PlatformOpsGatePage extends StatefulWidget {
  const PlatformOpsGatePage({super.key});

  @override
  State<PlatformOpsGatePage> createState() => _PlatformOpsGatePageState();
}

class _PlatformOpsGatePageState extends State<PlatformOpsGatePage> {
  static const _password = 'ihateluvstories';
  static const _black = Color(0xFF0A0A0A);
  static const _line = Color(0xFFE5E5E5);

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text;
    if (value != _password) {
      setState(() => _error = 'Incorrect password');
      return;
    }
    sl<PlatformOpsSession>().unlock();
    context.go(AppRoutes.platformOps);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compact = Breakpoints.isCompact(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            padding: EdgeInsets.fromLTRB(wide ? 48 : 16, 12, wide ? 48 : 16, 12),
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.login),
                  style: TextButton.styleFrom(
                    foregroundColor: _black,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '← Back',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 20 : 24,
                      compact ? 24 : 36,
                      compact ? 20 : 24,
                      24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                        maxWidth: 400,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/saasify_logo.png',
                                  height: compact ? 40 : 48,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'Saasify',
                                ),
                              ),
                              SizedBox(height: compact ? 20 : 24),
                              Text(
                                'Owner access',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 24 : 28,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter password to continue',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              AppPasswordField(
                                controller: _controller,
                                autofocus: true,
                                errorText: _error,
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                                onSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'Continue',
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
