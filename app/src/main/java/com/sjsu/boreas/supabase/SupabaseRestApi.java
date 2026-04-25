package com.sjsu.boreas.supabase;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

public class SupabaseRestApi {
    private static final MediaType JSON = MediaType.get("application/json; charset=utf-8");
    private final OkHttpClient http = new OkHttpClient();

    private Request.Builder base(String url, String accessToken) {
        return new Request.Builder().url(url)
                .addHeader("apikey", SupabaseConfig.SUPABASE_ANON_KEY)
                .addHeader("Authorization", "Bearer " + accessToken)
                .addHeader("Accept", "application/json");
    }

    private static String enc(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8);
    }

    public JSONObject fetchMyProfile(String accessToken, String userId) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/profiles?id=eq." + enc(userId) + "&select=id,name,code,email,last_seen";
        Request req = base(url, accessToken).get().build();
        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            JSONArray arr = new JSONArray(raw);
            JSONObject out = new JSONObject();
            out.put("http_status", resp.code());
            if (arr.length() > 0) out.put("profile", arr.getJSONObject(0));
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONArray searchProfiles(String accessToken, String q) throws IOException {
        String or;
        if (q != null && q.matches("\\d{4}")) {
            or = "(code.eq." + enc(q) + ",name.ilike.*" + enc(q) + "*)";
        } else {
            or = "(name.ilike.*" + enc(q) + "*)";
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/profiles?select=id,name,code,last_seen&or=" + or + "&limit=50";
        Request req = base(url, accessToken).get().build();
        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            return new JSONArray(raw);
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public void updateLastSeenIso(String accessToken, String userId, String isoTs) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("last_seen", isoTs);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/profiles?id=eq." + enc(userId);
        Request req = base(url, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=minimal")
                .patch(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            // ignore
        }
    }

    public JSONObject getOrCreateConversation(String accessToken, String me, String other) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/conversations?select=id,user_a,user_b&or=(and(user_a.eq."
                + enc(me) + ",user_b.eq." + enc(other) + "),and(user_a.eq." + enc(other) + ",user_b.eq." + enc(me) + "))&limit=1";
        Request getReq = base(url, accessToken).get().build();

        try (Response resp = http.newCall(getReq).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            JSONArray arr = new JSONArray(raw);
            if (arr.length() > 0) {
                JSONObject out = new JSONObject();
                out.put("conversation", arr.getJSONObject(0));
                return out;
            }
        } catch (Exception e) {
            throw new IOException(e);
        }

        JSONObject body;
        try {
            body = new JSONObject();
            body.put("user_a", me);
            body.put("user_b", other);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String createUrl = SupabaseConfig.SUPABASE_URL + "/rest/v1/conversations";
        Request postReq = base(createUrl, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=representation")
                .post(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(postReq).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            JSONArray arr = new JSONArray(raw);
            JSONObject out = new JSONObject();
            if (arr.length() > 0) out.put("conversation", arr.getJSONObject(0));
            out.put("http_status", resp.code());
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONArray fetchMessages(String accessToken, String conversationId, String sinceIso) throws IOException {
        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/messages?select=id,conversation_id,sender_id,receiver_id,kind,body,media_url,media_type,media_size_bytes,created_at,read_at"
                + "&conversation_id=eq." + enc(conversationId) + "&order=created_at.asc";
        if (sinceIso != null) {
            url += "&created_at=gt." + enc(sinceIso);
        }
        Request req = base(url, accessToken).get().build();
        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            return new JSONArray(raw);
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONObject sendTextMessage(String accessToken, String conversationId, String senderId, String receiverId, String text) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("conversation_id", conversationId);
            body.put("sender_id", senderId);
            body.put("receiver_id", receiverId);
            body.put("kind", "text");
            body.put("body", text);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/messages";
        Request req = base(url, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=representation")
                .post(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            JSONArray arr = new JSONArray(raw);
            JSONObject out = new JSONObject();
            out.put("http_status", resp.code());
            if (arr.length() > 0) out.put("message", arr.getJSONObject(0));
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public JSONObject createMediaMessagePlaceholder(String accessToken, String conversationId, String senderId, String receiverId, String kind, String mime, long sizeBytes) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("conversation_id", conversationId);
            body.put("sender_id", senderId);
            body.put("receiver_id", receiverId);
            body.put("kind", kind);
            body.put("media_type", mime);
            body.put("media_size_bytes", sizeBytes);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/messages";
        Request req = base(url, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=representation")
                .post(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            String raw = resp.body() != null ? resp.body().string() : "[]";
            JSONArray arr = new JSONArray(raw);
            JSONObject out = new JSONObject();
            out.put("http_status", resp.code());
            if (arr.length() > 0) out.put("message", arr.getJSONObject(0));
            return out;
        } catch (Exception e) {
            throw new IOException(e);
        }
    }

    public void updateMessageMediaUrl(String accessToken, String messageId, String mediaUrl) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("media_url", mediaUrl);
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/messages?id=eq." + enc(messageId);
        Request req = base(url, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=minimal")
                .patch(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            // ignore
        }
    }

    public void markConversationRead(String accessToken, String conversationId, String me) throws IOException {
        JSONObject body;
        try {
            body = new JSONObject();
            body.put("read_at", java.time.OffsetDateTime.now().toString());
        } catch (Exception e) {
            throw new IOException(e);
        }

        String url = SupabaseConfig.SUPABASE_URL + "/rest/v1/messages?conversation_id=eq." + enc(conversationId)
                + "&receiver_id=eq." + enc(me) + "&read_at=is.null";

        Request req = base(url, accessToken)
                .addHeader("Content-Type", "application/json")
                .addHeader("Prefer", "return=minimal")
                .patch(RequestBody.create(body.toString(), JSON))
                .build();

        try (Response resp = http.newCall(req).execute()) {
            // ignore
        }
    }
}
