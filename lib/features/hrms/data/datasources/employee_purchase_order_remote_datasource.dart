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
