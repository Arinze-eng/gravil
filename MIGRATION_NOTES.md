# Gravil / Minimal Chat App — Firebase ➜ Supabase migration notes

## What changed
- Firebase dependencies removed.
- Supabase auth + database used instead.
- **Email verification flow** added:
  - After sign-up, user is prompted to verify email.
  - **Resend verification email** button provided.
  - If a user tries to sign up again and Supabase returns *already registered*, the UI switches them to **Login**.
- Chat + contacts migrated:
  - Contacts stored in `public.friendships`.
  - Messages stored in `public.messages` (compatible with the existing Gravil schema: `type`, `content`, `created_at`, etc.).
- Android build: removed Google Services (Firebase) Gradle plugin.

## Supabase project
This project is configured to use runtime values:
- `--dart-define=SUPABASE_URL=...`
- `--dart-define=SUPABASE_ANON_KEY=...`

Fallback values are present in `lib/services/supabase_client.dart` for local dev.

## Database migrations
- `supabase/migrations/0002_friendships.sql` was applied to your Supabase project (`ljnparociyyggmxdewwv`) via MCP.

## GitHub Actions APK build
Workflow: `.github/workflows/build-apk.yml`

Required repo secrets:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Artifacts:
- `app-arm64-v8a-release.apk` uploaded as `app-apk-arm64`

## Pushing to GitHub (safe commands)
I did **not** use the GitHub token you pasted in chat (treat it as compromised; rotate it in GitHub).

Suggested steps:
1. Clone your repo
   - `git clone https://github.com/Arinze-eng/gravil.git`
2. Replace repo contents with this project (or copy files into the repo folder)
3. Commit + push
   - `git add -A`
   - `git commit -m "Migrate Firebase to Supabase + APK CI"`
   - `git push -u origin main`
4. Trigger a build
   - Push again or use **Run workflow** in GitHub Actions.

To monitor runs with GitHub CLI:
- `gh run list --limit 5`
- `gh run watch <run_id>`
