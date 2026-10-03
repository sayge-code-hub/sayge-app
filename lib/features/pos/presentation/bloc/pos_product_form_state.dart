part of 'pos_product_form_bloc.dart';

enum PosProductFormStatus {
  initial,
  loading,
  editing,
  saving,
  success,
  deleted,
  failure,
}

class PosProductFormState extends Equatable {
  const PosProductFormState({
    this.status = PosProductFormStatus.initial,
    this.brandId,
    this.product,
    this.isEdit = false,
    this.errorMessage,
    this.successMessage,
  });

  final PosProductFormStatus status;
  final String? brandId;
  final PosProduct? product;
  final bool isEdit;
  final String? errorMessage;
  final String? successMessage;

  PosProductFormState copyWith({
    PosProductFormStatus? status,
    String? brandId,
    PosProduct? product,
    bool? isEdit,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PosProductFormState(
      status: status ?? this.status,
      brandId: brandId ?? this.brandId,
      product: product ?? this.product,
      isEdit: isEdit ?? this.isEdit,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, brandId, product, isEdit, errorMessage, successMessage];
}
