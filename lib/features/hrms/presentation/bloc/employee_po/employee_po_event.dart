part of 'employee_po_bloc.dart';

abstract class EmployeePoEvent extends Equatable {
  const EmployeePoEvent();

  @override
  List<Object?> get props => [];
}

class EmployeePoRequested extends EmployeePoEvent {
  const EmployeePoRequested(this.employeeId);

  final String employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class EmployeePoSubmitted extends EmployeePoEvent {
  const EmployeePoSubmitted({
    required this.employeeId,
    required this.poNumber,
    required this.startDate,
    required this.endDate,
    required this.fileName,
    required this.fileBytes,
    this.mimeType = 'application/pdf',
  });

  final String employeeId;
  final String poNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;

  @override
  List<Object?> get props => [
        employeeId,
        poNumber,
        startDate,
        endDate,
        fileName,
        fileBytes,
        mimeType,
      ];
}

class EmployeePoUpdated extends EmployeePoEvent {
  const EmployeePoUpdated({
    required this.id,
    required this.poNumber,
    required this.startDate,
    required this.endDate,
    this.fileName,
    this.fileBytes,
    this.mimeType = 'application/pdf',
  });

  final String id;
  final String poNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String? fileName;
  final Uint8List? fileBytes;
  final String mimeType;

  @override
  List<Object?> get props => [
        id,
        poNumber,
        startDate,
        endDate,
        fileName,
        fileBytes,
        mimeType,
      ];
}

class EmployeePoDeleted extends EmployeePoEvent {
  const EmployeePoDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class EmployeePoDownloadRequested extends EmployeePoEvent {
  const EmployeePoDownloadRequested(this.order);

  final EmployeePurchaseOrder order;

  @override
  List<Object?> get props => [order];
}
