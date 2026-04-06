import 'package:flutter/foundation.dart';

/// Service to access build-time version information
/// Version is injected at build time using dart-define
class VersionService {
  static const String _version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev-build',
  );

  /// Get the full version number (e.g., "1.261187")
  static String get version => _version;

  /// Get the major version component (e.g., 1)
  static int get majorVersion {
    final parts = _version.split('.');
    if (parts.isEmpty) return 0;
    return int.tryParse(parts[0]) ?? 0;
  }

  /// Get the minor version component as percentage (e.g., 0.261187)
  static double get minorVersion {
    final parts = _version.split('.');
    if (parts.length < 2) return 0.0;
    final minor = parts[1];
    // Convert back to decimal (e.g., "261187" -> 0.261187)
    if (minor.length <= 6) {
      final padded = minor.padRight(6, '0');
      return int.parse(padded) / 1000000.0;
    }
    return 0.0;
  }

  /// Get a formatted display string with build info
  static String get displayVersion {
    if (_version == 'dev-build') {
      return 'Development Build';
    }
    return 'v$_version';
  }

  /// Check if running a development build
  static bool get isDevBuild => _version == 'dev-build' || kDebugMode;
}
