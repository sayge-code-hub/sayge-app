import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/client.dart';
import '../bloc/clients/clients_bloc.dart';
import '../widgets/client_documents_section.dart';

class AddClientsPage extends StatelessWidget {
  const AddClientsPage({
    super.key,
    this.embedded = false,
    this.clientId,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  /// When set, the form edits an existing client and shows DMS documents.
  final String? clientId;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  bool get isEditing => clientId != null && clientId!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return _AddClientsView(
      embedded: embedded,
      clientId: clientId?.trim(),
      onCompleted: onCompleted,
      onCancel: onCancel,
    );
  }
}

class _AddClientsView extends StatefulWidget {
  const _AddClientsView({
    required this.embedded,
    this.clientId,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  final String? clientId;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  State<_AddClientsView> createState() => _AddClientsViewState();
}

class _AddClientsViewState extends State<_AddClientsView> {
  final _nameController = TextEditingController();
  final _vendorController = TextEditingController();
  final _entityController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  bool _hydrated = false;

  bool get _isEditing =>
      widget.clientId != null && widget.clientId!.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _vendorController.dispose();
    _entityController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  void _clear() {
    _nameController.clear();
    _vendorController.clear();
    _entityController.clear();
    _contactController.clear();
    _addressController.clear();
    _gstinController.clear();
  }

  void _hydrate(Client client) {
    _nameController.text = client.name;
    _vendorController.text = client.vendorCode;
    _entityController.text = client.entityCode;
    _contactController.text = client.contactName;
    _addressController.text = client.address;
    _gstinController.text = client.gstin;
    _hydrated = true;
  }

  void _tryHydrate(List<Client> clients) {
    if (!_isEditing || _hydrated) return;
    final id = widget.clientId!;
    for (final client in clients) {
      if (client.id == id) {
        _hydrate(client);
        return;
      }
    }
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
          if (!_isEditing) _clear();
          await showAppMessageDialog(
            context,
            message: _isEditing
                ? 'Client updated successfully'
                : 'Client added successfully',
          );
          if (!context.mounted) return;
          if (widget.embedded) {
            widget.onCompleted?.call();
          }
        }
      },
      builder: (context, state) {
        _tryHydrate(state.clients);

        if (_isEditing &&
            !_hydrated &&
            (state.status == ClientsStatus.loading ||
                state.status == ClientsStatus.initial)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (_isEditing && !_hydrated) {
          return Center(
            child: Text(
              'Client not found.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          );
        }

        final isSaving = state.status == ClientsStatus.saving;

        Widget fieldGap = const SizedBox(height: 12);
        final fields = <Widget>[
          AppTextField(
            controller: _nameController,
            label: 'Company name',
            enabled: !isSaving,
            textCapitalization: TextCapitalization.words,
          ),
          fieldGap,
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _vendorController,
                    label: 'Vendor code',
                    enabled: !isSaving,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppTextField(
                    controller: _entityController,
                    label: 'Entity code',
                    enabled: !isSaving,
                  ),
                ),
              ],
            )
          else ...[
            AppTextField(
              controller: _vendorController,
              label: 'Vendor code',
              enabled: !isSaving,
            ),
            fieldGap,
            AppTextField(
              controller: _entityController,
              label: 'Entity code',
              enabled: !isSaving,
            ),
          ],
          fieldGap,
          AppTextField(
            controller: _contactController,
            label: 'Contact name',
            enabled: !isSaving,
            textCapitalization: TextCapitalization.words,
          ),
          fieldGap,
          AppTextField(
            controller: _addressController,
            label: 'Address',
            enabled: !isSaving,
            maxLines: 3,
          ),
          fieldGap,
          AppTextField(
            controller: _gstinController,
            label: 'GSTIN',
            enabled: !isSaving,
            textCapitalization: TextCapitalization.characters,
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
        ];

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
                      children: fields,
                    ),
                  ),
                  if (_isEditing && _hydrated) ...[
                    const SizedBox(height: 16),
                    ClientDocumentsSection(
                      clientId: widget.clientId!,
                      clientName: _nameController.text.trim().isEmpty
                          ? 'Client'
                          : _nameController.text.trim(),
                      enabled: !isSaving,
                    ),
                  ],
                ],
              ),
            ),
            EmployeeStickyActions(
              children: [
                OutlinedButton(
                  onPressed: isSaving
                      ? null
                      : () => leaveFormIfConfirmed(context, () {
                          if (widget.embedded) {
                            widget.onCancel?.call();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        }),
                  child: const Text('Back'),
                ),
                AppButton(
                  label: _isEditing ? 'Update' : 'Save',
                  isLoading: isSaving,
                  onPressed: () => context.read<ClientsBloc>().add(
                        ClientSubmitted(
                          clientId: widget.clientId,
                          name: _nameController.text,
                          vendorCode: _vendorController.text,
                          entityCode: _entityController.text,
                          contactName: _contactController.text,
                          address: _addressController.text,
                          gstin: _gstinController.text,
                        ),
                      ),
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
