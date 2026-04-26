-- Fix signup failure caused by legacy trigger expecting `profiles.username`

-- 1) Ensure column exists (legacy triggers + any old app versions)
alter table public.profiles
  add column if not exists username text;

-- Optional: keep usernames unique when present
create unique index if not exists profiles_username_unique_idx
  on public.profiles(username)
  where username is not null;

-- 2) Remove legacy/duplicate triggers that can break signup
-- Keep only the intended trigger: on_auth_user_created_create_profile

drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_created_profile on auth.users;

drop function if exists public.handle_new_user();
drop function if exists public.handle_new_user_profile();
