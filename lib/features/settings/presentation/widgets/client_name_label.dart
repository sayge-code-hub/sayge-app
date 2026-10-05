import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../hrms/presentation/widgets/employee_avatar.dart';
import '../../domain/entities/client.dart';
import '../bloc/clients/clients_bloc.dart';

/// Resolves a client by company (or contact) name for logo lookup.
Client? findClientByCompanyName(
  List<Client> clients,
  String companyName, {
  String contactName = '',
}) {
  final company = companyName.trim().toLowerCase();
  if (company.isEmpty) return null;
  final contact = contactName.trim().toLowerCase();

  if (contact.isNotEmpty) {
    for (final client in clients) {
      if (client.name.trim().toLowerCase() == company &&
          client.contactName.trim().toLowerCase() == contact) {
        return client;
      }
    }
  }

  Client? match;
  for (final client in clients) {
    if (client.name.trim().toLowerCase() != company) continue;
    if (match != null) return match; // ambiguous → first match is fine for logo
    match = client;
  }
  return match;
}

/// Compact client name with a tiny logo when available.
class ClientNameLabel extends StatelessWidget {
  const ClientNameLabel({
    super.key,
    required this.name,
    this.contactName = '',
    this.style,
    this.logoRadius = 7,
    this.maxLines = 1,
  });

  final String name;
  final String contactName;
  final TextStyle? style;
  final double logoRadius;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final label = name.trim();
    if (label.isEmpty) return const SizedBox.shrink();

    ClientsBloc? bloc;
    try {
      bloc = context.read<ClientsBloc>();
    } catch (_) {
      bloc = null;
    }

    if (bloc == null) {
      return Text(
        label,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return BlocBuilder<ClientsBloc, ClientsState>(
      bloc: bloc,
      buildWhen: (prev, next) => prev.clients != next.clients,
      builder: (context, state) {
        final client = findClientByCompanyName(
          state.clients,
          label,
          contactName: contactName,
        );
        final logoUrl = client?.logoUrl?.trim() ?? '';
        final textStyle = style ??
            Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: AppColors.textLight,
                );

        if (logoUrl.isEmpty) {
          return Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmployeeAvatar(
              name: label,
              photoUrl: logoUrl,
              radius: logoRadius,
              fontSize: logoRadius * 0.75,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              ),
            ),
          ],
        );
      },
    );
  }
}
