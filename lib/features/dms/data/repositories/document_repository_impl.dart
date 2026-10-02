import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_remote_datasource.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  const DocumentRepositoryImpl({required this.remoteDataSource});

  final DocumentRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<DmsEntity>>> getEntities(
    DmsEntityType type,
  ) async {
    try {
      final entities = await remoteDataSource.getEntities(type);
      return Right(entities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<DocumentRecord>>> getDocuments({
    required DmsEntityType entityType,
    required String entityId,
  }) async {
    try {
      final documents = await remoteDataSource.getDocuments(
        entityType: entityType,
        entityId: entityId,
      );
      return Right(documents);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DocumentRecord>> addDocument({
    required DmsEntityType entityType,
    required String entityId,
    required String entityName,
    required String title,
    required String fileName,
    String mimeType = 'application/octet-stream',
    int fileSizeBytes = 0,
    String notes = '',
  }) async {
    try {
      final created = await remoteDataSource.addDocument(
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        title: title,
        fileName: fileName,
        mimeType: mimeType,
        fileSizeBytes: fileSizeBytes,
        notes: notes,
      );
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
