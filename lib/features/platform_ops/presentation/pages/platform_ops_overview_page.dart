import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/platform_ops/platform_ops_session.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../injection_container.dart';

enum _OpsView {
  overview,
  users,
  companies,
  plans,
  planCompanies,
  companyUsers,
}

/// Soft charcoal for table column headers (not pure black).
const _opsTableHeaderBg = Color(0xFF2E2E2E);

/// Black / white platform owner console — full-width, minimal.
class PlatformOpsOverviewPage extends StatefulWidget {
  const PlatformOpsOverviewPage({super.key});

  @override
  State<PlatformOpsOverviewPage> createState() =>
      _PlatformOpsOverviewPageState();
}

class _PlatformOpsOverviewPageState extends State<PlatformOpsOverviewPage> {
  static const _password = 'ihateluvstories';
  static const _black = Color(0xFF0A0A0A);
  static const _white = Color(0xFFFFFFFF);
  static const _line = Color(0xFFE5E5E5);

  static final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = const {};
  _OpsView _view = _OpsView.overview;
  String? _appVersion;
  String? _focusPlanCode;
  String? _focusPlanName;
  String? _focusCompanyId;
  String? _focusCompanyName;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _load();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      // Non-fatal — dashboard still works without version.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client.rpc(
        'platform_ops_snapshot',
        params: {'p_password': _password},
      );
      if (!mounted) return;
      if (raw is! Map) throw StateError('Unexpected response');
      setState(() {
        _data = Map<String, dynamic>.from(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _applySnapshot(dynamic raw) async {
    if (raw is! Map) throw StateError('Unexpected response');
    if (!mounted) return;
    setState(() => _data = Map<String, dynamic>.from(raw));
  }

  Future<void> _updatePlan({
    required String code,
    required String name,
    required double priceInr,
    required int employeeLimit,
  }) async {
    final raw = await Supabase.instance.client.rpc(
      'platform_ops_update_plan',
      params: {
        'p_password': _password,
        'p_code': code,
        'p_name': name,
        'p_price_inr': priceInr,
        'p_employee_limit': employeeLimit,
      },
    );
    await _applySnapshot(raw);
  }

  Future<void> _setLivePlan(String code) async {
    final raw = await Supabase.instance.client.rpc(
      'platform_ops_set_live_plan',
      params: {
        'p_password': _password,
        'p_plan_code': code,
      },
    );
    await _applySnapshot(raw);
  }

  Future<void> _setPlanActive({
    required String code,
    required bool isActive,
  }) async {
    final raw = await Supabase.instance.client.rpc(
      'platform_ops_set_plan_active',
      params: {
        'p_password': _password,
        'p_code': code,
        'p_is_active': isActive,
      },
    );
    await _applySnapshot(raw);
  }

  Future<void> _createCompany({
    required String displayName,
    String? planCode,
    String? email,
  }) async {
    final raw = await Supabase.instance.client.rpc(
      'platform_ops_create_company',
      params: {
        'p_password': _password,
        'p_display_name': displayName,
        'p_name': null,
        'p_plan_code': (planCode ?? 'free').trim().isEmpty
            ? 'free'
            : planCode!.trim(),
        'p_email': email,
        'p_telephone': null,
      },
    );
    await _applySnapshot(raw);
  }

  Future<void> _inviteCompanyOwner({
    required String companyId,
    required String email,
    String? fullName,
  }) async {
    final prepared = await Supabase.instance.client.rpc(
      'platform_ops_prepare_owner_invite',
      params: {
        'p_password': _password,
        'p_company_id': companyId,
        'p_email': email,
        'p_full_name': fullName,
      },
    );
    if (prepared is! Map) throw StateError('Invite prepare failed');
    final meta = Map<String, dynamic>.from(
      (prepared['invite_metadata'] as Map?) ?? prepared,
    );
    final roleId = (meta['role_id'] ?? prepared['role_id'] ?? '').toString();
    final body = <String, dynamic>{
      'action': 'invite',
      'source': 'platform_ops',
      'email': email.trim().toLowerCase(),
      'fullName': (fullName ?? '').trim(),
      'company_id': companyId,
      'member_role': 'owner',
      if (roleId.isNotEmpty) 'roleId': roleId,
      if (AppConfig.inviteRedirectUrl.isNotEmpty)
        'redirectTo': AppConfig.inviteRedirectUrl,
    };
    final res = await Supabase.instance.client.functions.invoke(
      'invite-employee',
      body: body,
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw StateError(data['error'].toString());
    }
  }

  Future<void> _showCreateCompanyDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String plan = 'free';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Create company'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppTextField(
                      controller: nameCtrl,
                      label: 'Display name',
                      hintText: 'Acme Pvt Ltd',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: emailCtrl,
                      label: 'Billing email (optional)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use — controlled value in StatefulBuilder
                      value: plan,
                      decoration: const InputDecoration(
                        labelText: 'Plan',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'free', child: Text('Free')),
                        DropdownMenuItem(
                          value: 'starter',
                          child: Text('Starter'),
                        ),
                        DropdownMenuItem(
                          value: 'growth',
                          child: Text('Growth'),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => plan = v ?? 'free'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    final displayName = nameCtrl.text.trim();
    nameCtrl.dispose();
    final email = emailCtrl.text.trim();
    emailCtrl.dispose();
    if (ok != true || displayName.isEmpty) return;
    try {
      await _createCompany(
        displayName: displayName,
        planCode: plan,
        email: email.isEmpty ? null : email,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created $displayName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _showInviteOwnerDialog(Map<String, dynamic> company) async {
    final companyId = (company['id'] ?? '').toString();
    if (companyId.isEmpty) return;
    final display = (company['display_name']?.toString().trim().isNotEmpty ==
            true)
        ? company['display_name'].toString()
        : (company['name']?.toString() ?? 'Company');
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invite owner · $display'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: emailCtrl,
                label: 'Owner email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: nameCtrl,
                label: 'Full name (optional)',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send invite'),
          ),
        ],
      ),
    );
    final email = emailCtrl.text.trim().toLowerCase();
    final fullName = nameCtrl.text.trim();
    emailCtrl.dispose();
    nameCtrl.dispose();
    if (ok != true || email.isEmpty) return;
    try {
      await _inviteCompanyOwner(
        companyId: companyId,
        email: email,
        fullName: fullName.isEmpty ? null : fullName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  void _openPlanCompanies(Map<String, dynamic> plan) {
    setState(() {
      _focusPlanCode = (plan['plan_code'] ?? '').toString();
      _focusPlanName = (plan['plan_name'] ?? _focusPlanCode).toString();
      _focusCompanyId = null;
      _focusCompanyName = null;
      _view = _OpsView.planCompanies;
    });
  }

  void _openCompanyUsers({
    required String companyId,
    required String companyName,
    required _OpsView backTo,
  }) {
    setState(() {
      _focusCompanyId = companyId;
      _focusCompanyName = companyName;
      _view = _OpsView.companyUsers;
      // Remember where company drill-down came from via focusPlan when from plan.
      if (backTo == _OpsView.companies) {
        _focusPlanCode = null;
        _focusPlanName = null;
      }
    });
  }

  List<Map<String, dynamic>> _companiesForPlan(String? planCode) {
    if (planCode == null || planCode.isEmpty) return const [];
    return [
      for (final c in _list('companies'))
        if ((c['plan_code'] ?? '').toString() == planCode) c,
    ];
  }

  List<Map<String, dynamic>> _usersForCompany(String? companyId) {
    if (companyId == null || companyId.isEmpty) return const [];
    return [
      for (final u in _list('users'))
        if ((u['company_id'] ?? '').toString() == companyId) u,
    ];
  }

  void _lock() {
    sl<PlatformOpsSession>().lock();
    context.go(AppRoutes.login);
  }

  int _n(String key) {
    final v = _data[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _data[key];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: _white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 14, wide ? 48 : 20, 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/saasify_logo.png',
                    height: 36,
                    fit: BoxFit.contain,
                    semanticLabel: 'Saasify',
                  ),
                  if (_appVersion != null) ...[
                    const SizedBox(width: 14),
                    Text(
                      'v$_appVersion',
                      style: const TextStyle(
                        color: Color(0xFF737373),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _BwButton(
                    label: 'Refresh',
                    outlined: true,
                    onPressed: _loading ? null : _load,
                  ),
                  const SizedBox(width: 10),
                  _BwButton(
                    label: 'Lock',
                    onPressed: _lock,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _black,
                      ),
                    ),
                  )
                : _error != null
                    ? _ErrorBody(message: _error!, onRetry: _load)
                    : switch (_view) {
                        _OpsView.overview => _OverviewBody(
                            wide: wide,
                            appVersion: _appVersion,
                            usersActive: _n('users_active'),
                            usersTotal: _n('users_total'),
                            joinedToday: _n('users_joined_today'),
                            companiesTotal: _n('companies_total'),
                            livePlanName:
                                (_data['live_plan_name'] ?? '').toString(),
                            livePlanCode:
                                (_data['live_plan_code'] ?? '').toString(),
                            liveStatus:
                                (_data['live_status'] ?? '').toString(),
                            plans: _list('plans'),
                            onUsersTap: () =>
                                setState(() => _view = _OpsView.users),
                            onCompaniesTap: () =>
                                setState(() => _view = _OpsView.companies),
                            onPlansTap: () =>
                                setState(() => _view = _OpsView.plans),
                          ),
                        _OpsView.users => _UsersTableView(
                            users: _list('users'),
                            dateFmt: _dateFmt,
                            wide: wide,
                            onBack: () =>
                                setState(() => _view = _OpsView.overview),
                          ),
                        _OpsView.companies => _CompaniesTableView(
                            companies: _list('companies'),
                            dateFmt: _dateFmt,
                            wide: wide,
                            subtitle:
                                'Sayge is the first Saasify client · create companies & invite owners',
                            onBack: () =>
                                setState(() => _view = _OpsView.overview),
                            onCreateCompany: _showCreateCompanyDialog,
                            onInviteOwner: _showInviteOwnerDialog,
                            onCompanyTap: (c) {
                              final id = (c['id'] ?? '').toString();
                              if (id.isEmpty) return;
                              final display =
                                  (c['display_name']?.toString().trim().isNotEmpty ==
                                          true)
                                      ? c['display_name'].toString()
                                      : (c['name']?.toString() ?? 'Company');
                              _openCompanyUsers(
                                companyId: id,
                                companyName: display,
                                backTo: _OpsView.companies,
                              );
                            },
                          ),
                        _OpsView.plans => _PlansManageView(
                            plans: _list('plans'),
                            livePlanCode:
                                (_data['live_plan_code'] ?? '').toString(),
                            livePlanName:
                                (_data['live_plan_name'] ?? '').toString(),
                            liveStatus:
                                (_data['live_status'] ?? '').toString(),
                            wide: wide,
                            onBack: () =>
                                setState(() => _view = _OpsView.overview),
                            onUpdatePlan: _updatePlan,
                            onSetLivePlan: _setLivePlan,
                            onSetPlanActive: _setPlanActive,
                            onOpenPlan: _openPlanCompanies,
                          ),
                        _OpsView.planCompanies => _CompaniesTableView(
                            companies: _companiesForPlan(_focusPlanCode),
                            dateFmt: _dateFmt,
                            wide: wide,
                            title: _focusPlanName ?? 'Plan',
                            subtitle:
                                'Companies on ${_focusPlanName ?? 'this plan'} · tap to view users',
                            onBack: () => setState(() {
                              _view = _OpsView.plans;
                              _focusCompanyId = null;
                              _focusCompanyName = null;
                            }),
                            onCompanyTap: (c) {
                              final id = (c['id'] ?? '').toString();
                              if (id.isEmpty) return;
                              final display =
                                  (c['display_name']?.toString().trim().isNotEmpty ==
                                          true)
                                      ? c['display_name'].toString()
                                      : (c['name']?.toString() ?? 'Company');
                              _openCompanyUsers(
                                companyId: id,
                                companyName: display,
                                backTo: _OpsView.planCompanies,
                              );
                            },
                          ),
                        _OpsView.companyUsers => _UsersTableView(
                            users: _usersForCompany(_focusCompanyId),
                            dateFmt: _dateFmt,
                            wide: wide,
                            title: _focusCompanyName ?? 'Users',
                            subtitle:
                                'Users in ${_focusCompanyName ?? 'this company'}',
                            onBack: () => setState(() {
                              _view = _focusPlanCode != null
                                  ? _OpsView.planCompanies
                                  : _OpsView.companies;
                              _focusCompanyId = null;
                              _focusCompanyName = null;
                            }),
                          ),
                      },
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.wide,
    required this.appVersion,
    required this.usersActive,
    required this.usersTotal,
    required this.joinedToday,
    required this.companiesTotal,
    required this.livePlanName,
    required this.livePlanCode,
    required this.liveStatus,
    required this.plans,
    required this.onUsersTap,
    required this.onCompaniesTap,
    required this.onPlansTap,
  });

  final bool wide;
  final String? appVersion;
  final int usersActive;
  final int usersTotal;
  final int joinedToday;
  final int companiesTotal;
  final String livePlanName;
  final String livePlanCode;
  final String liveStatus;
  final List<Map<String, dynamic>> plans;
  final VoidCallback onUsersTap;
  final VoidCallback onCompaniesTap;
  final VoidCallback onPlansTap;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    final liveLabel = livePlanName.isNotEmpty
        ? livePlanName
        : (livePlanCode.isNotEmpty ? livePlanCode : '—');
    final versionBit =
        (appVersion != null && appVersion!.isNotEmpty) ? 'v$appVersion' : null;
    final subtitleParts = <String>[
      if (versionBit != null) 'Live $versionBit',
      if (liveLabel != '—') 'Plan $liveLabel',
      'this deployment',
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 48 : 16, wide ? 36 : 20, wide ? 48 : 16, wide ? 48 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              color: _black,
              fontWeight: FontWeight.w700,
              fontSize: wide ? 36 : 28,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitleParts.join(' · '),
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _MetricTile(
                  label: 'Users using this',
                  value: '$usersActive',
                  hint: '$usersTotal accounts total · tap to view',
                  onTap: onUsersTap,
                ),
                _MetricTile(
                  label: 'Companies',
                  value: '$companiesTotal',
                  hint: 'Tap to view companies',
                  onTap: onCompaniesTap,
                ),
                _MetricTile(
                  label: 'Live plan',
                  value: liveLabel,
                  valueSize: liveLabel.length > 8 ? 36 : 48,
                  hint: liveStatus.isNotEmpty
                      ? '${liveStatus.toUpperCase()} · tap to manage pricing'
                      : 'Tap to manage pricing',
                  onTap: onPlansTap,
                ),
                _MetricTile(
                  label: 'New users today',
                  value: '$joinedToday',
                  hint: 'Created since midnight',
                ),
              ];
              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              if (constraints.maxWidth >= 640) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: cards[2]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[3]),
                      ],
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    cards[i],
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 48),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plans',
                      style: TextStyle(
                        color: _black,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Catalog pricing and seat limits',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onPlansTap,
                style: TextButton.styleFrom(
                  foregroundColor: _black,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Manage →',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (plans.isEmpty)
            const Text(
              'No billing data yet. Apply billing_closed_beta.sql.',
              style: TextStyle(color: _muted, fontSize: 14),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: cols == 1 ? 3.2 : 2.4,
                  children: [
                    for (final p in plans)
                      _PlanTile(
                        name: (p['plan_name'] ?? p['plan_code']).toString(),
                        count: _planCount(p),
                        meta: '₹${_price(p)}/mo · ${_limit(p)} emp',
                        isLive: p['is_live'] == true,
                        onTap: onPlansTap,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  static int _planCount(Map<String, dynamic> p) {
    final c = p['subscriptions'];
    if (c is int) return c;
    if (c is num) return c.toInt();
    return int.tryParse('$c') ?? 0;
  }

  static String _price(Map<String, dynamic> p) {
    final v = p['price_inr'];
    if (v is num) {
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(0);
    }
    return '0';
  }

  static String _limit(Map<String, dynamic> p) {
    final v = p['employee_limit'];
    if (v is int) return '$v';
    if (v is num) return '${v.toInt()}';
    return '$v';
  }
}

class _UsersTableView extends StatefulWidget {
  const _UsersTableView({
    required this.users,
    required this.dateFmt,
    required this.wide,
    required this.onBack,
    this.title = 'Users',
    this.subtitle,
  });

  final List<Map<String, dynamic>> users;
  final DateFormat dateFmt;
  final bool wide;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;

  @override
  State<_UsersTableView> createState() => _UsersTableViewState();
}

class _UsersTableViewState extends State<_UsersTableView> {
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);
  static const _zebra = Color(0xFFFAFAFA);

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return [
      for (final u in widget.users)
        if ('${u['full_name']}'.toLowerCase().contains(q) ||
            '${u['email']}'.toLowerCase().contains(q) ||
            '${u['role']}'.toLowerCase().contains(q) ||
            '${u['role_code']}'.toLowerCase().contains(q) ||
            '${u['company']}'.toLowerCase().contains(q))
          u,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.wide ? 48 : 16,
        24,
        widget.wide ? 48 : 16,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(
                foregroundColor: _black,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '← Back',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              color: _black,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle ??
                '${rows.length} of ${widget.users.length} accounts',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _SearchField(
            controller: _search,
            hint: 'Search name, email, role…',
            showClear: _query.isNotEmpty,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: _opsTableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: const Row(
                            children: [
                              _HeadCell('Name', flex: 3),
                              _HeadCell('Email', flex: 4),
                              _HeadCell('Role', flex: 2),
                              _HeadCell('Company', flex: 2),
                              _HeadCell('Status', flex: 2),
                              _HeadCell('Joined', flex: 3),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final u = rows[index];
                              final active = u['is_active'] == true;
                              final created = DateTime.tryParse(
                                '${u['created_at'] ?? ''}',
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: index.isOdd ? _zebra : Colors.white,
                                  border: const Border(
                                    bottom: BorderSide(color: _line),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _BodyCell(
                                      (u['full_name']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true)
                                          ? u['full_name'].toString()
                                          : '—',
                                      flex: 3,
                                      bold: true,
                                    ),
                                    _BodyCell(
                                      u['email']?.toString() ?? '—',
                                      flex: 4,
                                    ),
                                    _BodyCell(
                                      u['role']?.toString().isNotEmpty == true
                                          ? u['role'].toString()
                                          : (u['role_code']?.toString() ??
                                              '—'),
                                      flex: 2,
                                    ),
                                    _BodyCell(
                                      u['company']?.toString() ?? 'Sayge',
                                      flex: 2,
                                    ),
                                    _BodyCell(
                                      active ? 'Active' : 'Inactive',
                                      flex: 2,
                                      color: active ? _black : _muted,
                                    ),
                                    _BodyCell(
                                      created != null
                                          ? widget.dateFmt
                                              .format(created.toLocal())
                                          : '—',
                                      flex: 3,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompaniesTableView extends StatefulWidget {
  const _CompaniesTableView({
    required this.companies,
    required this.dateFmt,
    required this.wide,
    required this.onBack,
    this.title = 'Companies',
    this.subtitle,
    this.onCompanyTap,
    this.onCreateCompany,
    this.onInviteOwner,
  });

  final List<Map<String, dynamic>> companies;
  final DateFormat dateFmt;
  final bool wide;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final void Function(Map<String, dynamic> company)? onCompanyTap;
  final VoidCallback? onCreateCompany;
  final void Function(Map<String, dynamic> company)? onInviteOwner;

  @override
  State<_CompaniesTableView> createState() => _CompaniesTableViewState();
}

class _CompaniesTableViewState extends State<_CompaniesTableView> {
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);
  static const _zebra = Color(0xFFFAFAFA);

  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.companies;
    return [
      for (final c in widget.companies)
        if ('${c['name']}'.toLowerCase().contains(q) ||
            '${c['display_name']}'.toLowerCase().contains(q) ||
            '${c['email']}'.toLowerCase().contains(q) ||
            '${c['gstin']}'.toLowerCase().contains(q))
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.wide ? 48 : 16,
        24,
        widget.wide ? 48 : 16,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(
                foregroundColor: _black,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '← Back',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              color: _black,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle ??
                '${rows.length} of ${widget.companies.length} companies',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.onCreateCompany != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: _BwButton(
                label: 'Create company',
                onPressed: widget.onCreateCompany,
              ),
            ),
          ],
          const SizedBox(height: 20),
          _SearchField(
            controller: _search,
            hint: 'Search company, email, GSTIN…',
            showClear: _query.isNotEmpty,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No companies on this plan',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: _opsTableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const _HeadCell('Company', flex: 3),
                              const _HeadCell('Email', flex: 3),
                              const _HeadCell('Phone', flex: 2),
                              const _HeadCell('GSTIN', flex: 2),
                              const _HeadCell('Users', flex: 1),
                              const _HeadCell('Created', flex: 2),
                              if (widget.onInviteOwner != null)
                                const _HeadCell('Invite', flex: 2),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final c = rows[index];
                              final created = DateTime.tryParse(
                                '${c['created_at'] ?? ''}',
                              );
                              final display = (c['display_name']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true)
                                  ? c['display_name'].toString()
                                  : (c['name']?.toString() ?? '—');
                              final usersCount = () {
                                final v = c['users_count'];
                                if (v is int) return v;
                                if (v is num) return v.toInt();
                                return int.tryParse('$v') ?? 0;
                              }();
                              final row = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: index.isOdd ? _zebra : Colors.white,
                                  border: const Border(
                                    bottom: BorderSide(color: _line),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _BodyCell(display, flex: 3, bold: true),
                                    _BodyCell(
                                      (c['email']?.toString().trim().isNotEmpty ==
                                              true)
                                          ? c['email'].toString()
                                          : '—',
                                      flex: 3,
                                    ),
                                    _BodyCell(
                                      (c['telephone']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true)
                                          ? c['telephone'].toString()
                                          : '—',
                                      flex: 2,
                                    ),
                                    _BodyCell(
                                      (c['gstin']?.toString().trim().isNotEmpty ==
                                              true)
                                          ? c['gstin'].toString()
                                          : '—',
                                      flex: 2,
                                    ),
                                    _BodyCell('$usersCount', flex: 1),
                                    _BodyCell(
                                      created != null
                                          ? widget.dateFmt
                                              .format(created.toLocal())
                                          : '—',
                                      flex: 2,
                                    ),
                                    if (widget.onInviteOwner != null)
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed: () =>
                                                widget.onInviteOwner!(c),
                                            style: TextButton.styleFrom(
                                              foregroundColor: _black,
                                              padding: EdgeInsets.zero,
                                              minimumSize: const Size(0, 28),
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Owner',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                              if (widget.onCompanyTap == null) return row;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onCompanyTap!(c),
                                  hoverColor: const Color(0xFFF5F5F5),
                                  child: row,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

typedef _UpdatePlanFn = Future<void> Function({
  required String code,
  required String name,
  required double priceInr,
  required int employeeLimit,
});

typedef _SetPlanActiveFn = Future<void> Function({
  required String code,
  required bool isActive,
});

class _PlansManageView extends StatefulWidget {
  const _PlansManageView({
    required this.plans,
    required this.livePlanCode,
    required this.livePlanName,
    required this.liveStatus,
    required this.wide,
    required this.onBack,
    required this.onUpdatePlan,
    required this.onSetLivePlan,
    required this.onSetPlanActive,
    required this.onOpenPlan,
  });

  final List<Map<String, dynamic>> plans;
  final String livePlanCode;
  final String livePlanName;
  final String liveStatus;
  final bool wide;
  final VoidCallback onBack;
  final _UpdatePlanFn onUpdatePlan;
  final Future<void> Function(String code) onSetLivePlan;
  final _SetPlanActiveFn onSetPlanActive;
  final void Function(Map<String, dynamic> plan) onOpenPlan;

  @override
  State<_PlansManageView> createState() => _PlansManageViewState();
}

class _PlansManageViewState extends State<_PlansManageView> {
  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);
  static const _zebra = Color(0xFFFAFAFA);

  bool _busy = false;
  String? _actionError;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final code = (plan['plan_code'] ?? '').toString();
    final nameCtrl = TextEditingController(
      text: (plan['plan_name'] ?? code).toString(),
    );
    final priceCtrl = TextEditingController(
      text: _priceRaw(plan),
    );
    final limitCtrl = TextEditingController(
      text: _limitRaw(plan),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text(
            'Edit $code',
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: 'Display name',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: priceCtrl,
                  label: 'Price (₹ / month)',
                  prefixText: '₹ ',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: limitCtrl,
                  label: 'Employee seat limit',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            AppOutlinedButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: AppButton(
                label: 'Save',
                expand: true,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      limitCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim());
    final limit = int.tryParse(limitCtrl.text.trim());
    nameCtrl.dispose();
    priceCtrl.dispose();
    limitCtrl.dispose();

    if (name.isEmpty || price == null || price < 0 || limit == null || limit <= 0) {
      setState(() => _actionError = 'Enter a valid name, price, and seat limit.');
      return;
    }

    await _run(
      () => widget.onUpdatePlan(
        code: code,
        name: name,
        priceInr: price,
        employeeLimit: limit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveLabel = widget.livePlanName.isNotEmpty
        ? widget.livePlanName
        : (widget.livePlanCode.isNotEmpty ? widget.livePlanCode : '—');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.wide ? 48 : 16,
        24,
        widget.wide ? 48 : 16,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(
                foregroundColor: _black,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '← Back',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Plans',
            style: TextStyle(
              color: _black,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live: $liveLabel'
            '${widget.liveStatus.isNotEmpty ? ' · ${widget.liveStatus}' : ''}'
            ' · tap a plan for companies · edit / activate / make live',
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_actionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _actionError!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: widget.plans.isEmpty
                ? const Center(
                    child: Text(
                      'No plans found. Apply billing_closed_beta.sql.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: _opsTableHeaderBg,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: const Row(
                            children: [
                              _HeadCell('Plan', flex: 3),
                              _HeadCell('Price / mo', flex: 2),
                              _HeadCell('Seats', flex: 1),
                              _HeadCell('Cos', flex: 1),
                              _HeadCell('Status', flex: 2),
                              _HeadCell(
                                'Actions',
                                flex: 4,
                                align: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.plans.length,
                            itemBuilder: (context, index) {
                              final p = widget.plans[index];
                              final code = (p['plan_code'] ?? '').toString();
                              final name =
                                  (p['plan_name'] ?? code).toString();
                              final isLive = p['is_live'] == true ||
                                  code == widget.livePlanCode;
                              final isActive = p['is_active'] != false;
                              final cosCount = () {
                                final v = p['companies_count'];
                                if (v is int) return v;
                                if (v is num) return v.toInt();
                                return int.tryParse('$v') ?? 0;
                              }();
                              final row = Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: index.isOdd ? _zebra : Colors.white,
                                  border: const Border(
                                    bottom: BorderSide(color: _line),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: isActive
                                                  ? _black
                                                  : _muted,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            code,
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _BodyCell(
                                      '₹${_priceRaw(p)}',
                                      flex: 2,
                                      color: isActive ? null : _muted,
                                    ),
                                    _BodyCell(
                                      _limitRaw(p),
                                      flex: 1,
                                      color: isActive ? null : _muted,
                                    ),
                                    _BodyCell(
                                      '$cosCount',
                                      flex: 1,
                                      color: isActive ? null : _muted,
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _PlanStatusChip(
                                          isLive: isLive,
                                          isActive: isActive,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: () {},
                                          behavior: HitTestBehavior.opaque,
                                          child: Wrap(
                                            alignment: WrapAlignment.end,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _BwButton(
                                                label: 'Edit',
                                                outlined: true,
                                                onPressed: _busy
                                                    ? null
                                                    : () => _editPlan(p),
                                              ),
                                              if (isActive && !isLive)
                                                _BwButton(
                                                  label: 'Deactivate',
                                                  outlined: true,
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _run(
                                                            () => widget
                                                                .onSetPlanActive(
                                                              code: code,
                                                              isActive: false,
                                                            ),
                                                          ),
                                                ),
                                              if (!isActive)
                                                _BwButton(
                                                  label: 'Activate',
                                                  outlined: true,
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _run(
                                                            () => widget
                                                                .onSetPlanActive(
                                                              code: code,
                                                              isActive: true,
                                                            ),
                                                          ),
                                                ),
                                              if (!isLive)
                                                _BwButton(
                                                  label: 'Make live',
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _run(
                                                            () => widget
                                                                .onSetLivePlan(
                                                              code,
                                                            ),
                                                          ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onOpenPlan(p),
                                  hoverColor: const Color(0xFFF5F5F5),
                                  child: row,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _priceRaw(Map<String, dynamic> p) {
    final v = p['price_inr'];
    if (v is num) {
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
    }
    return '0';
  }

  static String _limitRaw(Map<String, dynamic> p) {
    final v = p['employee_limit'];
    if (v is int) return '$v';
    if (v is num) return '${v.toInt()}';
    return '$v';
  }
}

class _PlanStatusChip extends StatelessWidget {
  const _PlanStatusChip({
    required this.isLive,
    required this.isActive,
  });

  final bool isLive;
  final bool isActive;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    if (isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _black,
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      );
    }
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: _muted),
        ),
        child: const Text(
          'INACTIVE',
          style: TextStyle(
            color: _muted,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      );
    }
    return const Text(
      'Active',
      style: TextStyle(
        color: _muted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.showClear = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool showClear;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      cursorColor: _black,
      style: const TextStyle(
        color: _black,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
        prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
        suffixIcon: !showClear
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.close, size: 18, color: _muted),
              ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _line),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _black, width: 1.4),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell(
    this.label, {
    required this.flex,
    this.align = TextAlign.left,
  });

  final String label;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(
    this.text, {
    required this.flex,
    this.bold = false,
    this.color,
  });

  final String text;
  final int flex;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? const Color(0xFF0A0A0A),
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.hint,
    this.onTap,
    this.valueSize = 56,
  });

  final String label;
  final String value;
  final String hint;
  final VoidCallback? onTap;
  final double valueSize;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _black,
              fontWeight: FontWeight.w800,
              fontSize: valueSize,
              height: 1,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hint,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF5F5F5),
        child: child,
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.name,
    required this.count,
    required this.meta,
    this.isLive = false,
    this.onTap,
  });

  final String name;
  final int count;
  final String meta;
  final bool isLive;
  final VoidCallback? onTap;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);
  static const _line = Color(0xFFE5E5E5);

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: isLive ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border.all(color: isLive ? _black : _line, width: isLive ? 1.4 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        color: _black,
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: _black,
              fontWeight: FontWeight.w800,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0xFFF5F5F5),
        child: child,
      ),
    );
  }
}

class _BwButton extends StatelessWidget {
  const _BwButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  static const _black = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        height: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: _black,
            side: const BorderSide(color: _black, width: 1.2),
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.4,
            ),
          ),
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD4D4D4),
          elevation: 0,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  static const _black = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    final needsSql = message.contains('platform_ops_snapshot') ||
        message.contains('platform_ops_update_plan') ||
        message.contains('platform_ops_set_live_plan') ||
        message.contains('platform_ops_set_plan_active') ||
        message.contains('Could not find the function') ||
        message.contains('PGRST');
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load',
            style: TextStyle(
              color: _black,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            needsSql
                ? 'Re-apply supabase/platform_ops_snapshot.sql, then retry.\n\n$message'
                : message,
            style: const TextStyle(color: _muted, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 24),
          _BwButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
