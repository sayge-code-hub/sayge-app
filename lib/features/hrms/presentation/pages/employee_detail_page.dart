import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../injection_container.dart';
import '../../domain/entities/employee.dart';
import '../../domain/usecases/exit_employee.dart';
import '../../domain/usecases/update_employee_photo_usecase.dart';
import '../bloc/employees/employees_bloc.dart';
import '../widgets/employee_avatar.dart';
import '../widgets/employee_documents_section.dart';
import '../widgets/employee_form_layout.dart';
import '../widgets/employee_purchase_orders_section.dart';

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({
    super.key,
    required this.employee,
    this.embedded = false,
    this.canEdit = true,
    this.showPurchaseOrders = true,
    this.canManagePurchaseOrders = true,
    this.showDocuments = true,
    this.onBack,
    this.onEdit,
  });

  final Employee employee;
  final bool embedded;
  final bool canEdit;
  final bool showPurchaseOrders;
  final bool canManagePurchaseOrders;
  final bool showDocuments;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  late Employee _employee;
  bool _exiting = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _employee = widget.employee;
  }

  @override
  void didUpdateWidget(covariant EmployeeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employee != widget.employee) {
      _employee = widget.employee;
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (!widget.canEdit || _uploadingPhoto) return;
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    setState(() => _uploadingPhoto = true);
    final result = await sl<UpdateEmployeePhotoUseCase>()(
      employeeId: _employee.employeeId,
      bytes: bytes,
      fileName: file.name,
      mimeType: _mimeFor(file.extension, file.name),
    );
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);

    await result.fold(
      (failure) => showAppMessageDialog(
        context,
        title: 'Profile picture',
        message: failure.message,
      ),
      (updated) async {
        setState(() => _employee = updated);
        context.read<EmployeesBloc>().add(const EmployeesRequested());
        if (!mounted) return;
        await showAppMessageDialog(
          context,
          message: 'Profile picture updated',
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

  Future<void> _exitEmployee() async {
    final employee = _employee;
    if (!employee.isActive || _exiting) return;

    var exitDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final formatted = AppDates.compact.format(exitDate);
            return AlertDialog(
              backgroundColor: AppColors.background,
              surfaceTintColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              title: const Text('Exit employee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mark ${employee.employeeName} as exited from the organisation? '
                    'Their login will be disabled.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: exitDate,
                        firstDate: employee.dateOfJoining,
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() => exitDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text('Exit date: $formatted'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Exit employee'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _exiting = true);
    final result = await sl<ExitEmployeeUseCase>()(
      employeeId: employee.employeeId,
      dateOfExit: exitDate,
    );
    if (!mounted) return;
    setState(() => _exiting = false);

    await result.fold(
      (failure) async {
        await showAppMessageDialog(
          context,
          title: 'Exit employee',
          message: failure.message,
        );
      },
      (_) async {
        context.read<EmployeesBloc>().add(const EmployeesRequested());
        await showAppMessageDialog(
          context,
          title: 'Exit employee',
          message:
              '${employee.employeeName} has been exited from the organisation.',
        );
        if (!mounted) return;
        if (widget.embedded) {
          widget.onBack?.call();
        } else {
          context.go(AppRoutes.employees);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    final canEdit = widget.canEdit;
    final isDesktop = Breakpoints.isDesktop(context);
    final dateFormat = AppDates.compact;
    final horizontal = isDesktop ? 32.0 : 16.0;

    final identity = EmployeeDetailSection(
      title: 'Identity',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Employee ID',
          value: employee.employeeId,
        ),
        EmployeeDetailField(
          label: 'Employee name',
          value: employee.employeeName,
        ),
        EmployeeDetailField(
          label: 'Contact no',
          value: employee.contactNo,
        ),
        EmployeeDetailField(
          label: 'Alternate contact',
          value: employee.alternateContact,
        ),
        EmployeeDetailField(
          label: 'Personal email',
          value: employee.personalEmail,
        ),
        EmployeeDetailField(
          label: 'Gender',
          value: employee.gender,
        ),
        EmployeeDetailField(
          label: "Father's name",
          value: employee.fatherName,
        ),
        EmployeeDetailField(
          label: "Mother's name",
          value: employee.motherName,
        ),
        EmployeeDetailField(
          label: 'Nationality',
          value: employee.nationality,
        ),
        EmployeeDetailField(
          label: 'Pincode',
          value: employee.pincode,
        ),
        EmployeeDetailField(
          label: 'Residential address',
          value: employee.residentialAddress,
        ),
      ],
    );

    final role = EmployeeDetailSection(
      title: 'Role & allocation',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'Client',
          value: employee.client,
        ),
        EmployeeDetailField(
          label: 'Designation',
          value: employee.designation,
        ),
        EmployeeDetailField(
          label: 'Department',
          value: employee.department,
        ),
        EmployeeDetailField(
          label: 'Grade',
          value: employee.grade,
        ),
        EmployeeDetailField(
          label: 'Date of joining',
          value: dateFormat.format(employee.dateOfJoining),
        ),
        EmployeeDetailField(
          label: 'Location',
          value: employee.location,
        ),
        EmployeeDetailField(
          label: 'Active',
          value: employee.isActive ? 'Yes' : 'No',
        ),
        if (employee.dateOfExit != null)
          EmployeeDetailField(
            label: 'Date of exit',
            value: dateFormat.format(employee.dateOfExit!),
          ),
      ],
    );

    final compensation = EmployeeDetailSection(
      title: 'Compensation',
      isDesktop: isDesktop,
      trailing: TextButton(
        onPressed: () => context.go(
          AppRoutes.employeeCompensation(employee.employeeId),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.success,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Breakdown',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
        ),
      ),
      children: [
        EmployeeDetailField(
          label: 'Annual CTC',
          value: MoneyFormat.format(employee.annualCtc),
        ),
        EmployeeDetailField(
          label: 'Monthly CTC',
          value: MoneyFormat.format(employee.monthlyCtc),
        ),
        EmployeeDetailField(
          label: 'Client billing',
          value: MoneyFormat.format(employee.monthlyRate),
        ),
        EmployeeDetailField(
          label: 'Medical insurance',
          value: MoneyFormat.format(employee.medicalInsurance),
        ),
        EmployeeDetailField(
          label: 'Retention amount',
          value: MoneyFormat.format(employee.retentionAmount),
        ),
        EmployeeDetailField(
          label: 'TDS (monthly)',
          value: MoneyFormat.format(employee.tdsAmount),
        ),
        EmployeeDetailField(
          label: 'Special allowance',
          value: MoneyFormat.format(employee.specialAllowance),
        ),
      ],
    );

    final compliance = EmployeeDetailSection(
      title: 'Compliance & bank',
      isDesktop: isDesktop,
      children: [
        EmployeeDetailField(
          label: 'PF applicable',
          value: employee.pfApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'PT applicable',
          value: employee.ptApplicable ? 'Yes' : 'No',
        ),
        EmployeeDetailField(
          label: 'PAN',
          value: employee.pan,
        ),
        EmployeeDetailField(
          label: 'UAN',
          value: employee.uan,
        ),
        EmployeeDetailField(
          label: 'Bank A/C',
          value: employee.bankAccount,
        ),
        EmployeeDetailField(
          label: 'IFSC',
          value: employee.ifsc,
        ),
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
                    onTap: canEdit && !_uploadingPhoto
                        ? _pickAndUploadPhoto
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        EmployeeAvatar(
                          name: employee.employeeName,
                          photoUrl: employee.photoUrl,
                          radius: isDesktop ? 44 : 40,
                          fontSize: isDesktop ? 22 : 20,
                        ),
                        if (_uploadingPhoto)
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
                        if (canEdit && !_uploadingPhoto)
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
              EmployeeDetailSectionRow(
                isDesktop: isDesktop,
                left: identity,
                right: role,
              ),
              const SizedBox(height: 12),
              EmployeeDetailSectionRow(
                isDesktop: isDesktop,
                left: compensation,
                right: compliance,
              ),
              if (widget.showDocuments) ...[
                const SizedBox(height: 12),
                EmployeeDocumentsSection(
                  employeeId: employee.employeeId,
                  isDesktop: isDesktop,
                ),
              ],
              if (widget.showPurchaseOrders) ...[
                const SizedBox(height: 12),
                EmployeePurchaseOrdersSection(
                  employeeId: employee.employeeId,
                  isDesktop: isDesktop,
                  canManage: widget.canManagePurchaseOrders,
                ),
              ],
            ],
          ),
        ),
        if (canEdit)
          EmployeeStickyActions(
            children: [
              if (employee.isActive)
                OutlinedButton(
                  onPressed: _exiting ? null : _exitEmployee,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: Text(_exiting ? 'Exiting…' : 'Exit employee'),
                ),
              AppButton(
                label: 'Edit',
                enabled: !_exiting,
                onPressed: () {
                  if (widget.embedded) {
                    widget.onEdit?.call();
                  }
                },
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
  }
}
