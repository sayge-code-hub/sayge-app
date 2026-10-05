import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
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
  final VoidCallback? onEdit;

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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          );
        }

        return _ClientDetailBody(
          client: client,
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
    required this.embedded,
    this.onBack,
    this.onEdit,
  });

  final Client client;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

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
        await showAppMessageDialog(
          context,
          message: 'Client logo updated',
        );
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

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    final details = EmployeeDetailSection(
      title: 'Client details',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(label: 'Company name', value: client.name),
        EmployeeDetailField(label: 'Contact name', value: client.contactName),
        EmployeeDetailField(label: 'Vendor code', value: client.vendorCode),
        EmployeeDetailField(label: 'Entity code', value: client.entityCode),
        EmployeeDetailField(label: 'GSTIN', value: client.gstin),
        EmployeeDetailField(
          label: 'Status',
          value: client.isActive ? 'Active' : 'Inactive',
        ),
        EmployeeDetailField(label: 'Address', value: client.address),
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
                                color: AppColors.background
                                    .withValues(alpha: 0.6),
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
            if (widget.onEdit != null)
              AppButton(
                label: 'Edit',
                onPressed: widget.onEdit,
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
