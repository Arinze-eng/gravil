# Gravil (Flutter + Supabase)

A navy-blue chat app:
- Email + password sign up/sign in (no email verification — configure this in Supabase Auth settings)
- User profiles with **unique 5-digit public ID** (`public_id`) visible in search
- 1:1 chat: text, image (max **4MB**), voice note (max **5MB**), files
- Last seen (updated every 30s while logged in)
- Read receipts (single tick = sent, double tick = read)
- Optional **VPN toggle** (Android VPNService scaffold + platform channel)

## Configure Supabase

Build/run with:

- `--dart-define=SUPABASE_URL=...`
- `--dart-define=SUPABASE_ANON_KEY=...`

### Database
Apply SQL migration from `supabase/migrations/0001_init.sql`.

### Storage buckets
Create buckets:
- `images` (public)
- `voice` (public)
- `files` (public)

## GitHub Actions

Workflow builds a debug APK on each push.

## VPN Note

VPN is scaffolded in `android/.../VpnTunnelService.kt` and wired to Flutter via `MethodChannel('gravil/vpn')`.
To make it a real sing-box/Xray tunnel, plug sing-box core execution + config generation into that service.

## CI Secrets
This repo has GitHub Actions secrets set: SUPABASE_URL and SUPABASE_ANON_KEY.

