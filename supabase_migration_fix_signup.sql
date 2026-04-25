-- Fix signup trigger failures causing "database error"
-- Ensure profiles.code is TEXT (not bpchar) to avoid padding issues.

alter table public.profiles
  alter column code type text using trim(code);

alter table public.profiles drop constraint if exists profiles_code_4digits;
alter table public.profiles
  add constraint profiles_code_4digits
  check (code ~ '^[0-9]{4}$');
