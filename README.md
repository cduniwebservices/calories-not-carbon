# 🌿 Calories Not Carbon - GPS Carbon Offset Tracking App

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-black.svg)](https://supabase.io)
[![Sentry](https://img.shields.io/badge/Monitoring-Sentry-red.svg)](https://sentry.io)

**Calories Not Carbon** is a premium, enterprise-grade Flutter application designed for real-time GPS activity tracking with a focus on environmental impact and carbon offsets. It transforms physical activity into measurable environmental contributions through a sleek, modern interface.

---

## 🚀 Key Features

### 📍 Precision GPS Tracking
- **Real-time Monitoring**: High-accuracy GPS tracking using `geolocator`.
- **Background Support**: Continued tracking even when the app is in the background or the screen is off via `flutter_foreground_task`.
- **Interactive Maps**: Live route visualization using OpenStreetMap (`flutter_map`) with dynamic polylines and custom markers.
- **Smart Logic**: Automatic pause detection and activity state management.

### 📊 Comprehensive Analytics
- **Live Metrics**: Real-time display of distance, speed, pace, calories, and duration.
- **Data Visualization**: Rich, interactive charts using `fl_chart` for session analysis.
- **History & Details**: Deep-dive into past activities with detailed route maps and performance statistics.

### 🔄 Cloud Sync & Offline-First
- **Local Cache**: Instant performance and offline availability using `Hive` and `Shared Preferences`.
- **Seamless Sync**: Automatic background synchronization with `Supabase` when connectivity is restored.
- **Device Identifiers**: Secure session management using unique device IDs (`uuid`).

### 🎨 Premium UI/UX
- **Modern Neon Aesthetic**: Custom dark-themed UI with "Neon" components and glowing effects.
- **Smooth Animations**: Integrated `flutter_animate` for fluid transitions and micro-interactions.
- **Haptic Feedback**: Tactile interaction responses via a dedicated `HapticService`.
- **Responsive Design**: Optimized for various screen sizes and orientations.

---

## 📱 Application Flow & Screens

The app follows a structured user journey from onboarding to detailed activity analysis:

1.  **Welcome Screen**: Introduction to the "Calories Not Carbon" mission.
2.  **Permission Onboarding**: Educational flow for Location and Activity Recognition permissions.
3.  **Goals Screen**: Interactive UI to set activity targets and browse potential achievements.
4.  **Enhanced Run Screen**: The core tracking interface featuring live maps and real-time statistics.
5.  **Session Summary**: Post-activity breakdown with maps, charts, and carbon offset calculations.
6.  **History Screen**: A chronological list of all tracked activities.
7.  **Activity Detail**: Granular analysis of a specific past session.
8.  **Debug Screen**: A hidden overlay for monitoring logs, cache state, and service status.

---

## 🛠️ Technical Stack

### Core Framework
- **Flutter SDK**: `^3.8.1`
- **State Management**: `flutter_riverpod` (Reactive and scalable)
- **Navigation**: `go_router` (Type-safe, declarative routing)

### Backend & Services
- **Supabase**: Primary database and cloud synchronization.
- **Hive**: High-performance local NoSQL database for offline storage.
- **Sentry**: Enterprise-grade error tracking and performance monitoring.
- **Geolocator**: Advanced GPS and location services.

### UI & UX
- **Mapping**: `flutter_map`, `latlong2`.
- **Charts**: `fl_chart`.
- **Animations**: `flutter_animate`.
- **Icons/Fonts**: `cupertino_icons`, `google_fonts`, `flutter_svg`.
- **Feedback**: `sensors_plus`, `haptic_feedback`.

---

## 🔧 External Services & Integration

### Supabase Setup
The app uses Supabase for cloud persistence. The schema includes:
- `activities`: Stores session data including `route_points` (JSONB), distance, duration, and calories.
- `activity_stats`: A database view for aggregated device statistics.
- **RLS (Row Level Security)**: Ensures data privacy based on `device_id`.

### Sentry Monitoring
Real-time crash reporting and performance profiling are handled via Sentry. Tracing is enabled for all startup and critical service operations.

### API Environment Variables
The app requires the following environment variables during build:
- `SUPABASE_URL`: Your Supabase project URL.
- `SUPABASE_ANON_KEY`: Your Supabase anonymous API key.
- `SENTRY_DSN`: Your Sentry project DSN.

---

## 🏗️ Project Architecture

```
lib/
├── components/         # Reusable UI elements (NeonCard, AppButton, InteractiveMap)
├── features/           # Feature-based modules (Run, Goals, History, Debug)
│   ├── fitness/        # Core tracking and analysis screens
│   ├── onboarding/     # Permission and setup flow
│   └── welcome/        # Entry point
├── models/             # Data entities (ActivitySession, RoutePoint)
├── providers/          # Riverpod state providers (ActivityProvider, GoalProvider)
├── services/           # Business logic layer (LocationService, SyncService, LocalStorage)
├── theme/              # Global design system and color palettes
└── utils/              # Helper functions and responsive design utilities
```

---

## 🚀 Getting Started

1.  **Clone the Repo**:
    ```bash
    git clone https://github.com/shujaatsunasra/Track-Your-Walk
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Run with Environment Variables**:
    ```bash
    flutter run \
      --dart-define=SUPABASE_URL=your_url \
      --dart-define=SUPABASE_ANON_KEY=your_key \
      --dart-define=SENTRY_DSN=your_dsn
    ```

---

## 🔬 Raw Sensor Data (Diagnostics)

Each waypoint records raw sensor data for cross-platform debugging. This data is stored in `rawSensorData` on the `ActivityWaypoint` model and flows through to both Hive (local) and Supabase (remote) without requiring schema changes, since `route_points` is a JSONB column.

### Fields recorded per waypoint

| Field | Description |
|-------|-------------|
| `platform` | `"ios"` or `"android"` |
| `rawAltitude` | Raw altitude from GPS (ellipsoidal on Android, MSL on iOS) |
| `geoidHeight` | Orthometric height after geoid correction (Android only) |
| `geoidUndulation` | Geoid N value: `rawAltitude - geoidHeight` (indicates if GeoidService is working) |
| `gpsAccuracy` | Horizontal accuracy in meters |
| `platformSpeed` | Raw speed from GPS (before any iOS -1.0 → 0.0 conversion) |
| `calculatedSpeed` | Speed after jitter filtering and processing |
| `distanceFromLastPoint` | Haversine distance from previous waypoint (meters) |
| `isDistanceReliable` | Whether distance exceeded GPS accuracy (jitter filter) |
| `barometricPressureHpa` | Current barometric pressure in hPa from device sensor |
| `barometricAltitudeMeters` | Relative altitude from barometer using the barometric formula (sensitive to ~0.5m changes) |
| `seaLevelPressureHpa` | Reference pressure captured at activity start (used as P0 in altitude calculation) |

### iOS vs Android altitude differences

- **iOS**: `CLLocation.altitude` is orthometric (MSL) — ready to use as-is
- **Android**: `Position.altitude` is ellipsoidal (WGS84) — requires geoid correction via `GeoidService`
- The `geoidUndulation` field reveals whether the EGM96 correction is being applied (should be ~10-25m in Australia, not 0)

### Barometric altitude

The device barometer (where available) provides pressure readings sensitive to ~0.5m altitude changes. The barometric altitude is calculated using:

```
h = 44330 × (1 - (P / P0)^(1/5.255))
```

Where `P` is the current pressure and `P0` is the reference pressure captured at the start of the activity. This gives **relative** altitude from the starting point — useful for detecting elevation gain on hills even when GPS altitude is inaccurate. Not all devices have a barometer sensor; the field will be `null` on devices without one.

---

*Last Updated: May 2026*
