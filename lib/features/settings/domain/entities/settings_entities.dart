class CompanyDetails {
  const CompanyDetails({
    required this.id,
    required this.name,
    required this.displayName,
    required this.address,
    required this.gstin,
    required this.pan,
    required this.sacCode,
    required this.telephone,
    required this.email,
    required this.bankName,
    required this.bankAccountNo,
    required this.bankBranch,
    required this.bankIfsc,
    this.logoPath = '',
    this.logoUrl,
  });

  final String id;
  final String name;
  final String displayName;
  final String address;
  final String gstin;
  final String pan;
  final String sacCode;
  final String telephone;
  final String email;
  final String bankName;
  final String bankAccountNo;
  final String bankBranch;
  final String bankIfsc;
  final String logoPath;
  final String? logoUrl;
}

class AppRole {
  const AppRole({
    required this.id,
    required this.code,
    required this.label,
    required this.description,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String code;
  final String label;
  final String description;
  final int sortOrder;
  final bool isActive;
}

class ActivityLogEntry {
  const ActivityLogEntry({
    required this.id,
    required this.occurredAt,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.actorEmail,
    this.summary = '',
  });

  final int id;
  final DateTime occurredAt;
  final String tableName;
  final String recordId;
  final String action;
  final String? actorEmail;
  final String summary;
}
