part of 'pos_product_detail_bloc.dart';

sealed class PosProductDetailEvent extends Equatable {
  const PosProductDetailEvent();
  @override
  List<Object?> get props => [];
}

class PosProductDetailStarted extends PosProductDetailEvent {
  const PosProductDetailStarted(this.productId);
  final String productId;
  @override
  List<Object?> get props => [productId];
}

class PosPurchaseRecorded extends PosProductDetailEvent {
  const PosPurchaseRecorded(this.draft);
  final PosPurchaseDraft draft;
  @override
  List<Object?> get props => [draft];
}

class PosPriceRuleSaved extends PosProductDetailEvent {
  const PosPriceRuleSaved(this.rule);
  final PosPriceRule rule;
  @override
  List<Object?> get props => [rule];
}

class PosPriceRuleRemoved extends PosProductDetailEvent {
  const PosPriceRuleRemoved({
    required this.ruleId,
    required this.productId,
  });
  final String ruleId;
  final String productId;
  @override
  List<Object?> get props => [ruleId, productId];
}
