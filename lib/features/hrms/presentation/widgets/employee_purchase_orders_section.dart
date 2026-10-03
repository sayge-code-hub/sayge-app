import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/employee_purchase_order.dart';
import '../bloc/employee_po/employee_po_bloc.dart';

class EmployeePurchaseOrdersSection extends StatelessWidget {
  const EmployeePurchaseOrdersSection({
    super.key,
    required this.employeeId,
    required this.isDesktop,
  });

  final String employeeId;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<EmployeePoBloc>()..add(EmployeePoRequested(employeeId)),
      child: _EmployeePurchaseOrdersBody(
        employeeId: employeeId,
        isDesktop: isDesktop,
      ),
    );
  }
}

class _EmployeePurchaseOrdersBody extends StatelessWidget {
  const _EmployeePurchaseOrdersBody({
    required this.employeeId,
    required this.isDesktop,
  });

  final String employeeId;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeePoBloc, EmployeePoState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage ||
          prev.downloadUrl != next.downloadUrl,
      listener: (context, state) async {
        if (state.errorMessage != null && context.mounted) {
          await showAppMessageDialog(
            context,
            title: 'Purchase order',
            message: state.errorMessage!,
          );
        }
        final url = state.downloadUrl;
        if (url != null && url.isNotEmpty && context.mounted) {
          final uri = Uri.parse(url);
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (!launched && context.mounted) {
            await showAppMessageDialog(
              context,
              title: 'Purchase order',
              message: 'Could not open the PO PDF.',
            );
          }
        }
      },
      builder: (context, state) {
        final saving = state.status == EmployeePoStatus.saving;
        final loading = state.status == EmployeePoStatus.loading ||
            state.status == EmployeePoStatus.initial;

        return Container(
          width: double.infinity,
          padding: AppListCard.sectionPadding,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Purchase orders',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.highlight,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => _showAddPoDialog(context, employeeId),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add PO'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.text),
                  ),
                )
              else if (state.orders.isEmpty)
                Text(
                  'No purchase orders yet. Add a PO number, dates, and PDF.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLight,
                      ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < state.orders.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _PoRow(order: state.orders[i]),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PoRow extends StatelessWidget {
  const _PoRow({required this.order});

  final EmployeePurchaseOrder order;

  @override
  Widget build(BuildContext context) {
    final dates =
        '${AppDates.compact.format(order.startDate)} - ${AppDates.compact.format(order.endDate)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.poNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  dates,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                ),
                if (order.fileName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.textLight,
                        ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open PDF',
            onPressed: !order.hasFile
                ? null
                : () => context
                    .read<EmployeePoBloc>()
                    .add(EmployeePoDownloadRequested(order)),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddPoDialog(BuildContext context, String employeeId) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: context.read<EmployeePoBloc>(),
        child: _AddPoDialog(employeeId: employeeId),
      );
    },
  );

  if (saved == true && context.mounted) {
    await showAppMessageDialog(
      context,
      title: 'Purchase order',
      message: 'Purchase order added.',
    );
  }
}

class _AddPoDialog extends StatefulWidget {
  const _AddPoDialog({required this.employeeId});

  final String employeeId;

  @override
  State<_AddPoDialog> createState() => _AddPoDialogState();
}

class _AddPoDialogState extends State<_AddPoDialog> {
  final _poNumber = TextEditingController();
  final _startCtrl = TextEditingController();
  final _endCtrl = TextEditingController();
  final _dateFormat = DateFormat('dd-MM-yyyy');

  DateTime? _startDate;
  DateTime? _endDate;
  String? _fileName;
  Uint8List? _fileBytes;
  String _mimeType = 'application/pdf';

  @override
  void dispose() {
    _poNumber.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool end}) async {
    final initial = end
        ? (_endDate ?? _startDate ?? DateTime.now())
        : (_startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _endDate = picked;
        _endCtrl.text = _dateFormat.format(picked);
      } else {
        _startDate = picked;
        _startCtrl.text = _dateFormat.format(picked);
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
          _endCtrl.text = _dateFormat.format(picked);
        }
      }
    });
  }

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (!mounted) return;
      await showAppMessageDialog(
        context,
        title: 'Purchase order',
        message: 'Could not read the selected PDF. Try another file.',
      );
      return;
    }
    setState(() {
      _fileName = file.name;
      _fileBytes = bytes;
      _mimeType = 'application/pdf';
    });
  }

  void _submit() {
    final poNumber = _poNumber.text.trim();
    if (poNumber.isEmpty) {
      showAppMessageDialog(
        context,
        title: 'Purchase order',
        message: 'Enter the PO number.',
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      showAppMessageDialog(
        context,
        title: 'Purchase order',
        message: 'Select start and end dates.',
      );
      return;
    }
    if (_fileName == null || _fileBytes == null) {
      showAppMessageDialog(
        context,
        title: 'Purchase order',
        message: 'Attach the PO PDF document.',
      );
      return;
    }

    context.read<EmployeePoBloc>().add(
          EmployeePoSubmitted(
            employeeId: widget.employeeId,
            poNumber: poNumber,
            startDate: _startDate!,
            endDate: _endDate!,
            fileName: _fileName!,
            fileBytes: _fileBytes!,
            mimeType: _mimeType,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EmployeePoBloc, EmployeePoState>(
      listenWhen: (prev, next) =>
          prev.status == EmployeePoStatus.saving &&
          next.status == EmployeePoStatus.ready &&
          next.successMessage != null,
      listener: (context, state) {
        if (!Navigator.of(context).canPop()) return;
        Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final saving = state.status == EmployeePoStatus.saving;

        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'Add purchase order',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  label: 'PO number',
                  controller: _poNumber,
                  enabled: !saving,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Start date',
                  controller: _startCtrl,
                  readOnly: true,
                  enabled: !saving,
                  hintText: 'Select date',
                  onTap: saving ? null : () => _pickDate(end: false),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'End date',
                  controller: _endCtrl,
                  readOnly: true,
                  enabled: !saving,
                  hintText: 'Select date',
                  onTap: saving ? null : () => _pickDate(end: true),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PO document (PDF)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          color: AppColors.textLight,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving ? null : _pickPdf,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(_fileName == null ? 'Choose PDF' : 'Change'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fileName ?? 'No file selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Save',
              expand: false,
              isLoading: saving,
              enabled: !saving,
              onPressed: _submit,
            ),
          ],
        );
      },
    );
  }
}
