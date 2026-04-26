-- Gravil initial schema

-- PROFILES
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  public_id text not null unique,
  last_seen timestamptz,
  created_at timestamptz not null default now()
);

-- MESSAGES
create table if not exists public.messages (
  id bigserial primary key,
  room_id text not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('text','image','voice','file')),
  content text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists messages_room_id_created_at_idx on public.messages(room_id, created_at);
create index if not exists messages_receiver_read_idx on public.messages(receiver_id, read_at);

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.messages enable row level security;

-- PROFILES policies
create policy "profiles_select_all" on public.profiles
for select using (true);

create policy "profiles_insert_own" on public.profiles
for insert with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = id);

-- MESSAGES policies
create policy "messages_select_room_participants" on public.messages
for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "messages_insert_sender" on public.messages
for insert with check (auth.uid() = sender_id);

create policy "messages_update_receiver_read" on public.messages
for update using (auth.uid() = receiver_id);
