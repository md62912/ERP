import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts a caught exception into a short, human-readable message safe
/// to show a user -- raw Postgrest/Auth exceptions include internal
/// details (constraint names, SQL fragments) that look broken and leak
/// implementation details in a production app. The original error is
/// still logged via debugPrint for developer troubleshooting.
String friendlyError(Object error) {
  debugPrint('Error: $error');

  if (error is PostgrestException) {
    final code = error.code;
    final message = error.message.toLowerCase();

    if (code == '23505' || message.contains('duplicate key')) {
      return 'That value is already in use — please use a different one.';
    }
    if (code == '42501' || message.contains('row-level security') || message.contains('permission denied')) {
      return "You don't have permission to do that.";
    }
    if (code == '23503' || message.contains('foreign key')) {
      return 'This is linked to other records and cannot be changed right now.';
    }
    if (code == '23514' || message.contains('violates check constraint')) {
      return 'One of the values entered isn\'t valid.';
    }
    return 'Something went wrong saving that. Please try again.';
  }

  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('already registered') || message.contains('already exists')) {
      return 'An account with that email already exists.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('password') && message.contains('least')) {
      return 'Password is too short.';
    }
    return 'Something went wrong with that request. Please try again.';
  }

  if (error.toString().contains('SocketException') || error.toString().contains('Failed host lookup')) {
    return 'No internet connection. Please check your network and try again.';
  }

  return 'Something went wrong. Please try again.';
}
