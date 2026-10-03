part of 'pos_products_bloc.dart';

enum PosProductsStatus { initial, loading, ready, saving, success, failure }

class PosProductsState extends Equatable {
  const PosProductsState({
    this.status = PosProductsStatus.initial,
    this.brandId,
    this.brand,
    this.products = const [],
    this.errorMessage,
    this.successMessage,
  });

  final PosProductsStatus status;
  final String? brandId;
  final PosBrand? brand;
  final List<PosProduct> products;
  final String? errorMessage;
  final String? successMessage;

  PosProductsState copyWith({
    PosProductsStatus? status,
    String? brandId,
    PosBrand? brand,
    List<PosProduct>? products,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PosProductsState(
      status: status ?? this.status,
      brandId: brandId ?? this.brandId,
      brand: brand ?? this.brand,
      products: products ?? this.products,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, brandId, brand, products, errorMessage, successMessage];
}
