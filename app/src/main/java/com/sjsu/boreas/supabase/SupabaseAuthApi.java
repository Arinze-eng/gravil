package com.sjsu.boreas.supabase;

import org.json.JSONObject;

import java.io.IOException;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class SupabaseAuthApi {
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");
    private final OkHttpClient http = new OkHttpClient();

    public JSONObject signUp(String name, String email, String password) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("email", email);
            body.put("password", password);
            JSONObject data = new JSONObject();
            data.put("name", name);
            body.put("data", data);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/auth/v1/signup";
        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "{}";
            JSONObject out = new JSONObject(raw);
            out.put("http_status", resp.code());
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONObject signInWithPassword(String email, String password) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("email", email);
            body.put("password", password);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/auth/v1/token?grant_type=password";
        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Content-Type", "application/json")
                .post(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "{}";
            JSONObject out = new JSONObject(raw);
            out.put("http_status", resp.code());
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONObject getUser(String accessToken) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/auth/v1/user";
        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer " + accessToken)
                .get()
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "{}";
            JSONObject out = new JSONObject(raw);
            out.put("http_status", resp.code());
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public void signOut(String accessToken) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/auth/v1/logout";
        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer " + accessToken)
                .post(RequestBody.create("", JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            // ignore
        }
    }
}
