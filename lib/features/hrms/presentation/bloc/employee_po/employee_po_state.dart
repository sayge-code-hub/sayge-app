part of 'employee_po_bloc.dart';

enum EmployeePoStatus { initial, loading, ready, saving, failure }

class EmployeePoState extends Equatable {
  const EmployeePoState({
    this.status = EmployeePoStatus.initial,
    this.employeeId,
    this.orders = const [],
    this.errorMessage,
    this.successMessage,
    this.downloadUrl,
    this.downloadFileName,
  });

  final EmployeePoStatus status;
  final String? employeeId;
  final List<EmployeePurchaseOrder> orders;
  final String? errorMessage;
  final String? successMessage;
  final String? downloadUrl;
  final String? downloadFileName;

  EmployeePoState copyWith({
    EmployeePoStatus? status,
    String? employeeId,
    List<EmployeePurchaseOrder>? orders,
    String? errorMessage,
    String? successMessage,
    String? downloadUrl,
    String? downloadFileName,
    bool clearError = false,
    bool clearMessage = false,
    bool clearDownload = false,
  }) {
    return EmployeePoState(
      status: status ?? this.status,
      employeeId: employeeId ?? this.employeeId,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessage ? null : (successMessage ?? this.successMessage),
      downloadUrl: clearDownload ? null : (downloadUrl ?? this.downloadUrl),
      downloadFileName:
          clearDownload ? null : (downloadFileName ?? this.downloadFileName),
    );
  }

  @override
  List<Object?> get props => [
        status,
        employeeId,
        orders,
        errorMessage,
        successMessage,
        downloadUrl,
        downloadFileName,
      ];
}
