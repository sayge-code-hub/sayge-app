part of 'pos_brands_bloc.dart';

enum PosBrandsStatus { initial, loading, ready, saving, success, failure }

class PosBrandsState extends Equatable {
  const PosBrandsState({
    this.status = PosBrandsStatus.initial,
    this.brands = const [],
    this.savedBrand,
    this.errorMessage,
    this.successMessage,
  });

  final PosBrandsStatus status;
  final List<PosBrand> brands;
  final PosBrand? savedBrand;
  final String? errorMessage;
  final String? successMessage;

  PosBrandsState copyWith({
    PosBrandsStatus? status,
    List<PosBrand>? brands,
    PosBrand? savedBrand,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSavedBrand = false,
  }) {
    return PosBrandsState(
      status: status ?? this.status,
      brands: brands ?? this.brands,
      savedBrand:
          clearSavedBrand ? null : (savedBrand ?? this.savedBrand),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, brands, savedBrand, errorMessage, successMessage];
}
