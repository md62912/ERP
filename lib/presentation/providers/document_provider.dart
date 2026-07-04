import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';

class EmployeeDocument {
  final String id;
  final String employeeId;
  final String? docType;
  final String? fileUrl;
  final DateTime uploadedAt;

  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    this.docType,
    this.fileUrl,
    required this.uploadedAt,
  });

  factory EmployeeDocument.fromJson(Map<String, dynamic> json) => EmployeeDocument(
        id: json['id'] as String,
        employeeId: json['employee_id'] as String,
        docType: json['doc_type'] as String?,
        fileUrl: json['file_url'] as String?,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      );
}

final employeeDocumentsProvider =
    FutureProvider.autoDispose.family<List<EmployeeDocument>, String>((ref, employeeId) async {
  final rows = await SupabaseService.client
      .from(Tables.employeeDocuments)
      .select()
      .eq('employee_id', employeeId)
      .order('uploaded_at', ascending: false);
  return (rows as List).map((e) => EmployeeDocument.fromJson(e as Map<String, dynamic>)).toList();
});

const _documentsBucket = 'employee-documents';

final documentActionsProvider = Provider((ref) => DocumentActions());

class DocumentActions {
  /// Uploads [bytes] to the private `employee-documents` bucket under
  /// `{employeeId}/{fileName}` and records the metadata row. Storage RLS
  /// only allows this for the employee themself or hr/admin.
  Future<void> upload({
    required String employeeId,
    required String fileName,
    required Uint8List bytes,
    String? docType,
  }) async {
    final path = '$employeeId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await SupabaseService.client.storage.from(_documentsBucket).uploadBinary(path, bytes);

    // Bucket is private, so a "public" URL wouldn't actually resolve —
    // store the storage path instead and sign it on demand when viewing.
    await SupabaseService.client.from(Tables.employeeDocuments).insert({
      'employee_id': employeeId,
      'doc_type': docType,
      'file_url': path,
    });
  }

  /// Bucket is private, so reading a file back requires a short-lived
  /// signed URL rather than the public URL stored above.
  Future<String> signedUrlFor(String storagePath, {int expiresInSeconds = 3600}) {
    return SupabaseService.client.storage
        .from(_documentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }
}
