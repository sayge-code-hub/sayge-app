import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/usecases/cafe_pos_usecases.dart';

class CafeKitchenPage extends StatefulWidget {
  const CafeKitchenPage({super.key, required this.clientId});

  final String clientId;

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
      widget.clientId,
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

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (!AppAccess.canRunCafeKitchen(user, widget.clientId)) {
      return const Center(child: Text('Kitchen access denied.'));
    }
    final isDesktop = Breakpoints.isDesktop(context);
    if (_loading && _orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.text),
      );
    }
    if (_error != null && _orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            AppButton(label: 'Retry', expand: false, onPressed: _reload),
          ],
        ),
      );
    }

    List<CafeOrder> col(CafePrepStatus s) =>
        _orders.where((o) => o.prepStatus == s).toList();

    Widget column(String title, CafePrepStatus status, Color tint) {
      final list = col(status);
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: tint.withValues(alpha: 0.12),
              child: Text(
                '$title (${list.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14,
                    ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        '—',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textLight,
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = list[index];
                        final next = _next(order.prepStatus);
                        return AppListCard(
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
                                        ?.copyWith(fontSize: 15),
                                  ),
                                  const Spacer(),
                                  Text(
                                    order.orderType.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textLight),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              for (final item in order.items)
                                Text(
                                  '${item.quantity.toStringAsFixed(0)} × ${item.itemName}'
                                  '${item.notes.trim().isEmpty ? '' : ' (${item.notes})'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              if (next != null) ...[
                                const SizedBox(height: 10),
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
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    final board = isDesktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              column('New', CafePrepStatus.neu, Colors.orange),
              const VerticalDivider(width: 1),
              column('Preparing', CafePrepStatus.preparing, Colors.blue),
              const VerticalDivider(width: 1),
              column('Ready', CafePrepStatus.ready, Colors.green),
            ],
          )
        : DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'New'),
                    Tab(text: 'Preparing'),
                    Tab(text: 'Ready'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      column('New', CafePrepStatus.neu, Colors.orange),
                      column(
                        'Preparing',
                        CafePrepStatus.preparing,
                        Colors.blue,
                      ),
                      column('Ready', CafePrepStatus.ready, Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 12, 8, 12, 0),
          child: Row(
            children: [
              Text(
                'Kitchen display',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(child: board),
      ],
    );
  }
}
