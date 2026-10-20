-- LAPGRID initial schema for Supabase / PostgreSQL
-- Apply in Supabase SQL Editor after creating a project.
create extension if not exists pgcrypto;

create type public.record_visibility as enum ('public', 'private');
create type public.proof_type as enum ('self_reported', 'gps_log', 'official_result');
create type public.surface_condition as enum ('dry', 'damp', 'wet', 'mixed', 'unknown');
create type public.warmer_usage as enum ('used', 'not_used', 'unknown');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Track Driver',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.circuits (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  course_name text not null default '',
  country_code char(2) not null default 'JP',
  latitude double precision,
  longitude double precision,
  length_m integer,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name, course_name)
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  nickname text,
  make text,
  model text not null,
  chassis_code text,
  model_year integer,
  power_ps integer,
  weight_kg numeric(7,2),
  drivetrain text check (drivetrain in ('FF','FR','MR','RR','4WD','other')),
  class_name text,
  setup_notes text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicles_owner_idx on public.vehicles(owner_id);

create table public.lap_records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id uuid references public.vehicles(id) on delete set null,
  circuit_id uuid references public.circuits(id) on delete restrict,
  circuit_name text not null,
  course_name text not null default '',
  session_date date not null,
  session_time timestamptz,
  lap_time_ms integer not null check (lap_time_ms > 0),
  driver_display_name text not null,
  vehicle_display_name text not null,
  power_ps integer,
  vehicle_weight_kg numeric(7,2),
  tire_brand text not null,
  tire_model text not null,
  tire_size text not null,
  tire_condition text,
  tire_pressure_value numeric(5,2),
  tire_pressure_unit text check (tire_pressure_unit in ('bar','kpa','psi')),
  weather text,
  surface public.surface_condition not null default 'unknown',
  air_temp_c numeric(5,2),
  track_temp_c numeric(5,2),
  pressure_hpa numeric(7,2),
  pressure_kind text check (pressure_kind in ('station','sea_level','unknown')) default 'unknown',
  wind_speed_ms numeric(5,2),
  wind_direction text,
  weather_source text,
  weather_observed_at timestamptz,
  warmer public.warmer_usage not null default 'unknown',
  warmer_brand text,
  warmer_model text,
  warmer_set_temp_c numeric(5,2),
  warmer_duration_min integer check (warmer_duration_min is null or warmer_duration_min >= 0),
  tire_temp_after_warming_c numeric(5,2),
  proof public.proof_type not null default 'self_reported',
  proof_url text,
  notes text,
  visibility public.record_visibility not null default 'public',
  moderation_status text not null default 'pending' check (moderation_status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index lap_records_public_rank_idx on public.lap_records(circuit_name, course_name, lap_time_ms)
  where visibility = 'public' and moderation_status = 'approved';
create index lap_records_owner_date_idx on public.lap_records(owner_id, session_date desc);
create index lap_records_tire_idx on public.lap_records(tire_brand, tire_model);

-- Create a profile for every new account.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', 'Track Driver'));
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.circuits enable row level security;
alter table public.vehicles enable row level security;
alter table public.lap_records enable row level security;

create policy "Profiles are publicly readable" on public.profiles
  for select using (true);
create policy "Users update their own profile" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Users insert their own profile" on public.profiles
  for insert with check (auth.uid() = id);

create policy "Active circuits are readable" on public.circuits
  for select using (is_active = true);
-- Circuit creation/editing is intentionally admin-only; manage seed data from SQL initially.

create policy "Public vehicles or own vehicles are readable" on public.vehicles
  for select using (owner_id = auth.uid());
create policy "Users create own vehicles" on public.vehicles
  for insert with check (owner_id = auth.uid());
create policy "Users update own vehicles" on public.vehicles
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Users delete own vehicles" on public.vehicles
  for delete using (owner_id = auth.uid());

create policy "Read public approved records or own records" on public.lap_records
  for select using (
    (visibility = 'public' and moderation_status = 'approved') or owner_id = auth.uid()
  );
create policy "Users create own records" on public.lap_records
  for insert with check (owner_id = auth.uid());
create policy "Users update own records" on public.lap_records
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Users delete own records" on public.lap_records
  for delete using (owner_id = auth.uid());

-- Seed a small initial circuit list. Confirm track names/course variants before public launch.
insert into public.circuits (name, course_name, latitude, longitude) values
  ('筑波サーキット', 'TC2000', 36.1508, 140.0768),
  ('鈴鹿サーキット', '南コース', 34.8431, 136.5410),
  ('セントラルサーキット', '', 34.9780, 134.9860),
  ('富士スピードウェイ', '', 35.3717, 138.9267)
on conflict (name, course_name) do nothing;
-- Prevent regular authenticated users from approving their own lap records.
-- Apply after 001_initial_schema.sql. Admin approval must be performed by a trusted
-- server-side process using the service role key; never expose that key in browser code.
create or replace function public.enforce_lap_record_moderation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.uid() is not null then
    if tg_op = 'INSERT' then
      new.moderation_status := 'pending';
    else
      new.moderation_status := old.moderation_status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_lap_record_moderation on public.lap_records;
create trigger enforce_lap_record_moderation
before insert or update on public.lap_records
for each row execute function public.enforce_lap_record_moderation();
