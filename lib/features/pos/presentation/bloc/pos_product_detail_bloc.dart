import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pos_entities.dart';
import '../../domain/usecases/pos_usecases.dart';

part 'pos_product_detail_event.dart';
part 'pos_product_detail_state.dart';

class PosProductDetailBloc
    extends Bloc<PosProductDetailEvent, PosProductDetailState> {
  PosProductDetailBloc({
    required this.getProductDetailUseCase,
    required this.recordPurchaseUseCase,
    required this.upsertPriceRuleUseCase,
    required this.deletePriceRuleUseCase,
    required this.publicImageUrlUseCase,
  }) : super(const PosProductDetailState()) {
    on<PosProductDetailStarted>(_onStarted);
    on<PosPurchaseRecorded>(_onPurchase);
    on<PosPriceRuleSaved>(_onPriceRule);
    on<PosPriceRuleRemoved>(_onDeleteRule);
  }

  final GetPosProductDetailUseCase getProductDetailUseCase;
  final RecordPosPurchaseUseCase recordPurchaseUseCase;
  final UpsertPosPriceRuleUseCase upsertPriceRuleUseCase;
  final DeletePosPriceRuleUseCase deletePriceRuleUseCase;
  final PosPublicImageUrlUseCase publicImageUrlUseCase;

  String imageUrl(String path) => publicImageUrlUseCase(path);

  Future<void> _onStarted(
    PosProductDetailStarted event,
    Emitter<PosProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: PosProductDetailStatus.loading, clearError: true));
    final result = await getProductDetailUseCase(event.productId);
    result.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductDetailStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (detail) => emit(
        state.copyWith(
          status: PosProductDetailStatus.ready,
          detail: detail,
        ),
      ),
    );
  }

  Future<void> _reload(Emitter<PosProductDetailState> emit, String productId) async {
    final latest = await getProductDetailUseCase(productId);
    latest.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductDetailStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (detail) => emit(
        state.copyWith(
          status: PosProductDetailStatus.ready,
          detail: detail,
        ),
      ),
    );
  }

  Future<void> _onPurchase(
    PosPurchaseRecorded event,
    Emitter<PosProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: PosProductDetailStatus.saving, clearError: true));
    final result = await recordPurchaseUseCase(event.draft);
    await result.fold(
      (f) async => emit(
        state.copyWith(
          status: PosProductDetailStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(successMessage: 'Purchase recorded'));
        await _reload(emit, event.draft.productId);
      },
    );
  }

  Future<void> _onPriceRule(
    PosPriceRuleSaved event,
    Emitter<PosProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: PosProductDetailStatus.saving, clearError: true));
    final result = await upsertPriceRuleUseCase(event.rule);
    await result.fold(
      (f) async => emit(
        state.copyWith(
          status: PosProductDetailStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(successMessage: 'Promotion saved'));
        await _reload(emit, event.rule.productId);
      },
    );
  }

  Future<void> _onDeleteRule(
    PosPriceRuleRemoved event,
    Emitter<PosProductDetailState> emit,
  ) async {
    emit(state.copyWith(status: PosProductDetailStatus.saving, clearError: true));
    final result = await deletePriceRuleUseCase(event.ruleId);
    await result.fold(
      (f) async => emit(
        state.copyWith(
          status: PosProductDetailStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (_) async {
        emit(state.copyWith(successMessage: 'Promotion removed'));
        await _reload(emit, event.productId);
      },
    );
  }
}
