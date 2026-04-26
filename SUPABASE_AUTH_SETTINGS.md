# Supabase: Disable Email Verification (Confirm Signup)

Your Flutter app expects **email confirmation to be OFF** so users are logged in immediately after signup.

## Hosted Supabase (Dashboard)

1. Open your project: https://supabase.com/dashboard/project/ljnparociyyggmxdewwv
2. Go to: **Authentication → Providers**
3. Under **Email**, turn **Confirm email** OFF
4. Save.

After this, `supabase.auth.signUp(...)` will return a non-null `session` and the app will route to the chat screen automatically.

## Local Supabase (CLI)

This repo now includes `supabase/config.toml` with:

- `auth.email.enable_confirmations = false`

So when you run Supabase locally, confirmations are disabled by default.

## Note about MCP

The current Supabase MCP toolset available here can list projects and run SQL, but it does **not** expose a management API endpoint to toggle **Auth → Confirm email** for hosted projects. That switch must be changed in the dashboard.
