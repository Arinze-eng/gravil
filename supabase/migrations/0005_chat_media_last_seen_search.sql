-- Features: user search, last_seen, media messages (image/voice)

-- PROFILES
alter table public.profiles
  add column if not exists last_seen timestamptz;

create index if not exists profiles_email_idx on public.profiles (email);
create index if not exists profiles_code_idx on public.profiles (code);
create index if not exists profiles_username_idx on public.profiles (username);

-- MESSAGES
-- Ensure base table exists
create table if not exists public.messages (
  id bigserial primary key,
  room_id text not null,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  message text,
  created_at timestamptz not null default now()
);

alter table public.messages
  add column if not exists content text,
  add column if not exists type text not null default 'text',
  add column if not exists media_path text,
  add column if not exists media_mime text,
  add column if not exists media_duration_ms int;

-- Keep compatibility: if old column `message` exists, mirror into `content`
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'messages' and column_name = 'message'
  ) then
    execute 'update public.messages set content = coalesce(content, message) where content is null';
  end if;
end $$;

create index if not exists messages_room_id_created_at_idx on public.messages(room_id, created_at);

-- RLS
alter table public.messages enable row level security;

drop policy if exists "messages_select_room_participants" on public.messages;
create policy "messages_select_room_participants" on public.messages
for select using (auth.uid() = sender_id or auth.uid() = receiver_id);

drop policy if exists "messages_insert_sender" on public.messages;
create policy "messages_insert_sender" on public.messages
for insert with check (auth.uid() = sender_id);

drop policy if exists "messages_delete_participants" on public.messages;
create policy "messages_delete_participants" on public.messages
for delete using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- STORAGE: chat media bucket
insert into storage.buckets (id, name, public)
values ('chat_media', 'chat_media', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload/download their own chat media.
-- (Simple policy: allow all authenticated; tighten later if needed.)

do $$
begin
  -- select
  execute 'drop policy if exists "chat_media_select" on storage.objects';
  execute 'create policy "chat_media_select" on storage.objects for select to authenticated using (bucket_id = ''chat_media'')';

  -- insert
  execute 'drop policy if exists "chat_media_insert" on storage.objects';
  execute 'create policy "chat_media_insert" on storage.objects for insert to authenticated with check (bucket_id = ''chat_media'')';

  -- update
  execute 'drop policy if exists "chat_media_update" on storage.objects';
  execute 'create policy "chat_media_update" on storage.objects for update to authenticated using (bucket_id = ''chat_media'') with check (bucket_id = ''chat_media'')';

  -- delete
  execute 'drop policy if exists "chat_media_delete" on storage.objects';
  execute 'create policy "chat_media_delete" on storage.objects for delete to authenticated using (bucket_id = ''chat_media'')';
exception
  when undefined_table then
    -- storage schema not available in some local setups
    null;
end $$;
