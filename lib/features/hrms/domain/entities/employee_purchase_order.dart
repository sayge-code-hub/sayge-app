import 'package:equatable/equatable.dart';

class EmployeePurchaseOrder extends Equatable {
  const EmployeePurchaseOrder({
    required this.id,
    required this.employeeId,
    required this.poNumber,
    required this.startDate,
    required this.endDate,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.storagePath,
  });

  final String id;
  final String employeeId;
  final String poNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String storagePath;

  bool get hasFile => storagePath.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        employeeId,
        poNumber,
        startDate,
        endDate,
        fileName,
        storagePath,
      ];
}
