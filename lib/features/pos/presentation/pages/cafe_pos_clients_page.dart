import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../injection_container.dart';
import '../../../settings/presentation/bloc/clients/clients_bloc.dart';
import '../../../settings/presentation/widgets/client_name_label.dart';

/// Owner/admin: pick a Client cafe. Cafe roles redirect to their scoped client.
class CafePosClientsPage extends StatefulWidget {
  const CafePosClientsPage({super.key});

  @override
  State<CafePosClientsPage> createState() => _CafePosClientsPageState();
}

class _CafePosClientsPageState extends State<CafePosClientsPage> {
  @override
  void initState() {
    super.initState();
    final user = sl<AuthSession>().user;
    final scoped = AppAccess.cafeClientId(user);
    if (user != null && AppAccess.isCafeRole(user) && scoped != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppAccess.homeRoute(user));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = sl<AuthSession>().user;
    if (user != null && AppAccess.isCafeRole(user)) {
      final scoped = AppAccess.cafeClientId(user);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            scoped == null
                ? 'Your account is not linked to a cafe client. Ask an admin to set users.client_id.'
                : 'Opening your cafe…',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textLight,
                ),
          ),
        ),
      );
    }

    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsRequested()),
      child: const _ClientPickerBody(),
    );
  }
}

class _ClientPickerBody extends StatelessWidget {
  const _ClientPickerBody();

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, state) {
        if (state.status == ClientsStatus.loading ||
            state.status == ClientsStatus.initial) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }
        final clients =
            state.clients.where((c) => c.isActive).toList(growable: false);
        if (clients.isEmpty) {
          return Center(
            child: Text(
              'No active clients. Add a client in Settings first.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            16,
            isDesktop ? 32 : 16,
            24,
          ),
          itemCount: clients.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final client = clients[index];
            return AppListCard(
              onTap: () => context.go(AppRoutes.posClient(client.id)),
              child: ClientNameLabel(
                name: client.name,
                contactName: client.contactName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                    ),
              ),
            );
          },
        );
      },
    );
  }
}
