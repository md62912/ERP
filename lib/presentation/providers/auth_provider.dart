import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/local/local_cache.dart';
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

/// Set to true whenever a data provider falls back to a locally cached
/// value because the live fetch failed (almost always: no network).
/// Screens can watch this to show a small "offline" indicator instead of
/// pretending the (possibly stale) data is current.
/// Tracks whether the most recent profile resolution came from the
/// offline cache. Written only from inside currentEmployeeProvider's async
/// body (never touching another provider mid-build, which Riverpod
/// forbids and which previously caused the dashboard to hang), and read
/// back through [isShowingCachedDataProvider].
bool _lastProfileFromCache = false;

/// Whether the dashboard is currently showing a cached (offline) profile.
/// Derived by watching the employee provider so it recomputes whenever the
/// profile resolves, without any provider mutating another during build.
final isShowingCachedDataProvider = Provider<bool>((ref) {
  final employee = ref.watch(currentEmployeeProvider);
  // Only meaningful once a value has resolved; while loading/erroring we
  // report "not cached" so no stale banner flashes.
  return employee.hasValue && employee.value != null && _lastProfileFromCache;
});

const _cachedProfileKey = 'employee_profile';

/// The signed-in user's employee row (role, department, etc.) — this is
/// what drives role-based UI decisions client-side (RLS is the real
/// enforcement; this is just for showing/hiding menu items).
///
/// Falls back to the last cached profile if the live fetch fails (no
/// network), so the app remains at least partially usable offline
/// instead of the whole UI going blank because this one query failed.
final currentEmployeeProvider = FutureProvider<Employee?>((ref) async {
  ref.watch(authStateProvider); // re-fetch on auth changes
  if (SupabaseService.currentUser == null) return null;
  try {
    final employee = await EmployeeRepositoryImpl().getMyProfile();
    // Best-effort cache write; must never break the profile load.
    try {
      await LocalCache.setJsonWithTimestamp(_cachedProfileKey, employee.toJson());
    } catch (_) {}
    _lastProfileFromCache = false;
    return employee;
  } catch (_) {
    final cached = LocalCache.getMap(_cachedProfileKey);
    if (cached != null) {
      _lastProfileFromCache = true;
      return Employee.fromJson(cached);
    }
    _lastProfileFromCache = false;
    return null;
  }
});

final currentUserRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentEmployeeProvider).valueOrNull?.role;
});

/// Whether the current auth state came from clicking a password-reset
/// email link. Supabase's client fires a dedicated `passwordRecovery`
/// event for this (distinct from a normal sign-in), so this is purely
/// derived from the stream -- no manual flag-setting needed. It clears
/// itself once a different auth event fires (e.g. `userUpdated`, which
/// Supabase emits right after a successful password change).
final isPasswordRecoveryProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.event == AuthChangeEvent.passwordRecovery;
});

class AuthController {
  final SupabaseClient _client;
  AuthController(this._client);

  Future<void> signInWithPassword(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Sends a password-reset email. [redirectTo] should point back at this
  /// app (e.g. the GitHub Pages URL) -- Supabase's Auth settings must have
  /// that URL allow-listed under Authentication > URL Configuration >
  /// Redirect URLs, or the link in the email won't be able to return here.
  Future<void> resetPasswordForEmail(String email, {required String redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  /// Sets a new password for the currently-recovering session (only valid
  /// right after following a password-reset email link).
  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(SupabaseService.client);
});
