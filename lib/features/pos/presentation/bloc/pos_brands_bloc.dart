import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pos_entities.dart';
import '../../domain/usecases/pos_usecases.dart';

part 'pos_brands_event.dart';
part 'pos_brands_state.dart';

class PosBrandsBloc extends Bloc<PosBrandsEvent, PosBrandsState> {
  PosBrandsBloc({
    required this.getBrandsUseCase,
    required this.upsertBrandUseCase,
    required this.deleteBrandUseCase,
    required this.publicImageUrlUseCase,
  }) : super(const PosBrandsState()) {
    on<PosBrandsStarted>(_onStarted);
    on<PosBrandSubmitted>(_onSubmitted);
    on<PosBrandDeleted>(_onDeleted);
  }

  final GetPosBrandsUseCase getBrandsUseCase;
  final UpsertPosBrandUseCase upsertBrandUseCase;
  final DeletePosBrandUseCase deleteBrandUseCase;
  final PosPublicImageUrlUseCase publicImageUrlUseCase;

  String imageUrl(String path) => publicImageUrlUseCase(path);

  Future<void> _onStarted(
    PosBrandsStarted event,
    Emitter<PosBrandsState> emit,
  ) async {
    emit(state.copyWith(status: PosBrandsStatus.loading, clearError: true));
    final result = await getBrandsUseCase();
    result.fold(
      (f) => emit(
        state.copyWith(status: PosBrandsStatus.failure, errorMessage: f.message),
      ),
      (brands) => emit(
        state.copyWith(status: PosBrandsStatus.ready, brands: brands),
      ),
    );
  }

  Future<void> _onSubmitted(
    PosBrandSubmitted event,
    Emitter<PosBrandsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PosBrandsStatus.saving,
        clearError: true,
        clearSuccess: true,
        clearSavedBrand: true,
      ),
    );
    final result = await upsertBrandUseCase(event.brand, logo: event.logo);
    await result.fold(
      (f) async => emit(
        state.copyWith(status: PosBrandsStatus.failure, errorMessage: f.message),
      ),
      (saved) async {
        final latest = await getBrandsUseCase();
        latest.fold(
          (f) => emit(
            state.copyWith(
              status: PosBrandsStatus.success,
              savedBrand: saved,
              successMessage: 'Brand saved',
              errorMessage: f.message,
            ),
          ),
          (brands) => emit(
            state.copyWith(
              status: PosBrandsStatus.success,
              brands: brands,
              savedBrand: saved,
              successMessage: 'Brand saved',
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDeleted(
    PosBrandDeleted event,
    Emitter<PosBrandsState> emit,
  ) async {
    emit(state.copyWith(status: PosBrandsStatus.saving, clearError: true));
    final result = await deleteBrandUseCase(event.brandId);
    await result.fold(
      (f) async => emit(
        state.copyWith(status: PosBrandsStatus.failure, errorMessage: f.message),
      ),
      (_) async {
        final latest = await getBrandsUseCase();
        latest.fold(
          (f) => emit(
            state.copyWith(
              status: PosBrandsStatus.success,
              successMessage: 'Brand deleted',
              errorMessage: f.message,
            ),
          ),
          (brands) => emit(
            state.copyWith(
              status: PosBrandsStatus.success,
              brands: brands,
              successMessage: 'Brand deleted',
            ),
          ),
        );
      },
    );
  }
}
