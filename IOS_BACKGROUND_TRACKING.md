# iOS Background Tracking Implementation

This document describes the iOS background tracking implementation for the Calories Not Carbon app.

## Problem Statement

iOS background location tracking was not working reliably. The app would stop tracking when:
- The app was backgrounded (home button pressed)
- The screen was locked/turned off
- After a period of time in the background

Android background tracking was working perfectly with `flutter_foreground_task`, but iOS has different background execution constraints.

## Root Cause Analysis

The original implementation relied on `flutter_foreground_task` and `geolocator` for background tracking on both platforms. However:

1. **iOS Foreground Task Limitations**: `flutter_foreground_task` on iOS only shows a notification; the actual task execution is not guaranteed when the app is suspended
2. **No iOS-Specific Handling**: The app didn't use native iOS `CLLocationManager` with proper background configuration
3. **Missing Background Indicator**: No blue bar indicator was shown when using background location (required by Apple guidelines)
4. **Permission Flow Issues**: The iOS "Always" authorization wasn't requested using the native iOS flow
5. **No Background Fetch**: The app couldn't wake up periodically to check/restore tracking state

## Solution Overview

The implementation adds iOS-specific native code paths while keeping Android functionality unchanged:

### Platform Detection
```dart
bool get _isIOS => Platform.isIOS;
```

All location tracking code now branches based on platform, with:
- **iOS**: Native `CLLocationManager` via platform channels
- **Android**: Original `geolocator` + `flutter_foreground_task` (unchanged)

## Files Changed

### 1. `pubspec.yaml`
**Added:**
```yaml
background_fetch: ^1.3.2
```

### 2. `ios/Runner/Info.plist`
**Added:**
- Background fetch configuration
- BGTaskScheduler permissions for iOS 13+
- UIApplicationBackgroundFetchInterval set to 0 (immediate)

### 3. `ios/Runner/AppDelegate.swift`
**Added:**
- Method channel setup for Flutter <-> iOS communication
- Event channel for location stream updates
- Background fetch handling for `background_fetch` package

### 4. `ios/Runner/LocationManager.swift` (NEW)
**Features:**
- Native iOS `CLLocationManager` implementation
- Background location indicator (blue bar) support
- Significant location change monitoring for battery efficiency
- Proper iOS "Always" authorization handling
- Throttled location updates (1 second minimum interval)

### 5. `lib/services/ios_location_service.dart` (NEW)
**Purpose:** Flutter wrapper for iOS native location service
**Features:**
- Method channel communication with Swift code
- Event channel for location stream
- "Always" authorization status checking
- Background location indicator control
- Distance filter configuration

### 6. `lib/services/location_service.dart`
**Changes:**
- Added `dart:io` import for platform detection
- Added `_isIOS` getter
- Added iOS-specific initialization (native service + indicator)
- Modified `startTracking()` to use iOS native service on iOS
- Modified `stopTracking()` to stop iOS native service on iOS
- Added disposal of iOS resources

**Android Behavior:** Completely unchanged

### 7. `lib/services/permission_service.dart`
**Changes:**
- Added iOS-specific permission request flow
- Uses native iOS `requestAlwaysAuthorization()` for proper iOS authorization
- Maps iOS native status to permission_handler status enum
- Updates permission state monitoring to check native iOS status

### 8. `lib/services/background_fetch_service.dart` (NEW)
**Purpose:** iOS background fetch implementation
**Features:**
- Global callbacks for background execution
- Configurable fetch interval (minimum 15 minutes on iOS)
- Headless task support (executes even when app is terminated)
- Task scheduling for custom background operations
- Status monitoring and simulation for testing

### 9. `lib/main.dart`
**Changes:**
- Added `dart:io` import
- Imported `background_fetch_service.dart`
- Added iOS-only background fetch initialization
- Configured background fetch callbacks for:
  - Regular background fetch: Sync pending data
  - Headless execution: Sync pending data (app terminated)

## How It Works

### iOS Background Tracking Flow

1. **App Launch** (`main.dart`):
   - Detects iOS platform
   - Initializes `BackgroundFetchService` with sync callbacks
   - Starts background fetch with 15-minute minimum interval

2. **Permission Request** (`permission_service.dart`):
   - Requests "When In Use" via `permission_handler`
   - Uses native iOS `requestAlwaysAuthorization()` for "Always" permission
   - Maps native status to Flutter permission enum

3. **Location Service Initialization** (`location_service.dart`):
   - iOS: Initializes `IOSLocationService` (platform channel)
   - Enables background location indicator (blue bar)
   - Sets 5-meter distance filter

4. **Tracking Start** (`location_service.dart`):
   - iOS: Checks for "Always" authorization
   - iOS: Starts native `CLLocationManager` with:
     - `startUpdatingLocation()` (high accuracy)
     - `startMonitoringSignificantLocationChanges()` (background reliability)
   - iOS: Listens to native location stream via event channel
   - Android: Original behavior unchanged (Geolocator + foreground task)

5. **Background Execution**:
   - iOS: Native `CLLocationManager` continues running in background
   - iOS: Blue bar indicates location usage to user
   - iOS: Significant location changes trigger updates even if standard updates pause
   - Android: Foreground task continues running

6. **Background Fetch** (`background_fetch_service.dart`):
   - iOS: App wakes every 15+ minutes (iOS decides exact timing)
   - Syncs pending activities to Supabase
   - Can be extended to resume tracking if needed

### Key iOS Behaviors

1. **Background Location Indicator**: Blue bar appears at top of screen when app uses location in background
2. **Always Authorization Required**: iOS "Always" permission is mandatory for background tracking
3. **App Store Compliance**: Implementation follows Apple guidelines for background location
4. **Battery Efficiency**: Uses significant location changes + 5m distance filter to conserve battery

## Testing

### Simulator Testing
```bash
# Simulate background fetch on iOS Simulator
# In Xcode: Debug -> Simulate Background Fetch
```

### Device Testing
1. Install app on physical iOS device
2. Grant "Always" location permission
3. Start a workout
4. Lock screen or background the app
5. Verify blue location indicator appears
6. Wait 5-15 minutes
7. Unlock and verify tracking continued

### Debug Logs
Look for these log messages:
```
🍎 LocationService: Starting iOS native tracking...
✅ LocationManager: Started tracking with background support
📍 LocationManager: Location update - Lat: X, Lng: Y
🔄 BackgroundFetchService: Background fetch triggered
```

## Known Limitations

1. **iOS Background Fetch Timing**: Minimum interval is 15 minutes, but iOS decides actual execution time based on battery, usage patterns, etc.

2. **App Termination**: If user force-quits app (swipe up in app switcher), background tracking stops. This is an iOS limitation, not app limitation.

3. **Background Location Indicator**: Blue bar is required and shown to user per Apple guidelines.

4. **Battery Usage**: Background location uses more battery; iOS may throttle based on usage patterns.

## Platform Parity

| Feature | Android | iOS |
|---------|---------|-----|
| Background Service | `flutter_foreground_task` (notification) | Native `CLLocationManager` |
| Location Stream | `geolocator` stream | Native event channel |
| Permission | Standard location permission | "Always" authorization required |
| Background Indicator | Notification | Blue location bar |
| Background Fetch | Not needed | `background_fetch` package |
| Significant Changes | N/A | Enabled for battery efficiency |

## Future Improvements

1. **Background Fetch Resume**: Extend background fetch to automatically resume tracking if a workout was interrupted
2. **Geofencing**: Add geofence triggers for automatic workout start/stop
3. **Watch Connectivity**: Support Apple Watch for extended background tracking
4. **TestFlight Testing**: Validate with TestFlight external testers

## References

- [Apple Documentation: Getting the User's Location](https://developer.apple.com/documentation/corelocation/getting_the_user_s_location)
- [Apple Documentation: CLLocationManager](https://developer.apple.com/documentation/corelocation/cllocationmanager)
- [background_fetch package](https://pub.dev/packages/background_fetch)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
