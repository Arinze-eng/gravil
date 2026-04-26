-- Profiles improvements + automatic creation trigger

-- Ensure profiles columns used by the app exist
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists code text;

-- Make `code` unique when present
create unique index if not exists profiles_code_unique_idx on public.profiles(code) where code is not null;

-- Generate a 4-digit code that's not already used
create or replace function public.generate_unique_profile_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  tries int := 0;
begin
  loop
    tries := tries + 1;
    if tries > 50 then
      raise exception 'Could not allocate unique profile code';
    end if;

    v_code := lpad((floor(random()*10000))::int::text, 4, '0');
    exit when not exists (select 1 from public.profiles where code = v_code);
  end loop;

  return v_code;
end;
$$;

-- Create profile row when a new auth user is created
create or replace function public.handle_new_user_create_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_email text;
  v_name text;
  v_code text;
begin
  v_email := new.email;
  v_name := split_part(coalesce(v_email, 'user@example.com'), '@', 1);
  v_code := public.generate_unique_profile_code();

  insert into public.profiles (id, email, name, code)
  values (new.id, v_email, v_name, v_code)
  on conflict (id) do update
    set email = excluded.email,
        name = excluded.name;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_profile on auth.users;
create trigger on_auth_user_created_create_profile
after insert on auth.users
for each row execute procedure public.handle_new_user_create_profile();
