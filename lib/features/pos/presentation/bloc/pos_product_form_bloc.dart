import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pos_entities.dart';
import '../../domain/usecases/pos_usecases.dart';

part 'pos_product_form_event.dart';
part 'pos_product_form_state.dart';

class PosProductFormBloc
    extends Bloc<PosProductFormEvent, PosProductFormState> {
  PosProductFormBloc({
    required this.getProductUseCase,
    required this.upsertProductUseCase,
    required this.deleteProductUseCase,
    required this.publicImageUrlUseCase,
  }) : super(const PosProductFormState()) {
    on<PosProductFormStarted>(_onStarted);
    on<PosProductFormSubmitted>(_onSubmitted);
    on<PosProductFormDeleted>(_onDeleted);
  }

  final GetPosProductUseCase getProductUseCase;
  final UpsertPosProductUseCase upsertProductUseCase;
  final DeletePosProductUseCase deleteProductUseCase;
  final PosPublicImageUrlUseCase publicImageUrlUseCase;

  String imageUrl(String path) => publicImageUrlUseCase(path);

  Future<void> _onStarted(
    PosProductFormStarted event,
    Emitter<PosProductFormState> emit,
  ) async {
    emit(
      state.copyWith(
        status: PosProductFormStatus.loading,
        brandId: event.brandId,
        clearError: true,
      ),
    );
    if (event.productId == null || event.productId!.trim().isEmpty) {
      emit(
        state.copyWith(
          status: PosProductFormStatus.editing,
          isEdit: false,
          product: PosProduct(
            id: '',
            brandId: event.brandId,
            name: '',
          ),
        ),
      );
      return;
    }

    final result = await getProductUseCase(event.productId!);
    result.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductFormStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (product) => emit(
        state.copyWith(
          status: PosProductFormStatus.editing,
          isEdit: true,
          product: product,
        ),
      ),
    );
  }

  Future<void> _onSubmitted(
    PosProductFormSubmitted event,
    Emitter<PosProductFormState> emit,
  ) async {
    emit(state.copyWith(status: PosProductFormStatus.saving, clearError: true));
    final result = await upsertProductUseCase(
      product: event.product,
      images: event.images,
      attributes: event.attributes,
      auditReason: event.auditReason,
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductFormStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (product) => emit(
        state.copyWith(
          status: PosProductFormStatus.success,
          product: product,
          isEdit: true,
          successMessage: 'Product saved',
        ),
      ),
    );
  }

  Future<void> _onDeleted(
    PosProductFormDeleted event,
    Emitter<PosProductFormState> emit,
  ) async {
    emit(state.copyWith(status: PosProductFormStatus.saving, clearError: true));
    final result = await deleteProductUseCase(event.productId);
    result.fold(
      (f) => emit(
        state.copyWith(
          status: PosProductFormStatus.failure,
          errorMessage: f.message,
        ),
      ),
      (_) => emit(
        state.copyWith(
          status: PosProductFormStatus.deleted,
          successMessage: 'Product deleted',
        ),
      ),
    );
  }
}
