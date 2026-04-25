package com.sjsu.boreas.ui.chat;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.media.MediaRecorder;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.sjsu.boreas.R;
import com.sjsu.boreas.supabase.SessionManager;
import com.sjsu.boreas.supabase.SupabaseRestApi;
import com.sjsu.boreas.supabase.SupabaseStorageApi;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class ChatActivity extends AppCompatActivity {

    private static final int REQ_PICK_IMAGE = 1001;
    private static final int REQ_PERMS = 2001;

    private final ExecutorService exec = Executors.newSingleThreadExecutor();
    private final Handler handler = new Handler(Looper.getMainLooper());

    private SessionManager sm;
    private SupabaseRestApi rest;
    private SupabaseStorageApi storage;

    private String otherId;
    private String otherName;
    private String conversationId;

    private MessagesAdapter adapter;
    private String lastSeenIso = null;

    private MediaRecorder recorder;
    private File recordingFile;
    private boolean recording = false;

    private final Runnable poller = new Runnable() {
        @Override
        public void run() {
            pollOnce();
            handler.postDelayed(this, 2000);
        }
    };

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_chat_new);

        sm = new SessionManager(this);
        rest = new SupabaseRestApi();
        storage = new SupabaseStorageApi();

        otherId = getIntent().getStringExtra("other_id");
        otherName = getIntent().getStringExtra("other_name");
        String otherCode = getIntent().getStringExtra("other_code");

        TextView header = findViewById(R.id.header);
        header.setText(otherName + " (" + otherCode + ")");

        RecyclerView rv = findViewById(R.id.recycler);
        rv.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MessagesAdapter(sm.getUserId(), m -> {
            // media_url stores object path, e.g. {conversation_id}/{message_id}/{filename}
            return storage.createSignedUrl(sm.getAccessToken(), "chat-media", m.mediaUrl, 3600);
        });
        rv.setAdapter(adapter);

        EditText input = findViewById(R.id.input);
        Button send = findViewById(R.id.btn_send);
        ImageButton img = findViewById(R.id.btn_image);
        ImageButton voice = findViewById(R.id.btn_voice);

        send.setOnClickListener(v -> {
            String text = input.getText().toString();
            if (text.trim().isEmpty()) return;
            input.setText("");
            sendText(text);
        });

        img.setOnClickListener(v -> {
            if (!ensurePermissions()) return;
            Intent i = new Intent(Intent.ACTION_PICK);
            i.setType("image/*");
            startActivityForResult(i, REQ_PICK_IMAGE);
        });

        voice.setOnClickListener(v -> {
            if (!ensurePermissions()) return;
            if (!recording) {
                startRecording();
                voice.setImageResource(android.R.drawable.ic_media_pause);
            } else {
                stopRecordingAndUpload();
                voice.setImageResource(android.R.drawable.ic_btn_speak_now);
            }
        });

        initConversation();
    }

    private boolean ensurePermissions() {
        ArrayList<String> need = new ArrayList<>();
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            need.add(Manifest.permission.RECORD_AUDIO);
        }
        if (Build.VERSION.SDK_INT >= 33) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) != PackageManager.PERMISSION_GRANTED) {
                need.add(Manifest.permission.READ_MEDIA_IMAGES);
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                need.add(Manifest.permission.READ_EXTERNAL_STORAGE);
            }
        }
        if (!need.isEmpty()) {
            ActivityCompat.requestPermissions(this, need.toArray(new String[0]), REQ_PERMS);
            return false;
        }
        return true;
    }

    private void initConversation() {
        String token = sm.getAccessToken();
        String me = sm.getUserId();
        if (token == null || me == null || otherId == null) {
            Toast.makeText(this, "Session error", Toast.LENGTH_SHORT).show();
            finish();
            return;
        }

        exec.execute(() -> {
            try {
                JSONObject resp = rest.getOrCreateConversation(token, me, otherId);
                JSONObject conv = resp.getJSONObject("conversation");
                conversationId = conv.getString("id");
                runOnUiThread(() -> handler.post(poller));
            } catch (Exception e) {
                runOnUiThread(() -> {
                    Toast.makeText(this, "Conversation error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                    finish();
                });
            }
        });
    }

    private void pollOnce() {
        if (conversationId == null) return;
        String token = sm.getAccessToken();
        String me = sm.getUserId();
        if (token == null || me == null) return;

        exec.execute(() -> {
            try {
                JSONArray arr = rest.fetchMessages(token, conversationId, lastSeenIso);
                if (arr.length() > 0) {
                    ArrayList<MessageItem> out = new ArrayList<>();
                    for (int i = 0; i < arr.length(); i++) {
                        JSONObject o = arr.getJSONObject(i);
                        out.add(new MessageItem(
                                o.getString("id"),
                                o.getString("sender_id"),
                                o.optString("kind", "text"),
                                o.optString("body", ""),
                                o.optString("media_url", null),
                                o.optString("media_type", null),
                                o.optLong("media_size_bytes", 0),
                                o.optString("created_at", ""),
                                o.optString("read_at", null)
                        ));
                        lastSeenIso = o.optString("created_at", lastSeenIso);
                    }
                    runOnUiThread(() -> {
                        adapter.addItems(out);
                        RecyclerView rv = findViewById(R.id.recycler);
                        rv.scrollToPosition(adapter.getItemCount() - 1);
                    });
                }

                // Mark read
                rest.markConversationRead(token, conversationId, me);

            } catch (Exception ignored) {
            }
        });
    }

    private void sendText(String text) {
        String token = sm.getAccessToken();
        String me = sm.getUserId();
        if (token == null || me == null || conversationId == null) return;

        exec.execute(() -> {
            try {
                rest.sendTextMessage(token, conversationId, me, otherId, text);
            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(this, "Send failed: " + e.getMessage(), Toast.LENGTH_SHORT).show());
            }
        });
    }

    private void sendImage(Uri uri) {
        String token = sm.getAccessToken();
        String me = sm.getUserId();
        if (token == null || me == null || conversationId == null) return;

        exec.execute(() -> {
            try {
                File f = FileUtils.copyUriToCache(this, uri, "img");
                long size = f.length();
                if (size > 3145728) {
                    runOnUiThread(() -> Toast.makeText(this, "Image must be <= 3MB", Toast.LENGTH_SHORT).show());
                    return;
                }

                String mime = "image/*";
                JSONObject msgResp = rest.createMediaMessagePlaceholder(token, conversationId, me, otherId, "image", mime, size);
                JSONObject msg = msgResp.getJSONObject("message");
                String messageId = msg.getString("id");

                String path = conversationId + "/" + messageId + "/image.jpg";
                storage.uploadObject(token, "chat-media", path, f, "image/jpeg");
                rest.updateMessageMediaUrl(token, messageId, path);

            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(this, "Image send error: " + e.getMessage(), Toast.LENGTH_SHORT).show());
            }
        });
    }

    private void startRecording() {
        try {
            recordingFile = new File(getCacheDir(), "voice_" + System.currentTimeMillis() + ".m4a");
            recorder = new MediaRecorder();
            recorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            recorder.setAudioEncodingBitRate(64000);
            recorder.setAudioSamplingRate(44100);
            recorder.setOutputFile(recordingFile.getAbsolutePath());
            recorder.prepare();
            recorder.start();
            recording = true;
            Toast.makeText(this, "Recording... tap again to stop", Toast.LENGTH_SHORT).show();
        } catch (Exception e) {
            recording = false;
            recorder = null;
            Toast.makeText(this, "Record error: " + e.getMessage(), Toast.LENGTH_SHORT).show();
        }
    }

    private void stopRecordingAndUpload() {
        try {
            if (recorder != null) {
                recorder.stop();
                recorder.release();
            }
        } catch (Exception ignored) {
        }
        recorder = null;
        recording = false;

        if (recordingFile == null) return;
        long size = recordingFile.length();
        if (size > 4194304) {
            Toast.makeText(this, "Voice note must be <= 4MB", Toast.LENGTH_SHORT).show();
            return;
        }

        String token = sm.getAccessToken();
        String me = sm.getUserId();
        if (token == null || me == null || conversationId == null) return;

        File f = recordingFile;
        exec.execute(() -> {
            try {
                JSONObject msgResp = rest.createMediaMessagePlaceholder(token, conversationId, me, otherId, "voice", "audio/mp4", size);
                JSONObject msg = msgResp.getJSONObject("message");
                String messageId = msg.getString("id");

                String path = conversationId + "/" + messageId + "/voice.m4a";
                storage.uploadObject(token, "chat-media", path, f, "audio/mp4");
                rest.updateMessageMediaUrl(token, messageId, path);
            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(this, "Voice send error: " + e.getMessage(), Toast.LENGTH_SHORT).show());
            }
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PICK_IMAGE && resultCode == Activity.RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) sendImage(uri);
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (recording) {
            stopRecordingAndUpload();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        handler.removeCallbacks(poller);
        exec.shutdownNow();
    }
}
