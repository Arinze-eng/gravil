# Chat + VPN (Native Java)

A native **Java** Android chat app backed by **Supabase** with:

- Email + password signup
- **Email verification required** before login (Supabase Auth confirmation email)
- Unique **4-digit chat code** auto-generated on signup (stored in `public.profiles.code`)
- Search users by name or 4-digit code
- 1-to-1 chat (text, images <= 3MB, voice notes <= 4MB)
- Last seen (updates `profiles.last_seen`)
- Read receipts (uses `messages.read_at`)
- In-app **SSL VPN** toggle (Android `VpnService`) with app-only tunneling

## Supabase

Project URL and anon key are configured in:

- `app/src/main/java/com/sjsu/boreas/supabase/SupabaseConfig.java`

Database migrations were applied via Supabase MCP. The important tables already present in your project:

- `public.profiles`
- `public.conversations`
- `public.messages`
- `public.groups`, `public.group_members`, `public.group_messages`

Additional migration added:

- `public.group_message_reads`
- storage bucket `chat-media`

## VPN config

The VPN settings are loaded from:

- `app/src/main/assets/vpn_config.json`

Edit that file to match your SSL payload/server/SNI.

## GitHub Actions (Build APK)

Workflow:

- `.github/workflows/android.yml`

On every push to `main` it builds `assembleDebug` and uploads the APK as an artifact.

### Optional signed release

Add these repository secrets to enable `assembleRelease` signing:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Run locally

Open in Android Studio, let it download SDK, then run.

