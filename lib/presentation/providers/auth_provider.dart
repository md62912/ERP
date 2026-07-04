import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/supabase/supabase_client.dart';
import '../../domain/entities/employee.dart';
import '../../data/repositories/employee_repository_impl.dart';

/// Raw Supabase auth state stream (fires on sign-in, sign-out, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

/// Whether someone is currently signed in.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session != null || SupabaseService.currentUser != null;
});

/// The signed-in user's employee row (role, department, etc.) — this is
/// what drives role-based UI decisions client-side (RLS is the real
/// enforcement; this is just for showing/hiding menu items).
final currentEmployeeProvider = FutureProvider<Employee?>((ref) async {
  ref.watch(authStateProvider); // re-fetch on auth changes
  if (SupabaseService.currentUser == null) return null;
  try {
    return await EmployeeRepositoryImpl().getMyProfile();
  } catch (_) {
    return null;
  }
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentEmployeeProvider).valueOrNull?.role;
});

class AuthController {
  final SupabaseClient _client;
  AuthController(this._client);

  Future<void> signInWithPassword(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(SupabaseService.client);
});
