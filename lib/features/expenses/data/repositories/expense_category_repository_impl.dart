import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_category_repository.dart';
import '../datasources/expense_category_remote_datasource.dart';

class ExpenseCategoryRepositoryImpl implements ExpenseCategoryRepository {
  const ExpenseCategoryRepositoryImpl({required this.remoteDataSource});

  final ExpenseCategoryRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<ExpenseCategory>>> listCategories() {
    return _guard(remoteDataSource.listCategories);
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> addCategory(String name) {
    return _mutate(() => remoteDataSource.addCategory(name));
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> renameCategory({
    required String id,
    required String name,
  }) {
    return _mutate(() => remoteDataSource.renameCategory(id: id, name: name));
  }

  @override
  Future<Either<Failure, List<ExpenseCategory>>> deleteCategory(String id) {
    return _mutate(() => remoteDataSource.deleteCategory(id));
  }

  Future<Either<Failure, List<ExpenseCategory>>> _mutate(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return Right(await remoteDataSource.listCategories());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update categories.'));
    }
  }

  Future<Either<Failure, List<ExpenseCategory>>> _guard(
    Future<List<ExpenseCategory>> Function() action,
  ) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load categories.'));
    }
  }
}
