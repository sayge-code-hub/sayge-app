part of 'pos_product_detail_bloc.dart';

enum PosProductDetailStatus { initial, loading, ready, saving, failure }

class PosProductDetailState extends Equatable {
  const PosProductDetailState({
    this.status = PosProductDetailStatus.initial,
    this.detail,
    this.errorMessage,
    this.successMessage,
  });

  final PosProductDetailStatus status;
  final PosProductDetail? detail;
  final String? errorMessage;
  final String? successMessage;

  PosProductDetailState copyWith({
    PosProductDetailStatus? status,
    PosProductDetail? detail,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PosProductDetailState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [status, detail, errorMessage, successMessage];
}
