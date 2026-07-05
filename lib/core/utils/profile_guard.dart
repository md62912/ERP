import 'package:flutter/material.dart';

/// Shows a brief explanation when an action can't proceed because the
/// signed-in user's employee profile hasn't loaded yet. Replaces the
/// old `if (me == null) return;` pattern, which silently did nothing and
/// made buttons feel broken. Returns false so callers can early-return
/// while still giving the user feedback.
bool notifyProfileNotReady(BuildContext context) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Still loading your profile — please try again in a moment.",
        ),
      ),
    );
  }
  return false;
}
