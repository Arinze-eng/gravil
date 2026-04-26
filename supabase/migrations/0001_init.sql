-- Minimal Chat App initial schema (Supabase)

-- PROFILES
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

-- FRIENDSHIPS (mutual contacts)
create table if not exists public.friendships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

-- MESSAGES
create table if not exists public.messages (
  id bigserial primary key,
  room_id text not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists messages_room_id_created_at_idx on public.messages(room_id, created_at);
create index if not exists messages_receiver_created_at_idx on public.messages(receiver_id, created_at);

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.messages enable row level security;

-- PROFILES policies
create policy "profiles_select_all" on public.profiles
for select using (true);

create policy "profiles_insert_own" on public.profiles
for insert with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
for update using (auth.uid() = id);

-- FRIENDSHIPS policies
create policy "friendships_select_participants" on public.friendships
for select using (auth.uid() = user_id or auth.uid() = friend_id);

create policy "friendships_insert_own" on public.friendships
for insert with check (auth.uid() = user_id);

create policy "friendships_delete_own" on public.friendships
for delete using (auth.uid() = user_id);

-- MESSAGES policies
create policy "messages_select_room_participants" on public.messages
for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "messages_insert_sender" on public.messages
for insert with check (auth.uid() = sender_id);

-- Optional: allow receiver to delete their received messages
create policy "messages_delete_participants" on public.messages
for delete using (auth.uid() = sender_id or auth.uid() = receiver_id);
