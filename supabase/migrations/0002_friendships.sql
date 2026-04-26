-- Add missing tables/columns for Minimal Chat App

-- Ensure profiles has email (optional)
alter table public.profiles add column if not exists email text;

-- FRIENDSHIPS
create table if not exists public.friendships (
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

alter table public.friendships enable row level security;

-- Policies (drop+create to be re-runnable)
drop policy if exists "friendships_select_participants" on public.friendships;
create policy "friendships_select_participants" on public.friendships
for select using (auth.uid() = user_id or auth.uid() = friend_id);

drop policy if exists "friendships_insert_own" on public.friendships;
create policy "friendships_insert_own" on public.friendships
for insert with check (auth.uid() = user_id);

drop policy if exists "friendships_delete_own" on public.friendships;
create policy "friendships_delete_own" on public.friendships
for delete using (auth.uid() = user_id);
