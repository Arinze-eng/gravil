package com.sjsu.boreas.supabase;

import android.content.Context;
import android.content.SharedPreferences;

public class SessionManager {
    private static final String PREFS = "chat_prefs";

    private final SharedPreferences sp;

    public SessionManager(Context ctx) {
        sp = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    public void saveSession(String accessToken, String refreshToken, String userId, String email) {
        sp.edit()
                .putString("access_token", accessToken)
                .putString("refresh_token", refreshToken)
                .putString("user_id", userId)
                .putString("email", email)
                .apply();
    }

    public void saveProfile(String name, String code) {
        sp.edit()
                .putString("name", name)
                .putString("code", code)
                .apply();
    }

    public String getAccessToken() { return sp.getString("access_token", null); }
    public String getRefreshToken() { return sp.getString("refresh_token", null); }
    public String getUserId() { return sp.getString("user_id", null); }
    public String getEmail() { return sp.getString("email", null); }
    public String getName() { return sp.getString("name", null); }
    public String getCode() { return sp.getString("code", null); }

    public void clear() {
        sp.edit().clear().apply();
    }
}
