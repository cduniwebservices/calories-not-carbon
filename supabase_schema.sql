-- Supabase schema for Calories Not Carbon
-- Run this in your Supabase SQL Editor

-- Activities table: stores GPS tracking sessions
CREATE TABLE IF NOT EXISTS activities (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  activity_type TEXT NOT NULL DEFAULT 'running',
  state TEXT NOT NULL DEFAULT 'completed',
  total_distance_meters DOUBLE PRECISION DEFAULT 0,
  total_duration_ms BIGINT DEFAULT 0,
  active_duration_ms BIGINT DEFAULT 0,
  average_speed_mps DOUBLE PRECISION DEFAULT 0,
  max_speed_mps DOUBLE PRECISION DEFAULT 0,
  estimated_calories INTEGER DEFAULT 0,
  total_steps INTEGER DEFAULT 0,
  elevation_gain DOUBLE PRECISION DEFAULT 0,
  is_valid BOOLEAN DEFAULT true,
  activity_replaced TEXT,
  start_weather JSONB,
  start_ip_lookup JSONB,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  route_points JSONB DEFAULT '[]',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_activities_device_id ON activities(device_id);
CREATE INDEX IF NOT EXISTS idx_activities_start_time ON activities(start_time);
CREATE INDEX IF NOT EXISTS idx_activities_activity_type ON activities(activity_type);

-- Row Level Security (RLS) policies
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read their own activities
CREATE POLICY "Users can view their own activities"
  ON activities
  FOR SELECT
  USING (device_id = current_setting('app.device_id', true));

-- Allow inserts from any authenticated user
CREATE POLICY "Allow inserts from authenticated users"
  ON activities
  FOR INSERT
  WITH CHECK (true);

-- Allow users to update their own activities
CREATE POLICY "Users can update their own activities"
  ON activities
  FOR UPDATE
  USING (device_id = current_setting('app.device_id', true));

-- View: Summary stats per device
CREATE OR REPLACE VIEW activity_stats AS
SELECT
  device_id,
  COUNT(*) as total_activities,
  SUM(total_distance_meters) / 1000 as total_distance_km,
  SUM(estimated_calories) as total_calories,
  SUM(total_duration_ms) / 1000 / 60 as total_duration_minutes,
  AVG(average_speed_mps) * 3.6 as avg_speed_kmh,
  MAX(max_speed_mps) * 3.6 as max_speed_kmh
FROM activities
GROUP BY device_id;
