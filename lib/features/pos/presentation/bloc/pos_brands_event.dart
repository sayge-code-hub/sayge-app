part of 'pos_brands_bloc.dart';

sealed class PosBrandsEvent extends Equatable {
  const PosBrandsEvent();
  @override
  List<Object?> get props => [];
}

class PosBrandsStarted extends PosBrandsEvent {
  const PosBrandsStarted();
}

class PosBrandSubmitted extends PosBrandsEvent {
  const PosBrandSubmitted(this.brand, {this.logo});
  final PosBrand brand;
  final PosImageUpload? logo;
  @override
  List<Object?> get props => [brand, logo];
}

class PosBrandDeleted extends PosBrandsEvent {
  const PosBrandDeleted(this.brandId);
  final String brandId;
  @override
  List<Object?> get props => [brandId];
}
