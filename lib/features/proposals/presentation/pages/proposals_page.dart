import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_display_config.dart';
import '../../../../core/config/app_proposal_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../core/widgets/app_list_card.dart';
import '../../../../core/widgets/app_list_search_field.dart';
import '../../../../core/widgets/app_message_dialog.dart';
import '../../../../core/widgets/app_sticky_actions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../hrms/presentation/bloc/employees/employees_bloc.dart';
import '../../../settings/domain/entities/client.dart';
import '../../../settings/presentation/bloc/clients/clients_bloc.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/services/proposal_calculator.dart';
import '../bloc/proposals_bloc.dart';
import '../widgets/proposal_preview_dialog.dart';

class ProposalsPage extends StatelessWidget {
  const ProposalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProposalsBloc>()..add(const ProposalsStarted()),
      child: const _ProposalsBody(),
    );
  }
}

class _ProposalsBody extends StatelessWidget {
  const _ProposalsBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProposalsBloc, ProposalsState>(
      listenWhen: (prev, next) =>
          prev.errorMessage != next.errorMessage && next.errorMessage != null,
      listener: (context, state) {
        final message = state.errorMessage;
        if (message != null) {
          showAppMessageDialog(
            context,
            title: 'Proposals',
            message: message,
          );
        }
      },
      builder: (context, state) {
        if (state.status == ProposalsStatus.initial ||
            (state.status == ProposalsStatus.loading &&
                state.view == ProposalsView.list &&
                state.proposals.isEmpty)) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.text),
          );
        }

        if (state.view == ProposalsView.form) {
          return _ProposalFormView(
            key: ValueKey('proposal-form-${state.editingId ?? state.referenceNo}'),
            state: state,
          );
        }
        return _ProposalList(state: state);
      },
    );
  }
}

class _ProposalList extends StatefulWidget {
  const _ProposalList({required this.state});

  final ProposalsState state;

  @override
  State<_ProposalList> createState() => _ProposalListState();
}

class _ProposalListState extends State<_ProposalList> {
  String _query = '';

  List<Proposal> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.state.proposals;
    return widget.state.proposals.where((p) {
      final party = p.billToCompany.isNotEmpty ? p.billToCompany : p.billToName;
      return p.referenceNo.toLowerCase().contains(q) ||
          party.toLowerCase().contains(q) ||
          p.billToName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final proposals = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            isDesktop ? 8 : 12,
            isDesktop ? 32 : 16,
            12,
          ),
          child: AppListSearchField(
            hintText: 'Search proposals…',
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: widget.state.proposals.isEmpty
              ? Center(
                  child: Text(
                    'No proposals yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                )
              : proposals.isEmpty
                  ? Center(
                      child: Text(
                        'No matching proposals.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textLight,
                            ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 32 : 16,
                        16,
                        isDesktop ? 32 : 16,
                        24,
                      ),
                      itemCount: proposals.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final proposal = proposals[index];
                        return _ProposalCard(
                          proposal: proposal,
                          dateLabel: dateFormat.format(proposal.quoteDate),
                        );
                      },
                    ),
        ),
        AppStickyActions(
          children: [
            AppButton(
              label: 'New proposal',
              onPressed: () => context
                  .read<ProposalsBloc>()
                  .add(const ProposalFormOpened()),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.dateLabel,
  });

  final Proposal proposal;
  final String dateLabel;

  Future<void> _open(BuildContext context) {
    return showProposalPreview(
      context: context,
      proposal: proposal,
      onEdit: () => context.read<ProposalsBloc>().add(
            ProposalEditOpened(proposal),
          ),
      onClone: () => context.read<ProposalsBloc>().add(
            ProposalCloneOpened(proposal),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final party = proposal.billToCompany.isNotEmpty
        ? proposal.billToCompany
        : proposal.billToName;

    return AppListCard(
      onTap: () => _open(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal.referenceNo,
                  style: textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  [party, dateLabel].where((e) => e.isNotEmpty).join(' · '),
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            MoneyFormat.format(proposal.subtotal),
            style: textTheme.titleMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(width: 4),
          AppListIconButton(
            tooltip: 'Edit',
            onPressed: () => context.read<ProposalsBloc>().add(
                  ProposalEditOpened(proposal),
                ),
            icon: Icons.edit_outlined,
          ),
          AppListIconButton(
            tooltip: 'Clone',
            onPressed: () => context.read<ProposalsBloc>().add(
                  ProposalCloneOpened(proposal),
                ),
            icon: Icons.copy_outlined,
          ),
          AppListIconButton(
            tooltip: 'Download PDF',
            onPressed: () => context.read<ProposalsBloc>().add(
                  ProposalDownloadRequested(proposal),
                ),
            icon: Icons.download_outlined,
          ),
        ],
      ),
    );
  }
}

class _ProposalFormView extends StatefulWidget {
  const _ProposalFormView({super.key, required this.state});

  final ProposalsState state;

  @override
  State<_ProposalFormView> createState() => _ProposalFormViewState();
}

class _ProposalFormViewState extends State<_ProposalFormView> {
  late final TextEditingController _reference;
  late final TextEditingController _place;
  late final TextEditingController _vendor;
  late final TextEditingController _entity;
  late final TextEditingController _billName;
  late final TextEditingController _billCompany;
  late final TextEditingController _billAddress;
  late final TextEditingController _billGstin;
  late final TextEditingController _shipName;
  late final TextEditingController _shipCompany;
  late final TextEditingController _shipAddress;
  late final TextEditingController _shipGstin;
  late final TextEditingController _notes;
  late final TextEditingController _quoteDateCtrl;
  late final TextEditingController _expiryDateCtrl;
  late final List<_LineControllers> _lines;
  late DateTime _quoteDate;
  late DateTime _expiryDate;
  Client? _billClient;
  Client? _shipClient;

  final _dateFormat = DateFormat('dd-MM-yyyy');

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _reference = TextEditingController(text: s.referenceNo);
    _place = TextEditingController(text: s.placeOfSupply);
    _vendor = TextEditingController(text: s.vendorCode);
    _entity = TextEditingController(text: s.entityCode);
    _billName = TextEditingController(text: s.billToName);
    _billCompany = TextEditingController(text: s.billToCompany);
    _billAddress = TextEditingController(text: s.billToAddress);
    _billGstin = TextEditingController(text: s.billToGstin);
    _shipName = TextEditingController(text: s.shipToName);
    _shipCompany = TextEditingController(text: s.shipToCompany);
    _shipAddress = TextEditingController(text: s.shipToAddress);
    _shipGstin = TextEditingController(text: s.shipToGstin);
    _notes = TextEditingController(text: s.notes);
    _quoteDate = s.quoteDate ?? DateTime.now();
    _expiryDate = s.expiryDate ?? ProposalCalculator.defaultExpiry(_quoteDate);
    _quoteDateCtrl = TextEditingController(text: _dateFormat.format(_quoteDate));
    _expiryDateCtrl =
        TextEditingController(text: _dateFormat.format(_expiryDate));
    _lines = [
      for (final line in s.draftLines)
        _LineControllers(
          description: TextEditingController(text: line.description),
          monthlyRate: TextEditingController(text: line.monthlyRate),
          months: TextEditingController(text: line.months),
          days: TextEditingController(text: line.days),
        ),
    ];
    if (_lines.isEmpty) {
      _lines.add(_LineControllers.empty());
    }
  }

  @override
  void dispose() {
    _reference.dispose();
    _place.dispose();
    _vendor.dispose();
    _entity.dispose();
    _billName.dispose();
    _billCompany.dispose();
    _billAddress.dispose();
    _billGstin.dispose();
    _shipName.dispose();
    _shipCompany.dispose();
    _shipAddress.dispose();
    _shipGstin.dispose();
    _notes.dispose();
    _quoteDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _submit() {
    context.read<ProposalsBloc>().add(
          ProposalSubmitted(
            referenceNo: _reference.text,
            quoteDate: _quoteDate,
            expiryDate: _expiryDate,
            placeOfSupply: _place.text,
            vendorCode: _vendor.text,
            entityCode: _entity.text,
            billToName: _billName.text,
            billToCompany: _billCompany.text,
            billToAddress: _billAddress.text,
            billToGstin: _billGstin.text,
            shipToName: _shipName.text,
            shipToCompany: _shipCompany.text,
            shipToAddress: _shipAddress.text,
            shipToGstin: _shipGstin.text,
            notes: _notes.text,
            lines: [
              for (final line in _lines)
                DraftLine(
                  description: line.description.text,
                  monthlyRate: line.monthlyRate.text,
                  months: line.months.text,
                  days: line.days.text,
                ),
            ],
          ),
        );
  }

  Proposal _draftProposal() {
    final lines = <ProposalLineItem>[];
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final rate = double.tryParse(line.monthlyRate.text.trim()) ?? 0;
      final months = int.tryParse(line.months.text.trim()) ?? 0;
      final days = int.tryParse(line.days.text.trim()) ?? 0;
      final total = ProposalCalculator.lineTotal(
        monthlyRate: rate,
        months: months,
        days: days,
      );
      lines.add(
        ProposalLineItem(
          id: 'preview_line_$i',
          description: line.description.text.trim(),
          monthlyRate: rate,
          months: months,
          days: days,
          totalRate: total,
          sortOrder: i,
        ),
      );
    }
    final subtotal = ProposalCalculator.subtotal(lines);
    return Proposal(
      id: 'preview',
      referenceNo: _reference.text.trim(),
      quoteDate: _quoteDate,
      expiryDate: _expiryDate,
      placeOfSupply: _place.text.trim(),
      vendorCode: _vendor.text.trim(),
      entityCode: _entity.text.trim(),
      billToName: _billName.text.trim(),
      billToCompany: _billCompany.text.trim(),
      billToAddress: _billAddress.text.trim(),
      billToGstin: _billGstin.text.trim(),
      shipToName: _shipName.text.trim(),
      shipToCompany: _shipCompany.text.trim(),
      shipToAddress: _shipAddress.text.trim(),
      shipToGstin: _shipGstin.text.trim(),
      notes: _notes.text.trim(),
      lineItems: lines,
      subtotal: subtotal,
      totalInWords: ProposalCalculator.amountInWords(subtotal),
    );
  }

  Future<void> _preview() async {
    await showProposalPreview(
      context: context,
      proposal: _draftProposal(),
    );
  }

  Future<void> _pickDate({required bool expiry}) async {
    final initial = expiry ? _expiryDate : _quoteDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (expiry) {
        _expiryDate = picked;
        _expiryDateCtrl.text = _dateFormat.format(picked);
      } else {
        _quoteDate = picked;
        _quoteDateCtrl.text = _dateFormat.format(picked);
        _expiryDate = ProposalCalculator.defaultExpiry(picked);
        _expiryDateCtrl.text = _dateFormat.format(_expiryDate);
      }
    });
  }

  void _applyBillClient(Client? client) {
    setState(() {
      _billClient = client;
      if (client == null) {
        for (final line in _lines) {
          line.selectedEmployee = null;
        }
        return;
      }
      _vendor.text = client.vendorCode;
      _entity.text = client.entityCode;
      _billCompany.text = client.name;
      _billName.text = client.contactName;
      _billAddress.text = client.address;
      _billGstin.text = client.gstin;
      for (final line in _lines) {
        final selected = line.selectedEmployee;
        if (selected != null &&
            !_employeeMatchesClient(selected, client)) {
          line.selectedEmployee = null;
          line.description.clear();
        }
      }
    });
  }

  bool _employeeMatchesClient(Employee employee, Client client) {
    if (employee.clientId.isNotEmpty && employee.clientId == client.id) {
      return true;
    }
    return employee.client.trim().toLowerCase() == client.name.trim().toLowerCase();
  }

  List<Employee> _candidatesForClient(Client? client, List<Employee> employees) {
    if (client == null) return const [];
    return employees
        .where((e) => e.isActive && _employeeMatchesClient(e, client))
        .toList()
      ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
  }

  void _applyCandidate(int index, Employee? employee) {
    setState(() {
      final line = _lines[index];
      line.selectedEmployee = employee;
      if (employee == null) {
        return;
      }
      final designation = employee.designation.trim();
      line.description.text = designation.isEmpty
          ? employee.employeeName
          : '${employee.employeeName} - $designation';
      line.description.selection = TextSelection.collapsed(
        offset: line.description.text.length,
      );
      if (employee.monthlyCtc > 0) {
        line.monthlyRate.text = employee.monthlyCtc.round().toString();
      }
    });
  }

  String _candidateLabel(Employee employee) {
    final designation = employee.designation.trim();
    if (designation.isEmpty) return employee.employeeName;
    return '${employee.employeeName} - $designation';
  }

  Widget _itemDescriptionField({
    required int index,
    required bool saving,
    required List<Employee> candidates,
  }) {
    final line = _lines[index];
    final canPick = !saving && candidates.isNotEmpty;

    return AppTextField(
      label: 'Item & description',
      controller: line.description,
      enabled: !saving,
      hintText: canPick
          ? 'Type freely or pick a candidate'
          : 'Type item description',
      onChanged: (_) {
        if (line.selectedEmployee != null) {
          setState(() => line.selectedEmployee = null);
        } else {
          setState(() {});
        }
      },
      suffixIcon: canPick
          ? PopupMenuButton<Employee>(
              tooltip: 'Select candidate',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: AppColors.textLight,
              ),
              onSelected: (employee) => _applyCandidate(index, employee),
              itemBuilder: (context) => [
                for (final employee in candidates)
                  PopupMenuItem<Employee>(
                    value: employee,
                    child: Text(_candidateLabel(employee)),
                  ),
              ],
            )
          : null,
    );
  }

  void _applyShipClient(Client? client) {
    setState(() {
      _shipClient = client;
      if (client == null) return;
      _shipCompany.text = client.name;
      _shipName.text = client.contactName;
      _shipAddress.text = client.address;
      _shipGstin.text = client.gstin;
    });
  }

  void _copyBillToShip() {
    setState(() {
      _shipClient = _billClient;
      _shipName.text = _billName.text;
      _shipCompany.text = _billCompany.text;
      _shipAddress.text = _billAddress.text;
      _shipGstin.text = _billGstin.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Breakpoints.isDesktop(context);
    final saving = widget.state.status == ProposalsStatus.saving;
    final horizontal = isDesktop ? 32.0 : 16.0;
    final clients = context.watch<ClientsBloc>().state.clients;
    final employees = context.watch<EmployeesBloc>().state.employees;
    final billClient = _resolveClient(_billClient, clients);
    final shipClient = _resolveClient(_shipClient, clients);
    final candidates = _candidatesForClient(billClient, employees);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: saving
                  ? null
                  : () => context
                      .read<ProposalsBloc>()
                      .add(const ProposalListRequested()),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to list'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textLight),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32),
            children: [
              _card(
                context,
                title: 'Quote details',
                child: _grid(isDesktop, [
                  AppTextField(
                    label: 'Reference No',
                    controller: _reference,
                    enabled: !saving,
                    onChanged: (_) => setState(() {}),
                  ),
                  AppTextField(
                    label: 'Place of Supply',
                    controller: _place,
                    enabled: !saving,
                  ),
                  AppTextField(
                    label: 'Quote Date',
                    controller: _quoteDateCtrl,
                    readOnly: true,
                    enabled: !saving,
                    onTap: saving ? null : () => _pickDate(expiry: false),
                  ),
                  AppTextField(
                    label: 'Vendor Code',
                    controller: _vendor,
                    enabled: !saving,
                    hintText: 'From client or type',
                  ),
                  AppTextField(
                    label: 'Expiry Date',
                    controller: _expiryDateCtrl,
                    readOnly: true,
                    enabled: !saving,
                    onTap: saving ? null : () => _pickDate(expiry: true),
                  ),
                  AppTextField(
                    label: 'Entity Code',
                    controller: _entity,
                    enabled: !saving,
                    hintText: 'From client or type',
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (isDesktop)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _partyCard(
                          context,
                          title: 'Bill To',
                          trailing: TextButton(
                            onPressed: saving ? null : _copyBillToShip,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppColors.textLight,
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: const Text('Copy to Ship To'),
                          ),
                          clientValue: billClient,
                          clients: clients,
                          onClientChanged: saving ? null : _applyBillClient,
                          saving: saving,
                          name: _billName,
                          company: _billCompany,
                          address: _billAddress,
                          gstin: _billGstin,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _partyCard(
                          context,
                          title: 'Ship To',
                          clientValue: shipClient,
                          clients: clients,
                          onClientChanged: saving ? null : _applyShipClient,
                          saving: saving,
                          name: _shipName,
                          company: _shipCompany,
                          address: _shipAddress,
                          gstin: _shipGstin,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _partyCard(
                  context,
                  title: 'Bill To',
                  trailing: TextButton(
                    onPressed: saving ? null : _copyBillToShip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.textLight,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Copy to Ship To'),
                  ),
                  clientValue: billClient,
                  clients: clients,
                  onClientChanged: saving ? null : _applyBillClient,
                  saving: saving,
                  name: _billName,
                  company: _billCompany,
                  address: _billAddress,
                  gstin: _billGstin,
                ),
                const SizedBox(height: 12),
                _partyCard(
                  context,
                  title: 'Ship To',
                  clientValue: shipClient,
                  clients: clients,
                  onClientChanged: saving ? null : _applyShipClient,
                  saving: saving,
                  name: _shipName,
                  company: _shipCompany,
                  address: _shipAddress,
                  gstin: _shipGstin,
                ),
              ],
              const SizedBox(height: 12),
              _card(
                context,
                title: 'Line items',
                trailing: TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                            _lines.add(_LineControllers.empty());
                            context
                                .read<ProposalsBloc>()
                                .add(const ProposalLineAdded());
                          }),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line'),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _lines.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _buildLine(
                        i,
                        saving,
                        isDesktop,
                        candidates: candidates,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                title: AppProposalConfig.notesHeading,
                child: AppTextField(
                  label: 'Notes',
                  controller: _notes,
                  enabled: !saving,
                  maxLines: 6,
                ),
              ),
            ],
          ),
        ),
        AppStickyActions(
          children: [
            OutlinedButton(
              onPressed: saving ? null : _preview,
              child: const Text('Preview'),
            ),
            AppButton(
              label: widget.state.isEditing ? 'Update proposal' : 'Save proposal',
              isLoading: saving,
              enabled: !saving,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  Client? _resolveClient(Client? selected, List<Client> clients) {
    if (selected == null) return null;
    for (final client in clients) {
      if (client.id == selected.id) return client;
    }
    return null;
  }

  Widget _partyCard(
    BuildContext context, {
    required String title,
    Widget? trailing,
    required Client? clientValue,
    required List<Client> clients,
    required ValueChanged<Client?>? onClientChanged,
    required bool saving,
    required TextEditingController name,
    required TextEditingController company,
    required TextEditingController address,
    required TextEditingController gstin,
  }) {
    return _card(
      context,
      title: title,
      trailing: trailing,
      child: Column(
        children: [
          AppDropdown<Client>(
            label: 'Client',
            value: clientValue,
            items: clients,
            itemLabel: (item) => item.displayLabel,
            enabled: !saving,
            hintText: 'Select client or type below',
            onChanged: onClientChanged,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Contact name',
            controller: name,
            enabled: !saving,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Company',
            controller: company,
            enabled: !saving,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Address',
            controller: address,
            enabled: !saving,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'GSTIN',
            controller: gstin,
            enabled: !saving,
          ),
        ],
      ),
    );
  }

  Widget _buildLine(
    int index,
    bool saving,
    bool isDesktop, {
    required List<Employee> candidates,
  }) {
    final line = _lines[index];
    final total = ProposalCalculator.lineTotal(
      monthlyRate: double.tryParse(line.monthlyRate.text.trim()) ?? 0,
      months: int.tryParse(line.months.text.trim()) ?? 0,
      days: int.tryParse(line.days.text.trim()) ?? 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Line ${index + 1}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textLight,
                    ),
              ),
              const Spacer(),
              Text(
                'Total ${MoneyFormat.format(total)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                    ),
              ),
              if (_lines.length > 1)
                IconButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                            _lines.removeAt(index).dispose();
                            context
                                .read<ProposalsBloc>()
                                .add(ProposalLineRemoved(index));
                          }),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _itemDescriptionField(
            index: index,
            saving: saving,
            candidates: candidates,
          ),
          const SizedBox(height: 10),
          if (isDesktop)
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Monthly rate',
                    controller: line.monthlyRate,
                    enabled: !saving,
                    prefixText: AppDisplayConfig.currencySymbol,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'No of months',
                    controller: line.months,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    label: 'No of days',
                    controller: line.days,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                AppTextField(
                  label: 'Monthly rate',
                  controller: line.monthlyRate,
                  enabled: !saving,
                  prefixText: AppDisplayConfig.currencySymbol,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  label: 'No of months',
                  controller: line.months,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  label: 'No of days',
                  controller: line.days,
                  enabled: !saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
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
          SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.highlight,
                          height: 1.2,
                        ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _grid(bool isDesktop, List<Widget> children) {
    if (!isDesktop) {
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _LineControllers {
  _LineControllers({
    required this.description,
    required this.monthlyRate,
    required this.months,
    required this.days,
  });

  factory _LineControllers.empty() {
    return _LineControllers(
      description: TextEditingController(),
      monthlyRate: TextEditingController(),
      months: TextEditingController(text: '1'),
      days: TextEditingController(text: '0'),
    );
  }

  final TextEditingController description;
  final TextEditingController monthlyRate;
  final TextEditingController months;
  final TextEditingController days;
  Employee? selectedEmployee;

  void dispose() {
    description.dispose();
    monthlyRate.dispose();
    months.dispose();
    days.dispose();
  }
}
