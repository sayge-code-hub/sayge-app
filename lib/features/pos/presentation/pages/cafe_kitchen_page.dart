import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';
import '../widgets/cafe_pos_chrome.dart';

class CafeKitchenPage extends StatefulWidget {
  const CafeKitchenPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeKitchenPage> createState() => _CafeKitchenPageState();
}

class _CafeKitchenPageState extends State<CafeKitchenPage> {
  List<CafeOrder> _orders = const [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  static const _active = [
    CafePrepStatus.neu,
    CafePrepStatus.preparing,
    CafePrepStatus.ready,
  ];

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final result = await sl<GetCafeOrders>()(
      widget.cafeId,
      prepStatuses: _active,
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (list) => setState(() {
        _orders = list;
        _loading = false;
        _error = null;
      }),
    );
  }

  CafePrepStatus? _next(CafePrepStatus current) {
    return switch (current) {
      CafePrepStatus.neu => CafePrepStatus.preparing,
      CafePrepStatus.preparing => CafePrepStatus.ready,
      CafePrepStatus.ready => CafePrepStatus.completed,
      _ => null,
    };
  }

  Future<void> _advance(CafeOrder order) async {
    final next = _next(order.prepStatus);
    if (next == null) return;
    final result = await sl<UpdateCafePrepStatus>()(
      orderId: order.id,
      status: next,
    );
    if (!mounted) return;
    result.fold(
      (f) => showAppMessageDialog(context, title: 'Kitchen', message: f.message),
      (_) => _reload(),
    );
  }

  Color _tintFor(CafePrepStatus status) {
    return switch (status) {
      CafePrepStatus.neu => const Color(0xFFD97706),
      CafePrepStatus.preparing => const Color(0xFF2563EB),
      CafePrepStatus.ready => AppColors.success,
      _ => AppColors.textLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canRunCafeKitchen(user, widget.cafeId)) {
      return const CafePosBackdrop(
        child: Center(child: Text('Kitchen access denied.')),
      );
    }
    final isDesktop = Breakpoints.isDesktop(context);
    final pagePad = CafePosSpace.page(context);
    if (_loading && _orders.isEmpty) {
      return const CafePosBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.text),
        ),
      );
    }
    if (_error != null && _orders.isEmpty) {
      return CafePosBackdrop(
        child: CafePosEmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Couldn’t load kitchen',
          message: _error!,
          action: AppButton(label: 'Retry', expand: false, onPressed: _reload),
        ),
      );
    }

    List<CafeOrder> col(CafePrepStatus s) =>
        _orders.where((o) => o.prepStatus == s).toList();

    Widget column(String title, CafePrepStatus status, {EdgeInsets? inset}) {
      final list = col(status);
      final tint = _tintFor(status);
      final hPad = inset ?? EdgeInsets.zero;
      return Expanded(
        child: Padding(
          padding: hPad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tint.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    Text(
                      '${list.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tint,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'Quiet here',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textLight,
                                    fontSize: 13,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = list[index];
                          final next = _next(order.prepStatus);
                          return Material(
                            color: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(CafePosSpace.radius),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        order.orderNo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        [
                                          if (order.tableNo.trim().isNotEmpty)
                                            'Table ${order.tableNo.trim()}',
                                          order.orderType.label,
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textLight,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  for (final item in order.items)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '${item.quantity.toStringAsFixed(0)} × ${item.itemName}'
                                        '${item.notes.trim().isEmpty ? '' : ' (${item.notes})'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                      ),
                                    ),
                                  if (next != null) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: AppButton(
                                        label: next.label,
                                        expand: false,
                                        onPressed: () => _advance(order),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    final board = isDesktop
        ? Padding(
            padding: EdgeInsets.fromLTRB(
              pagePad.left,
              0,
              pagePad.right,
              pagePad.bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column('New', CafePrepStatus.neu),
                const SizedBox(width: 16),
                column('Preparing', CafePrepStatus.preparing),
                const SizedBox(width: 16),
                column('Ready', CafePrepStatus.ready),
              ],
            ),
          )
        : DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pagePad.left),
                  child: TabBar(
                    labelColor: AppColors.text,
                    unselectedLabelColor: AppColors.textLight,
                    indicatorColor: AppColors.highlight,
                    tabs: [
                      Tab(text: 'New (${col(CafePrepStatus.neu).length})'),
                      Tab(
                        text:
                            'Preparing (${col(CafePrepStatus.preparing).length})',
                      ),
                      Tab(text: 'Ready (${col(CafePrepStatus.ready).length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      column(
                        'New',
                        CafePrepStatus.neu,
                        inset: EdgeInsets.fromLTRB(
                          pagePad.left,
                          12,
                          pagePad.right,
                          pagePad.bottom,
                        ),
                      ),
                      column(
                        'Preparing',
                        CafePrepStatus.preparing,
                        inset: EdgeInsets.fromLTRB(
                          pagePad.left,
                          12,
                          pagePad.right,
                          pagePad.bottom,
                        ),
                      ),
                      column(
                        'Ready',
                        CafePrepStatus.ready,
                        inset: EdgeInsets.fromLTRB(
                          pagePad.left,
                          12,
                          pagePad.right,
                          pagePad.bottom,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

    return CafePosBackdrop(
      child: Column(
        children: [
          Padding(
            padding: pagePad.copyWith(bottom: 12),
            child: CafePosPageHeader(
              title: 'Kitchen',
              subtitle: 'Advance tickets as you prep',
              trailing: IconButton(
                tooltip: 'Refresh',
                onPressed: _reload,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ),
          ),
          Expanded(child: board),
        ],
      ),
    );
  }
}
