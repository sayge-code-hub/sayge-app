/// Owner type for documents in the DMS.
enum DmsEntityType {
  company,
  vendor,
  employee,
  candidate;

  String get label {
    switch (this) {
      case DmsEntityType.company:
        return 'Companies';
      case DmsEntityType.vendor:
        return 'Vendors';
      case DmsEntityType.employee:
        return 'Employees';
      case DmsEntityType.candidate:
        return 'Candidates';
    }
  }

  String get singular {
    switch (this) {
      case DmsEntityType.company:
        return 'Company';
      case DmsEntityType.vendor:
        return 'Vendor';
      case DmsEntityType.employee:
        return 'Employee';
      case DmsEntityType.candidate:
        return 'Candidate';
    }
  }

  String get storageValue {
    switch (this) {
      case DmsEntityType.company:
        return 'company';
      case DmsEntityType.vendor:
        return 'vendor';
      case DmsEntityType.employee:
        return 'employee';
      case DmsEntityType.candidate:
        return 'candidate';
    }
  }

  static DmsEntityType fromStorage(String value) {
    switch (value.toLowerCase()) {
      case 'company':
        return DmsEntityType.company;
      case 'vendor':
        return DmsEntityType.vendor;
      case 'employee':
        return DmsEntityType.employee;
      case 'candidate':
        return DmsEntityType.candidate;
      default:
        return DmsEntityType.company;
    }
  }
}

/// A browsable DMS owner (company, vendor, employee, or candidate).
class DmsEntity {
  const DmsEntity({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final DmsEntityType type;
}
