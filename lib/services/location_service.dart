import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool success;
  final String? errorMessage;

  const LocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.success,
    this.errorMessage,
  });
}

class LocationService {
  /// Obtiene la ubicación GPS satelital con un timeout estricto para no demorar la app
  static Future<LocationResult> getCurrentLocation({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return const LocationResult(
          success: false,
          errorMessage: 'El GPS del teléfono está desactivado.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            success: false,
            errorMessage: 'Permiso de ubicación denegado.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          success: false,
          errorMessage: 'El permiso de ubicación fue denegado permanentemente.',
        );
      }

      // Obtener posición con precisión equilibrada y timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        success: true,
      );
    } catch (_) {
      return const LocationResult(
        success: false,
        errorMessage: 'No se pudo obtener la señal satelital a tiempo.',
      );
    }
  }

  /// Abre la configuración del sistema para activar el GPS
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
