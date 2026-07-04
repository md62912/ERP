import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/supabase/supabase_client.dart';

class Department {
  final String id;
  final String name;
  const Department({required this.id, required this.name});

  factory Department.fromJson(Map<String, dynamic> json) =>
      Department(id: json['id'] as String, name: json['name'] as String);
}

final departmentListProvider = FutureProvider.autoDispose<List<Department>>((ref) async {
  final rows = await SupabaseService.client.from(Tables.departments).select().order('name');
  return (rows as List).map((e) => Department.fromJson(e as Map<String, dynamic>)).toList();
});
