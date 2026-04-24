import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/fitness_models.dart';
import 'enterprise_logger.dart';

/// Service to fetch weather and IP data from WeatherAPI.com
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _baseUrl = 'https://api.weatherapi.com/v1';
  
  // Use environment variable for API key
  static const String _apiKey = String.fromEnvironment('WEATHER_API_KEY');

  /// Fetch current weather for the given coordinates with retry logic
  Future<WeatherData?> getCurrentWeather(double lat, double lon, {int retries = 3}) async {
    if (_apiKey.isEmpty) {
      EnterpriseLogger().logWarning('Weather', 'API Key is missing. Weather data will not be fetched.');
      return null;
    }

    final url = Uri.parse('$_baseUrl/current.json?key=$_apiKey&q=$lat,$lon&aqi=no');
    
    int attempt = 0;
    while (attempt <= retries) {
      try {
        if (attempt > 0) {
          final backoff = Duration(seconds: attempt * 2);
          EnterpriseLogger().logInfo('Weather', 'Retry attempt $attempt after ${backoff.inSeconds}s...');
          await Future.delayed(backoff);
        }

        EnterpriseLogger().logInfo('Weather', 'Fetching weather for $lat, $lon (Attempt ${attempt + 1})', 
            metadata: {'url': url.toString().replaceFirst(_apiKey, '***')});

        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final current = data['current'];
          final location = data['location'];
          
          // Calculate UTC Offset reliably
          final int epochSeconds = location['localtime_epoch'] as int;
          final String localTimeStr = location['localtime'] as String; // "2026-04-11 13:56"
          
          String calculatedOffset = '+00:00';
          try {
            final parts = localTimeStr.split(' ');
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');

            // Create a UTC DateTime using the local clock values
            final localDateTimeAsUtc = DateTime.utc(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2]),
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );

            // Find the difference in minutes
            final int localEpochMinutes = localDateTimeAsUtc.millisecondsSinceEpoch ~/ 60000;
            final int utcEpochMinutes = epochSeconds ~/ 60;
            final int offsetMinutes = localEpochMinutes - utcEpochMinutes;
            
            final int hours = offsetMinutes ~/ 60;
            final int mins = offsetMinutes % 60;
            calculatedOffset = "${hours >= 0 ? '+' : '-'}${hours.abs().toString().padLeft(2, '0')}:${mins.abs().toString().padLeft(2, '0')}";
          } catch (e) {
            EnterpriseLogger().logWarning('Weather', 'Offset calculation error: $e');
          }

          final weatherLocation = WeatherLocation(
            name: location['name'] as String? ?? '',
            region: location['region'] as String? ?? '',
            country: location['country'] as String? ?? '',
            tzId: location['tz_id'] as String? ?? '',
            localtimeEpoch: epochSeconds,
            localtime: localTimeStr,
            utcOffset: calculatedOffset,
          );

          final weather = WeatherData(
            location: weatherLocation,
            lastUpdated: current['last_updated'] as String? ?? '',
            lastUpdatedEpoch: current['last_updated_epoch'] as int? ?? 0,
            tempC: (current['temp_c'] as num? ?? 0).toDouble(),
            isDay: current['is_day'] as int? ?? 0,
            conditionText: current['condition']['text'] as String? ?? '',
            conditionIcon: current['condition']['icon'] as String? ?? '',
            conditionCode: current['condition']['code'] as int? ?? 0,
            windKph: (current['wind_kph'] as num? ?? 0).toDouble(),
            windDegree: current['wind_degree'] as int? ?? 0,
            windDir: current['wind_dir'] as String? ?? '',
            pressureMb: (current['pressure_mb'] as num? ?? 0).toDouble(),
            precipMm: (current['precip_mm'] as num? ?? 0).toDouble(),
            humidity: current['humidity'] as int? ?? 0,
            cloud: current['cloud'] as int? ?? 0,
            feelsLikeC: (current['feelslike_c'] as num? ?? 0).toDouble(),
            windChillC: (current['windchill_c'] as num? ?? 0).toDouble(),
            heatIndexC: (current['heatindex_c'] as num? ?? 0).toDouble(),
            dewPointC: (current['dewpoint_c'] as num? ?? 0).toDouble(),
            visKm: (current['vis_km'] as num? ?? 0).toDouble(),
            uv: (current['uv'] as num? ?? 0).toDouble(),
            gustKph: (current['gust_kph'] as num? ?? 0).toDouble(),
          );

          EnterpriseLogger().logInfo('Weather', 'Successfully fetched weather', metadata: {
            'temp': weather.tempC,
            'condition': weather.conditionText,
            'city': weatherLocation.name
          });
          return weather;
        } else {
          EnterpriseLogger().logError('Weather', 'Failed to fetch weather. Status: ${response.statusCode}', null);
          EnterpriseLogger().logInfo('Weather', 'Response body: ${response.body}');
          // Non-200 status usually means we shouldn't retry (e.g., 401, 403, 400)
          return null;
        }
      } catch (e) {
        attempt++;
        if (attempt > retries) {
          EnterpriseLogger().logError('Weather', 'All retry attempts failed for weather fetch: $e', StackTrace.current);
          return null;
        }
        EnterpriseLogger().logWarning('Weather', 'Transient error during weather fetch (Attempt $attempt): $e');
      }
    }
    return null;
  }

  /// Fetch IP lookup data with retry logic
  Future<IpLookupData?> getIpLookup({String? ipAddress, int retries = 3}) async {
    if (_apiKey.isEmpty) {
      EnterpriseLogger().logWarning('Weather', 'API Key is missing. IP lookup will not be performed.');
      return null;
    }

    final query = ipAddress ?? 'auto:ip';
    final url = Uri.parse('$_baseUrl/ip.json?key=$_apiKey&q=$query');
    
    int attempt = 0;
    while (attempt <= retries) {
      try {
        if (attempt > 0) {
          final backoff = Duration(seconds: attempt * 2);
          await Future.delayed(backoff);
        }

        EnterpriseLogger().logInfo('Weather', 'Performing IP lookup (Attempt ${attempt + 1})...', metadata: {
          'url': url.toString().replaceFirst(_apiKey, '***'),
          'query': query,
        });

        final response = await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          final ipLookup = IpLookupData(
            ip: data['ip'] as String? ?? '',
            type: data['type'] as String? ?? '',
            continentCode: data['continent_code'] as String? ?? '',
            continentName: data['continent_name'] as String? ?? '',
            countryCode: data['country_code'] as String? ?? '',
            countryName: data['country_name'] as String? ?? '',
            isEu: data['is_eu']?.toString().toLowerCase() == 'true',
            geonameId: data['geoname_id'] as int? ?? 0,
            city: data['city'] as String? ?? '',
            region: data['region'] as String? ?? '',
          );

          EnterpriseLogger().logInfo('Weather', 'IP lookup successful', metadata: {
            'ip': ipLookup.ip,
            'city': ipLookup.city,
            'country': ipLookup.countryName
          });
          return ipLookup;
        } else {
          EnterpriseLogger().logError('Weather', 'IP lookup failed. Status: ${response.statusCode}', null);
          return null;
        }
      } catch (e) {
        attempt++;
        if (attempt > retries) {
          EnterpriseLogger().logError('Weather', 'All retry attempts failed for IP lookup: $e', StackTrace.current);
          return null;
        }
      }
    }
    return null;
  }
}
