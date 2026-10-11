import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/dms_entity.dart';
import '../../domain/entities/document_record.dart';
import '../../domain/repositories/document_repository.dart';
import '../datasources/document_remote_datasource.dart';
import '../models/document_model.dart';

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
    required String category,
    required Uint8List fileBytes,
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
        category: category,
        fileBytes: fileBytes,
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

  @override
  Future<Either<Failure, void>> deleteDocument(String documentId) async {
    try {
      await remoteDataSource.deleteDocument(documentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DocumentRecord>> replaceDocument({
    required DocumentRecord existing,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
    String? title,
    String? category,
  }) async {
    try {
      final replaced = await remoteDataSource.replaceDocument(
        existing: DocumentModel.fromEntity(existing),
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        title: title,
        category: category,
      );
      return Right(replaced);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, DmsEntity>> createCatalogEntity({
    required DmsEntityType type,
    required String name,
    String subtitle = '',
  }) async {
    try {
      final entity = await remoteDataSource.createCatalogEntity(
        type: type,
        name: name,
        subtitle: subtitle,
      );
      return Right(entity);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getDownloadUrl(
    DocumentRecord document,
  ) async {
    try {
      final url = await remoteDataSource.getDownloadUrl(document.storagePath);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
