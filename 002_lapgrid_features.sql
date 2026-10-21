
-- LAPGRID 002: Add vehicle and lap record features
-- Safe additive migration: do not drop existing tables.

-- Vehicle specifications
alter table public.vehicles
  add column if not exists induction text
    check (induction in ('NA', 'turbo', 'supercharger', 'hybrid', 'electric', 'other')),
  add column if not exists front_tire_brand text,
  add column if not exists front_tire_model text,
  add column if not exists front_tire_size text,
  add column if not exists rear_tire_brand text,
  add column if not exists rear_tire_model text,
  add column if not exists rear_tire_size text;

-- Lap sector times (milliseconds) and top speed (km/h)
alter table public.lap_records
  add column if not exists sector1_time_ms integer
    check (sector1_time_ms is null or sector1_time_ms > 0),
  add column if not exists sector2_time_ms integer
    check (sector2_time_ms is null or sector2_time_ms > 0),
  add column if not exists sector3_time_ms integer
    check (sector3_time_ms is null or sector3_time_ms > 0),
  add column if not exists sector4_time_ms integer
    check (sector4_time_ms is null or sector4_time_ms > 0),
  add column if not exists top_speed_kmh numeric(6,2)
    check (top_speed_kmh is null or top_speed_kmh > 0);

-- Social links for driver profiles
alter table public.profiles
  add column if not exists x_url text,
  add column if not exists instagram_url text,
  add column if not exists youtube_url text,
  add column if not exists website_url text;

-- Helpful index for vehicle lookup
create index if not exists vehicles_owner_idx
  on public.vehicles(owner_id);
