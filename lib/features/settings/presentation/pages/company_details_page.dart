import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../hrms/presentation/widgets/employee_form_layout.dart';
import '../../domain/entities/settings_entities.dart';
import '../bloc/company_details/company_details_bloc.dart';

class CompanyDetailsPage extends StatelessWidget {
  const CompanyDetailsPage({
    super.key,
    this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<CompanyDetailsBloc>()..add(const CompanyDetailsStarted()),
      child: _CompanyDetailsBody(onBack: onBack),
    );
  }
}

class _CompanyDetailsBody extends StatefulWidget {
  const _CompanyDetailsBody({this.onBack});

  final VoidCallback? onBack;

  @override
  State<_CompanyDetailsBody> createState() => _CompanyDetailsBodyState();
}

class _CompanyDetailsBodyState extends State<_CompanyDetailsBody> {
  final _displayName = TextEditingController();
  final _address = TextEditingController();
  final _gstin = TextEditingController();
  final _pan = TextEditingController();
  final _sac = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  final _bankName = TextEditingController();
  final _account = TextEditingController();
  final _branch = TextEditingController();
  final _ifsc = TextEditingController();
  String? _boundId;

  @override
  void dispose() {
    _displayName.dispose();
    _address.dispose();
    _gstin.dispose();
    _pan.dispose();
    _sac.dispose();
    _tel.dispose();
    _email.dispose();
    _bankName.dispose();
    _account.dispose();
    _branch.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  void _bind(CompanyDetails details) {
    if (_boundId == details.id && _displayName.text.isNotEmpty) return;
    _boundId = details.id;
    _displayName.text = details.displayName;
    _address.text = details.address;
    _gstin.text = details.gstin;
    _pan.text = details.pan;
    _sac.text = details.sacCode;
    _tel.text = details.telephone;
    _email.text = details.email;
    _bankName.text = details.bankName;
    _account.text = details.bankAccountNo;
    _branch.text = details.bankBranch;
    _ifsc.text = details.bankIfsc;
  }

  void _pushFields(BuildContext context) {
    context.read<CompanyDetailsBloc>().add(
          CompanyDetailsFieldChanged(
            displayName: _displayName.text,
            address: _address.text,
            gstin: _gstin.text,
            pan: _pan.text,
            sacCode: _sac.text,
            telephone: _tel.text,
            email: _email.text,
            bankName: _bankName.text,
            bankAccountNo: _account.text,
            bankBranch: _branch.text,
            bankIfsc: _ifsc.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final horizontal = isDesktop ? 32.0 : 16.0;

    return BlocConsumer<CompanyDetailsBloc, CompanyDetailsState>(
      listenWhen: (prev, next) =>
          (prev.status != next.status &&
              next.status == CompanyDetailsStatus.success) ||
          (prev.details?.id != next.details?.id && next.details != null),
      listener: (context, state) async {
        final details = state.details;
        if (details != null) _bind(details);
        if (state.status == CompanyDetailsStatus.success) {
          await showAppMessageDialog(
            context,
            message: 'Company details saved',
          );
        }
      },
      builder: (context, state) {
        if (state.status == CompanyDetailsStatus.initial ||
            state.status == CompanyDetailsStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        final details = state.details;
        if (details == null) {
          return Center(
            child: Text(
              state.errorMessage ?? 'Company details unavailable.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.error),
            ),
          );
        }

        if (_boundId != details.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _bind(details);
          });
        }

        final saving = state.status == CompanyDetailsStatus.saving;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 24),
                children: [
                  Text(
                    'GST & identity',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textLight,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Display name',
                    controller: _displayName,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Address',
                    controller: _address,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'GSTIN',
                    controller: _gstin,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'PAN',
                    controller: _pan,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'SAC code',
                    controller: _sac,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Telephone',
                    controller: _tel,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bank details',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textLight,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Bank name',
                    controller: _bankName,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Account number',
                    controller: _account,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Branch',
                    controller: _branch,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'IFSC',
                    controller: _ifsc,
                    enabled: !saving,
                    onChanged: (_) => _pushFields(context),
                  ),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            EmployeeStickyActions(
              children: [
                OutlinedButton(
                  onPressed: saving ? null : widget.onBack,
                  child: const Text('Back'),
                ),
                AppButton(
                  label: saving ? 'Saving…' : 'Save',
                  isLoading: saving,
                  enabled: !saving,
                  onPressed: () {
                    _pushFields(context);
                    context
                        .read<CompanyDetailsBloc>()
                        .add(const CompanyDetailsSubmitted());
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
