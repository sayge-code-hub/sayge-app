import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform_ops/platform_ops_session.dart';
import '../../../../core/router/app_routes.dart';
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
  static const _white = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);

  final _controller = TextEditingController();
  String? _error;
  bool _obscure = true;

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

    return Scaffold(
      backgroundColor: _white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 16, wide ? 48 : 20, 16),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  TextButton(
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
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/saasify_logo.png',
                          height: 72,
                          fit: BoxFit.contain,
                          semanticLabel: 'Saasify',
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Owner access',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _black,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter password to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _controller,
                        obscureText: _obscure,
                        autofocus: true,
                        cursorColor: _black,
                        style: const TextStyle(
                          color: _black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: _muted),
                          floatingLabelStyle: const TextStyle(color: _black),
                          errorText: _error,
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _line),
                            borderRadius: BorderRadius.zero,
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _black, width: 1.4),
                            borderRadius: BorderRadius.zero,
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _black),
                            borderRadius: BorderRadius.zero,
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: _black, width: 1.4),
                            borderRadius: BorderRadius.zero,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: _muted,
                              size: 20,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _black,
                            foregroundColor: _white,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
