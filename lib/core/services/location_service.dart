import 'package:geolocator/geolocator.dart';

/// Result of attempting to capture a location for attendance. Location
/// capture is best-effort: if permission is denied or GPS is unavailable,
/// check-in should still succeed rather than block someone from clocking
/// in over a device/permission issue -- [position] is simply null in
/// that case.
class LocationCapture {
  final Position? position;
  final String? error;
  const LocationCapture({this.position, this.error});
}

class LocationService {
  LocationService._();

  /// Requests permission (if needed) and returns the current position.
  /// Never throws -- returns a [LocationCapture] with a null position and
  /// a human-readable [error] if anything prevented capture, so callers
  /// can proceed with check-in regardless.
  static Future<LocationCapture> tryCapture() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationCapture(error: 'Location services are turned off on this device.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationCapture(error: 'Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationCapture(error: 'Location permission is permanently denied. Enable it in system settings to have check-ins logged.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return LocationCapture(position: position);
    } catch (e) {
      return LocationCapture(error: 'Could not determine location: $e');
    }
  }

  /// Distance in meters between two coordinates.
  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
