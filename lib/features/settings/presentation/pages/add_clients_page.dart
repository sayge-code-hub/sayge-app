import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../bloc/clients/clients_bloc.dart';

class AddClientsPage extends StatelessWidget {
  const AddClientsPage({
    super.key,
    this.embedded = false,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return _AddClientsView(
      embedded: embedded,
      onCompleted: onCompleted,
      onCancel: onCancel,
    );
  }
}

class _AddClientsView extends StatefulWidget {
  const _AddClientsView({
    required this.embedded,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  State<_AddClientsView> createState() => _AddClientsViewState();
}

class _AddClientsViewState extends State<_AddClientsView> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final textTheme = Theme.of(context).textTheme;
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocConsumer<ClientsBloc, ClientsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        if (state.status == ClientsStatus.success) {
          _nameController.clear();
          await showAppMessageDialog(
            context,
            message: 'Client added successfully',
          );
          if (!context.mounted) return;
          if (widget.embedded) {
            widget.onCompleted?.call();
          }
        }
      },
      builder: (context, state) {
        final isSaving = state.status == ClientsStatus.saving;

        final body = Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  widget.embedded ? (isDesktop ? 12 : 8) : 16,
                  horizontal,
                  24,
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 28 : 20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: isDesktop
                          ? BorderRadius.circular(12)
                          : BorderRadius.zero,
                      border: isDesktop
                          ? Border.all(color: AppColors.border)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: 'Client name',
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) => context
                              .read<ClientsBloc>()
                              .add(ClientNameChanged(value)),
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.errorMessage!,
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            EmployeeStickyActions(
              children: [
                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                          if (widget.embedded) {
                            widget.onCancel?.call();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                  child: const Text('Back'),
                ),
                AppButton(
                  label: 'Save',
                  expand: false,
                  isLoading: isSaving,
                  onPressed: () => context
                      .read<ClientsBloc>()
                      .add(const ClientSubmitted()),
                ),
              ],
            ),
          ],
        );

        if (widget.embedded) {
          return body;
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(toolbarHeight: 72),
          body: body,
        );
      },
    );
  }
}
