import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

/// Service for calculating geoid undulation (separation) using EGM96 model.
/// This allows converting ellipsoidal height to orthometric height (MSL).
/// H = h - N
class GeoidService {
  static final GeoidService _instance = GeoidService._internal();
  factory GeoidService() => _instance;
  GeoidService._internal();

  static const String _assetPath = 'assets/datasets/egm96-15.pgm';
  static const int _width = 1440; // 360 * 4
  static const int _height = 721; // 180 * 4 + 1
  
  Uint16List? _grid;
  double _offset = -108.0;
  double _scale = 0.003;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the service by loading the EGM96 grid from assets.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🌍 GeoidService: Loading EGM96-15 grid...');
      final data = await rootBundle.load(_assetPath);
      final buffer = data.buffer.asUint8List();

      // Find the start of binary data after PGM header
      // Header ends after the line with "65535"
      int dataOffset = _findDataOffset(buffer);
      if (dataOffset == 0) {
        throw Exception('Invalid PGM header in $_assetPath');
      }

      // GeographicLib PGM files use Big-Endian 16-bit integers
      final byteData = ByteData.view(data.buffer);
      _grid = Uint16List(_width * _height);
      
      for (int i = 0; i < _grid!.length; i++) {
        _grid![i] = byteData.getUint16(dataOffset + (i * 2), Endian.big);
      }

      _isInitialized = true;
      debugPrint('✅ GeoidService: EGM96-15 grid loaded successfully');
    } catch (e) {
      debugPrint('❌ GeoidService: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Find the offset where binary data starts in the PGM file.
  int _findDataOffset(Uint8List buffer) {
    int newlinesFound = 0;
    // PGM P5 header:
    // P5
    // # comments...
    // width height
    // maxval
    // binary data starts here
    
    // We look for the 4th line that doesn't start with '#' after the first line.
    // Actually, a safer way is to find "65535" and the next newline.
    
    String header = String.fromCharCodes(buffer.sublist(0, 1000));
    List<String> lines = header.split('\n');
    
    int currentOffset = 0;
    int lineIndex = 0;
    
    // Skip P5
    currentOffset += lines[0].length + 1;
    lineIndex++;
    
    // Skip comments
    while (lineIndex < lines.length && lines[lineIndex].startsWith('#')) {
      currentOffset += lines[lineIndex].length + 1;
      lineIndex++;
    }
    
    // Skip width height
    if (lineIndex < lines.length) {
      currentOffset += lines[lineIndex].length + 1;
      lineIndex++;
    }
    
    // Skip maxval (65535)
    if (lineIndex < lines.length) {
      currentOffset += lines[lineIndex].length + 1;
    }
    
    return currentOffset;
  }

  /// Get the geoid undulation (N) for a given coordinate.
  /// [lat] Latitude in degrees (-90 to 90)
  /// [lon] Longitude in degrees (-180 to 180 or 0 to 360)
  double getUndulation(double lat, double lon) {
    if (!_isInitialized || _grid == null) {
      return 0.0;
    }

    // Normalize longitude to [0, 360)
    double normalizedLon = lon % 360;
    if (normalizedLon < 0) normalizedLon += 360;

    // Normalize latitude to [90, -90] (grid starts at 90N)
    double normalizedLat = lat.clamp(-90, 90);

    // Map lat/lon to grid coordinates (15-minute grid = 4 points per degree)
    double x = normalizedLon * 4;
    double y = (90 - normalizedLat) * 4;

    int x0 = x.floor() % _width;
    int x1 = (x0 + 1) % _width;
    int y0 = y.floor().clamp(0, _height - 1);
    int y1 = (y0 + 1).clamp(0, _height - 1);

    double dx = x - x.floor();
    double dy = y - y.floor();

    // Bilinear interpolation
    double v00 = _grid![y0 * _width + x0].toDouble();
    double v10 = _grid![y0 * _width + x1].toDouble();
    double v01 = _grid![y1 * _width + x0].toDouble();
    double v11 = _grid![y1 * _width + x1].toDouble();

    double val = (v00 * (1 - dx) * (1 - dy) +
                  v10 * dx * (1 - dy) +
                  v01 * (1 - dx) * dy +
                  v11 * dx * dy);
    
    return _offset + (val * _scale);
  }

  /// Convert ellipsoidal height to orthometric height (Mean Sea Level).
  /// H = h - N
  double getOrthometricHeight(double ellipsoidalHeight, double lat, double lon) {
    final n = getUndulation(lat, lon);
    return ellipsoidalHeight - n;
  }
}
