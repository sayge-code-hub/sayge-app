part of 'pos_product_form_bloc.dart';

sealed class PosProductFormEvent extends Equatable {
  const PosProductFormEvent();
  @override
  List<Object?> get props => [];
}

class PosProductFormStarted extends PosProductFormEvent {
  const PosProductFormStarted({
    required this.brandId,
    this.productId,
  });
  final String brandId;
  final String? productId;
  @override
  List<Object?> get props => [brandId, productId];
}

class PosProductFormSubmitted extends PosProductFormEvent {
  const PosProductFormSubmitted({
    required this.product,
    required this.images,
    required this.attributes,
    this.auditReason = '',
  });
  final PosProduct product;
  final List<PosImageUpload> images;
  final List<PosProductAttribute> attributes;
  final String auditReason;
  @override
  List<Object?> get props => [product, images, attributes, auditReason];
}

class PosProductFormDeleted extends PosProductFormEvent {
  const PosProductFormDeleted(this.productId);
  final String productId;
  @override
  List<Object?> get props => [productId];
}
