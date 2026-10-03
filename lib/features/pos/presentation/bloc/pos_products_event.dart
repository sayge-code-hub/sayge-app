part of 'pos_products_bloc.dart';

sealed class PosProductsEvent extends Equatable {
  const PosProductsEvent();
  @override
  List<Object?> get props => [];
}

class PosProductsStarted extends PosProductsEvent {
  const PosProductsStarted(this.brandId);
  final String brandId;
  @override
  List<Object?> get props => [brandId];
}

class PosProductDeleted extends PosProductsEvent {
  const PosProductDeleted({
    required this.productId,
    required this.brandId,
  });
  final String productId;
  final String brandId;
  @override
  List<Object?> get props => [productId, brandId];
}
