package com.sjsu.boreas.supabase;

import org.json.JSONObject;

import java.io.File;
import java.io.IOException;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class SupabaseStorageApi {
    private final OkHttpClient http = new OkHttpClient();

    public void uploadObject(String accessToken, String bucket, String path, File file, String mime) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/storage/v1/object/" + bucket + "/" + path;
        MediaType mt = mime != null ? MediaType.get(mime) : MediaType.get("application/octet-stream");

        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer " + accessToken)
                .addHeader("x-upsert", "true")
                .put(RequestBody.create(file, mt))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            if (!resp.isSuccessful()) {
                String raw = resp.body() != null ? resp.body().string() : "";
                throw new IOException("Upload failed: " + resp.code() + " " + raw);
            }
        }
    }

    public String createSignedUrl(String accessToken, String bucket, String path, int expiresInSeconds) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/storage/v1/object/sign/" + bucket + "/" + path;
        JSONObject body = new JSONObject();
        body.put("expiresIn", expiresInSeconds);

        Request req = new Request.Builder()
                .url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer " + accessToken)
                .addHeader("Content-Type", "application/json")
                .post(RequestBody.create(body.toString(), MediaType.get("application/json; charset=utf-8")))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "{}";
            if (!resp.isSuccessful()) throw new IOException("Signed URL failed: " + resp.code() + " " + raw);
            JSONObject json = new JSONObject(raw);
            String signedUrl = json.getString("signedURL");
            if (signedUrl.startsWith("http")) return signedUrl;
            return SupabaseConfig.SUPABASE_URL + signedUrl;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }
}
