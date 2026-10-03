import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_display_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../settings/domain/entities/client.dart';
import '../../domain/entities/employee.dart';
import '../bloc/add_employee/add_employee_bloc.dart';
import '../widgets/employee_form_layout.dart';

class AddEmployeePage extends StatelessWidget {
  const AddEmployeePage({
    super.key,
    this.embedded = false,
    this.employee,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  final Employee? employee;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AddEmployeeBloc>()
        ..add(AddEmployeeStarted(employee: employee)),
      child: _AddEmployeeView(
        embedded: embedded,
        isEditMode: employee != null,
        onCompleted: onCompleted,
        onCancel: onCancel,
      ),
    );
  }
}

class _AddEmployeeView extends StatefulWidget {
  const _AddEmployeeView({
    required this.embedded,
    required this.isEditMode,
    this.onCompleted,
    this.onCancel,
  });

  final bool embedded;
  final bool isEditMode;
  final VoidCallback? onCompleted;
  final VoidCallback? onCancel;

  @override
  State<_AddEmployeeView> createState() => _AddEmployeeViewState();
}

class _AddEmployeeViewState extends State<_AddEmployeeView> {
  final _dateFormat = AppDates.compact;
  final _dojController = TextEditingController();
  final _dobController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _annualCtcController = TextEditingController();
  final _monthlyCtcController = TextEditingController();
  final _medicalController = TextEditingController(text: '650');
  final _retentionController = TextEditingController(text: '2000');
  final _bankController = TextEditingController();
  final _ifscController = TextEditingController();
  final _panController = TextEditingController();
  final _uanController = TextEditingController();
  final _locationController = TextEditingController();
  final _gradeController = TextEditingController();
  bool _hydrated = false;

  void _hydrateControllers(AddEmployeeState state) {
    if (_hydrated) return;
    _hydrated = true;
    if (state.dateOfJoining != null) {
      _dojController.text = _dateFormat.format(state.dateOfJoining!);
    }
    if (state.dateOfBirth != null) {
      _dobController.text = _dateFormat.format(state.dateOfBirth!);
    }
    _employeeIdController.text = state.employeeId;
    _employeeNameController.text = state.employeeName;
    _designationController.text = state.designation;
    _departmentController.text = state.department;
    _annualCtcController.text = state.annualCtc;
    _monthlyCtcController.text = state.monthlyCtc;
    _medicalController.text = state.medicalInsurance;
    _retentionController.text = state.retentionAmount;
    _bankController.text = state.bankAccount;
    _ifscController.text = state.ifsc;
    _panController.text = state.pan;
    _uanController.text = state.uan;
    _locationController.text = state.location;
    _gradeController.text = state.grade;
  }

  @override
  void dispose() {
    _dojController.dispose();
    _dobController.dispose();
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _annualCtcController.dispose();
    _monthlyCtcController.dispose();
    _medicalController.dispose();
    _retentionController.dispose();
    _bankController.dispose();
    _ifscController.dispose();
    _panController.dispose();
    _uanController.dispose();
    _locationController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _pickJoiningDate(
    BuildContext context,
    AddEmployeeState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.dateOfJoining ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.text,
              onPrimary: AppColors.background,
              surface: AppColors.background,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      _dojController.text = _dateFormat.format(picked);
      context.read<AddEmployeeBloc>().add(
            AddEmployeeFieldChanged(dateOfJoining: picked),
          );
    }
  }

  Future<void> _pickBirthDate(
    BuildContext context,
    AddEmployeeState state,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.text,
              onPrimary: AppColors.background,
              surface: AppColors.background,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      _dobController.text = _dateFormat.format(picked);
      context.read<AddEmployeeBloc>().add(
            AddEmployeeFieldChanged(dateOfBirth: picked),
          );
    }
  }

  void _onAnnualCtcChanged(String value) {
    context.read<AddEmployeeBloc>().add(
          AddEmployeeFieldChanged(annualCtc: value),
        );
    final annual = double.tryParse(value.trim());
    if (annual != null) {
      final monthly = (annual / 12).round().toString();
      _monthlyCtcController.text = monthly;
      context.read<AddEmployeeBloc>().add(
            AddEmployeeFieldChanged(monthlyCtc: monthly),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final title = widget.isEditMode ? 'Edit employee' : 'Add employee';

    return BlocConsumer<AddEmployeeBloc, AddEmployeeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.isEditMode != current.isEditMode ||
          previous.employeeId != current.employeeId,
      listener: (context, state) async {
        if (state.employeeId.isNotEmpty &&
            _employeeIdController.text != state.employeeId) {
          _employeeIdController.text = state.employeeId;
        }
        if (state.isEditMode && state.employeeId.isNotEmpty) {
          _hydrateControllers(state);
        }
        if (state.status == AddEmployeeStatus.success) {
          await showAppMessageDialog(
            context,
            message: widget.isEditMode
                ? 'Employee updated successfully'
                : 'Employee added successfully',
          );
          if (!context.mounted) return;
          if (widget.embedded) {
            widget.onCompleted?.call();
          } else {
            Navigator.of(context).pop(true);
          }
        }
      },
      builder: (context, state) {
        if (state.isEditMode && state.employeeId.isNotEmpty && !_hydrated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _hydrateControllers(state);
          });
        }

        final isLoading = state.status == AddEmployeeStatus.loading;
        final body = _buildBody(context, state, isLoading, isDesktop);

        if (widget.embedded) {
          return body;
        }

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AddEmployeeState state,
    bool isLoading,
    bool isDesktop,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final horizontal = isDesktop ? 32.0 : 16.0;

    return Column(
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
              // Full-width form surface (no inset card) so top/bottom chrome
              // and fields share the same main-panel edges.
              ColoredBox(
                color: AppColors.background,
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 28 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EmployeeFormGrid(
                        isDesktop: isDesktop,
                        children: [
                        AppTextField(
                          controller: _employeeIdController,
                          label: 'Employee ID',
                          enabled: false,
                          readOnly: true,
                        ),
                        AppTextField(
                          controller: _employeeNameController,
                          label: 'Employee name',
                          enabled: !isLoading,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      employeeName: value,
                                    ),
                                  ),
                        ),
                        AppDropdown<Client>(
                          label: 'Client',
                          value: state.selectedClient,
                          items: state.availableClients,
                          itemLabel: (item) => item.displayLabel,
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      clientId: value?.id,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          label: 'Date of joining',
                          readOnly: true,
                          enabled: !isLoading,
                          controller: _dojController,
                          hintText: 'Select date',
                          onTap: isLoading
                              ? null
                              : () => _pickJoiningDate(context, state),
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                        AppTextField(
                          label: 'Date of birth',
                          readOnly: true,
                          enabled: !isLoading,
                          controller: _dobController,
                          hintText: 'Select date',
                          onTap: isLoading
                              ? null
                              : () => _pickBirthDate(context, state),
                          suffixIcon: const Icon(
                            Icons.cake_outlined,
                            size: 18,
                            color: AppColors.textLight,
                          ),
                        ),
                        AppTextField(
                          controller: _designationController,
                          label: 'Designation',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      designation: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _departmentController,
                          label: 'Department',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      department: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _annualCtcController,
                          label: 'Annual CTC',
                          prefixText: AppDisplayConfig.currencySymbol,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: _onAnnualCtcChanged,
                        ),
                        AppTextField(
                          controller: _monthlyCtcController,
                          label: 'Monthly CTC',
                          prefixText: AppDisplayConfig.currencySymbol,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(monthlyCtc: value),
                                  ),
                        ),
                        AppDropdown<bool>(
                          label: 'PF applicable',
                          value: state.pfApplicable,
                          items: const [true, false],
                          itemLabel: (item) => item ? 'Yes' : 'No',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      pfApplicable: value,
                                    ),
                                  ),
                        ),
                        AppDropdown<bool>(
                          label: 'PT applicable',
                          value: state.ptApplicable,
                          items: const [true, false],
                          itemLabel: (item) => item ? 'Yes' : 'No',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      ptApplicable: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _medicalController,
                          label: 'Medical insurance',
                          prefixText: AppDisplayConfig.currencySymbol,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      medicalInsurance: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _retentionController,
                          label: 'Retention amount',
                          prefixText: AppDisplayConfig.currencySymbol,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      retentionAmount: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _bankController,
                          label: 'Bank A/C',
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(
                                      bankAccount: value,
                                    ),
                                  ),
                        ),
                        AppTextField(
                          controller: _ifscController,
                          label: 'IFSC',
                          enabled: !isLoading,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(ifsc: value),
                                  ),
                        ),
                        AppTextField(
                          controller: _panController,
                          label: 'PAN',
                          enabled: !isLoading,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(pan: value),
                                  ),
                        ),
                        AppTextField(
                          controller: _uanController,
                          label: 'UAN',
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(uan: value),
                                  ),
                        ),
                        AppDropdown<bool>(
                          label: 'Active',
                          value: state.isActive,
                          items: const [true, false],
                          itemLabel: (item) => item ? 'Yes' : 'No',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(isActive: value),
                                  ),
                        ),
                        AppTextField(
                          controller: _locationController,
                          label: 'Location',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(location: value),
                                  ),
                        ),
                        AppTextField(
                          controller: _gradeController,
                          label: 'Grade',
                          enabled: !isLoading,
                          onChanged: (value) =>
                              context.read<AddEmployeeBloc>().add(
                                    AddEmployeeFieldChanged(grade: value),
                                  ),
                        ),
                      ],
                    ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 16),
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
              ),
            ],
          ),
        ),
        EmployeeStickyActions(
          children: [
            OutlinedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (widget.embedded) {
                        widget.onCancel?.call();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
              child: Text(widget.isEditMode ? 'Back' : 'Cancel'),
            ),
            AppButton(
              label: 'Save',
              isLoading: isLoading,
              onPressed: () => context
                  .read<AddEmployeeBloc>()
                  .add(const AddEmployeeSubmitted()),
            ),
          ],
        ),
      ],
    );
  }
}
