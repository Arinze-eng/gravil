# Validation report (code + database)

## ✅ Fixed issues found

### 1) **Supabase `profiles` insert was failing**
Your Supabase `public.profiles` table requires **NOT NULL**:
- `email`
- `name`
- `code` (must be **4 digits** and **unique**)

But the first migration version of the app was doing an upsert with only `id` + `email`, which would fail at runtime.

**Fix applied:** `AuthService` now creates/updates a profile correctly:
- `name` = email prefix
- `code` = random 4-digit with retry to avoid unique collisions

File:
- `lib/features/auth/service/auth_service.dart`

### 2) **Friend add flow violated RLS**
Your RLS policy for `public.friendships` allows inserting only rows where:
- `auth.uid() = user_id`

Old code tried to create **two rows** (mutual friendship), including one where `user_id = friendId`, which would be rejected by RLS.

**Fix applied:** `addFriend()` now inserts only:
- `(user_id = me, friend_id = friend)`

File:
- `lib/features/chatlist/service/chat_service.dart`

### 3) **Dart syntax bug in register dialog string**
`register_view.dart` had an invalid string continuation using `\`.

**Fix applied:** switched to normal adjacent string literals.

File:
- `lib/features/auth/view/register_view.dart`

## ✅ Database checks performed (via Supabase MCP)

### Tables verified
- `public.profiles` (RLS enabled)
- `public.messages` (RLS enabled)
- `public.friendships` (RLS enabled)

### Policies verified
- `profiles_select_all`, `profiles_insert_own`, `profiles_update_own`
- `messages_select_room_participants`, `messages_insert_sender`, `messages_update_receiver_read`
- `friendships_select_participants`, `friendships_insert_own`, `friendships_delete_own`

## Remaining note (not an error)
Local sandbox cannot run `flutter analyze`/`flutter test` because Flutter SDK isn’t installed here.
But the **runtime-critical** schema/RLS mismatches (the real production breakers) were found and patched.
