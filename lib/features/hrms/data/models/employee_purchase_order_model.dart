import '../../domain/entities/employee_purchase_order.dart';

class EmployeePurchaseOrderModel extends EmployeePurchaseOrder {
  const EmployeePurchaseOrderModel({
    required super.id,
    required super.employeeId,
    required super.poNumber,
    required super.startDate,
    required super.endDate,
    required super.fileName,
    required super.mimeType,
    required super.fileSizeBytes,
    required super.storagePath,
  });

  factory EmployeePurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.parse(value.toString());
    }

    return EmployeePurchaseOrderModel(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employee_id'] ?? '').toString(),
      poNumber: (json['po_number'] ?? '').toString(),
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      fileName: (json['file_name'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? 'application/pdf').toString(),
      fileSizeBytes: int.tryParse('${json['file_size_bytes'] ?? 0}') ?? 0,
      storagePath: (json['storage_path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return {
      'id': id,
      'employee_id': employeeId,
      'po_number': poNumber,
      'start_date': ymd(startDate),
      'end_date': ymd(endDate),
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'storage_path': storagePath,
    };
  }
}
