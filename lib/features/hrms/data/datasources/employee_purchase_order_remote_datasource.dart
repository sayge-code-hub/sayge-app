import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/employee_purchase_order_model.dart';

abstract class EmployeePurchaseOrderRemoteDataSource {
  Future<List<EmployeePurchaseOrderModel>> getForEmployee(String employeeId);

  Future<List<EmployeePurchaseOrderModel>> getAll();

  Future<EmployeePurchaseOrderModel> create({
    required String employeeId,
    required String poNumber,
    required DateTime startDate,
    required DateTime endDate,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/pdf',
  });

  Future<EmployeePurchaseOrderModel> update({
    required String id,
    required String poNumber,
    required DateTime startDate,
    required DateTime endDate,
    String? fileName,
    Uint8List? fileBytes,
    String mimeType = 'application/pdf',
  });

  Future<void> delete(String id);

  Future<String> getDownloadUrl(String storagePath);
}

class EmployeePurchaseOrderRemoteDataSourceImpl
    implements EmployeePurchaseOrderRemoteDataSource {
  EmployeePurchaseOrderRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'employee_purchase_orders';
  static const _bucket = 'employee-pos';

  @override
  Future<List<EmployeePurchaseOrderModel>> getForEmployee(
    String employeeId,
  ) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('employee_id', employeeId)
          .order('start_date', ascending: false);
      return (rows as List<dynamic>)
          .map(
            (row) => EmployeePurchaseOrderModel.fromJson(
              row as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load purchase orders.');
    }
  }

  @override
  Future<List<EmployeePurchaseOrderModel>> getAll() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('start_date', ascending: false);
      return (rows as List<dynamic>)
          .map(
            (row) => EmployeePurchaseOrderModel.fromJson(
              row as Map<String, dynamic>,
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load purchase orders.');
    }
  }

  @override
  Future<EmployeePurchaseOrderModel> create({
    required String employeeId,
    required String poNumber,
    required DateTime startDate,
    required DateTime endDate,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/pdf',
  }) async {
    final trimmedPo = poNumber.trim();
    final trimmedFile = fileName.trim();
    if (trimmedPo.isEmpty) {
      throw const ServerException('PO number is required.');
    }
    if (trimmedFile.isEmpty || fileBytes.isEmpty) {
      throw const ServerException('Attach a PO PDF document.');
    }
    if (endDate.isBefore(startDate)) {
      throw const ServerException('End date must be on or after start date.');
    }

    final safeFile = trimmedFile.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final id = 'po_${employeeId}_${DateTime.now().microsecondsSinceEpoch}';
    final path = '$employeeId/$id/$safeFile';

    try {
      await _client.storage.from(_bucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );

      final model = EmployeePurchaseOrderModel(
        id: id,
        employeeId: employeeId,
        poNumber: trimmedPo,
        startDate: startDate,
        endDate: endDate,
        fileName: safeFile,
        mimeType: mimeType,
        fileSizeBytes: fileBytes.length,
        storagePath: path,
      );

      final row = await _client
          .from(_table)
          .insert(model.toInsertJson())
          .select()
          .single();
      return EmployeePurchaseOrderModel.fromJson(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save purchase order.');
    }
  }

  @override
  Future<EmployeePurchaseOrderModel> update({
    required String id,
    required String poNumber,
    required DateTime startDate,
    required DateTime endDate,
    String? fileName,
    Uint8List? fileBytes,
    String mimeType = 'application/pdf',
  }) async {
    final trimmedPo = poNumber.trim();
    if (trimmedPo.isEmpty) {
      throw const ServerException('PO number is required.');
    }
    if (endDate.isBefore(startDate)) {
      throw const ServerException('End date must be on or after start date.');
    }

    final replacementName = fileName?.trim() ?? '';
    final replacementBytes = fileBytes;
    final replaceFile = replacementName.isNotEmpty &&
        replacementBytes != null &&
        replacementBytes.isNotEmpty;

    try {
      final existing = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (existing == null) {
        throw const ServerException('Purchase order not found.');
      }

      final current = EmployeePurchaseOrderModel.fromJson(existing);
      String ymd(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      final patch = <String, dynamic>{
        'po_number': trimmedPo,
        'start_date': ymd(startDate),
        'end_date': ymd(endDate),
      };

      String? newPath;
      String? previousPath;
      if (replaceFile) {
        final safeFile =
            replacementName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
        newPath = '${current.employeeId}/$id/$safeFile';
        previousPath = current.storagePath.trim();

        await _client.storage.from(_bucket).uploadBinary(
              newPath,
              replacementBytes,
              fileOptions: FileOptions(
                contentType: mimeType,
                upsert: true,
              ),
            );

        patch['file_name'] = safeFile;
        patch['mime_type'] = mimeType;
        patch['file_size_bytes'] = replacementBytes.length;
        patch['storage_path'] = newPath;
      }

      final row = await _client
          .from(_table)
          .update(patch)
          .eq('id', id)
          .select()
          .single();

      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != newPath) {
        try {
          await _client.storage.from(_bucket).remove([previousPath]);
        } catch (_) {}
      }

      return EmployeePurchaseOrderModel.fromJson(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update purchase order.');
    }
  }

  @override
  Future<void> delete(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Purchase order id is required.');
    }
    try {
      final existing = await _client
          .from(_table)
          .select('storage_path')
          .eq('id', trimmed)
          .maybeSingle();
      final storagePath =
          (existing?['storage_path'] ?? '').toString().trim();

      await _client.from(_table).delete().eq('id', trimmed);

      if (storagePath.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([storagePath]);
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete purchase order.');
    }
  }

  @override
  Future<String> getDownloadUrl(String storagePath) async {
    final path = storagePath.trim();
    if (path.isEmpty) {
      throw const ServerException('No file attached to this purchase order.');
    }
    try {
      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (_) {
      throw const NetworkException('Failed to get download link.');
    }
  }
}
