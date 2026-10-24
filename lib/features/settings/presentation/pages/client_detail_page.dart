import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../../hrms/presentation/widgets/employee_avatar.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/client.dart';
import '../../domain/usecases/update_client_logo_usecase.dart';
import '../bloc/clients/clients_bloc.dart';
import '../widgets/client_documents_section.dart';

class ClientDetailPage extends StatelessWidget {
  const ClientDetailPage({
    super.key,
    required this.clientId,
    this.embedded = false,
    this.onBack,
    this.onEdit,
  });

  final String clientId;
  final bool embedded;
  final VoidCallback? onBack;
  final ValueChanged<String>? onEdit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, state) {
        Client? client;
        for (final item in state.clients) {
          if (item.id == clientId) {
            client = item;
            break;
          }
        }

        if (client == null &&
            (state.status == ClientsStatus.loading ||
                state.status == ClientsStatus.initial)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (client == null) {
          return Center(
            child: Text(
              'Client not found.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
            ),
          );
        }

        final opened = client;
        final salutations = state.clients
            .where((item) => item.companyKey == opened.companyKey)
            .toList()
          ..sort(
            (a, b) => a.contactName.toLowerCase().compareTo(
              b.contactName.toLowerCase(),
            ),
          );

        return _ClientDetailBody(
          client: opened,
          salutations: salutations.isEmpty ? [opened] : salutations,
          embedded: embedded,
          onBack: onBack,
          onEdit: onEdit,
        );
      },
    );
  }
}

class _ClientDetailBody extends StatefulWidget {
  const _ClientDetailBody({
    required this.client,
    required this.salutations,
    required this.embedded,
    this.onBack,
    this.onEdit,
  });

  final Client client;
  final List<Client> salutations;
  final bool embedded;
  final VoidCallback? onBack;
  final ValueChanged<String>? onEdit;

  @override
  State<_ClientDetailBody> createState() => _ClientDetailBodyState();
}

class _ClientDetailBodyState extends State<_ClientDetailBody> {
  late Client _client;
  bool _uploadingLogo = false;

  bool get _canEditLogo => AppAccess.isStaff(sl<AuthSession>().user);

  @override
  void initState() {
    super.initState();
    _client = widget.client;
  }

  @override
  void didUpdateWidget(covariant _ClientDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      _client = widget.client;
    }
  }

  Future<void> _pickAndUploadLogo() async {
    if (!_canEditLogo || _uploadingLogo) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    setState(() => _uploadingLogo = true);
    final result = await sl<UpdateClientLogoUseCase>()(
      id: _client.id,
      bytes: bytes,
      fileName: file.name,
      mimeType: _mimeFor(file.extension, file.name),
    );
    if (!mounted) return;
    setState(() => _uploadingLogo = false);

    await result.fold(
      (failure) => showAppMessageDialog(
        context,
        title: 'Client logo',
        message: failure.message,
      ),
      (updated) async {
        setState(() => _client = updated);
        context.read<ClientsBloc>().add(const ClientsRequested());
        if (!mounted) return;
        await showAppMessageDialog(context, message: 'Client logo updated');
      },
    );
  }

  static String _mimeFor(String? extension, String fileName) {
    final ext = (extension ?? '').toLowerCase();
    if (ext.isEmpty && fileName.contains('.')) {
      final fromName = fileName.split('.').last.toLowerCase();
      return _mimeFor(fromName, fileName);
    }
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _confirmDelete(Client salutation) async {
    final name = salutation.contactName.trim().isEmpty
        ? salutation.name
        : salutation.contactName.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text('Delete salutation'),
          content: Text(
            'Delete $name? Linked employees will keep their records but lose '
            'this client link.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    context.read<ClientsBloc>().add(ClientDeleted(salutation.id));
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    final salutations = widget.salutations;
    final details = EmployeeDetailSection(
      title: 'Client details',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(label: 'Company name', value: client.name),
        EmployeeDetailField(label: 'Vendor code', value: client.vendorCode),
        EmployeeDetailField(label: 'Entity code', value: client.entityCode),
        EmployeeDetailField(label: 'GSTIN', value: client.gstin),
        EmployeeDetailField(label: 'Address', value: client.address),
      ],
    );

    final salutationSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Salutations',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.highlight,
          ),
        ),
        const SizedBox(height: 10),
        for (final salutation in salutations) ...[
          AppListCard(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    salutation.contactName.trim().isEmpty
                        ? '—'
                        : salutation.contactName.trim(),
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                ),
                if (!salutation.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'Inactive',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                AppListIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: widget.onEdit == null
                      ? null
                      : () => widget.onEdit!(salutation.id),
                ),
                AppListIconButton(
                  icon: salutation.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  tooltip: salutation.isActive ? 'Deactivate' : 'Activate',
                  onPressed: () => context.read<ClientsBloc>().add(
                    ClientActiveToggled(
                      clientId: salutation.id,
                      isActive: !salutation.isActive,
                    ),
                  ),
                ),
                AppListIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(salutation),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );

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
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: _canEditLogo && !_uploadingLogo
                        ? _pickAndUploadLogo
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        EmployeeAvatar(
                          name: client.name,
                          photoUrl: client.logoUrl,
                          radius: isDesktop ? 44 : 40,
                          fontSize: isDesktop ? 22 : 20,
                        ),
                        if (_uploadingLogo)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: 0.6,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_canEditLogo && !_uploadingLogo)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.highlight,
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              details,
              const SizedBox(height: 16),
              salutationSection,
              const SizedBox(height: 12),
              ClientDocumentsSection(
                clientId: client.id,
                clientName: client.name,
                enabled: false,
              ),
            ],
          ),
        ),
        EmployeeStickyActions(
          children: [
            if (widget.onBack != null)
              OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Back'),
              ),
            if (widget.onEdit != null && salutations.length <= 1)
              AppButton(
                label: 'Edit',
                onPressed: () => widget.onEdit!(client.id),
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
      appBar: AppBar(
        title: Text(
          client.displayLabel,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
      ),
      body: body,
    );
  }
}
