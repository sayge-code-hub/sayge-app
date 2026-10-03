import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pos_entities.dart';
import '../../domain/usecases/pos_usecases.dart';

part 'pos_products_event.dart';
part 'pos_products_state.dart';

class PosProductsBloc extends Bloc<PosProductsEvent, PosProductsState> {
  PosProductsBloc({
    required this.getBrandUseCase,
    required this.getProductsUseCase,
    required this.deleteProductUseCase,
    required this.publicImageUrlUseCase,
  }) : super(const PosProductsState()) {
    on<PosProductsStarted>(_onStarted);
    on<PosProductDeleted>(_onDeleted);
  }

  final GetPosBrandUseCase getBrandUseCase;
  final GetPosProductsUseCase getProductsUseCase;
  final DeletePosProductUseCase deleteProductUseCase;
  final PosPublicImageUrlUseCase publicImageUrlUseCase;

  String imageUrl(String path) => publicImageUrlUseCase(path);

  Future<void> _onStarted(
    PosProductsStarted event,
    Emitter<PosProductsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PosProductsStatus.loading,
        brandId: event.brandId,
        clearError: true,
      ),
    );
    final brandResult = await getBrandUseCase(event.brandId);
    final productsResult = await getProductsUseCase(event.brandId);

    brandResult.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductsStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (brand) {
        productsResult.fold(
          (f) => emit(
            state.copyWith(
              status: PosProductsStatus.failure,
              brand: brand,
              errorMessage: f.message,
            ),
          ),
          (products) => emit(
            state.copyWith(
              status: PosProductsStatus.ready,
              brand: brand,
              products: products,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDeleted(
    PosProductDeleted event,
    Emitter<PosProductsState> emit,
  ) async {
    emit(state.copyWith(status: PosProductsStatus.saving, clearError: true));
    final result = await deleteProductUseCase(event.productId);
    await result.fold(
      (f) async => emit(
        state.copyWith(
          status: PosProductsStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (_) async {
        final brandId = state.brandId ?? event.brandId;
        final latest = await getProductsUseCase(brandId);
        latest.fold(
          (f) => emit(
            state.copyWith(
              status: PosProductsStatus.success,
              successMessage: 'Product deleted',
              errorMessage: f.message,
            ),
          ),
          (products) => emit(
            state.copyWith(
              status: PosProductsStatus.success,
              products: products,
              successMessage: 'Product deleted',
            ),
          ),
        );
      },
    );
  }
}
