package com.sjsu.boreas.ui.main;

import android.content.Intent;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.widget.Button;
import android.widget.EditText;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.sjsu.boreas.R;
import com.sjsu.boreas.supabase.SessionManager;
import com.sjsu.boreas.supabase.SupabaseRestApi;
import com.sjsu.boreas.ui.auth.LoginActivity;
import com.sjsu.boreas.ui.chat.ChatActivity;
import com.sjsu.boreas.ui.settings.SettingsActivityNew;

import org.json.JSONArray;
import org.json.JSONObject;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class UsersActivity extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();
    private UsersAdapter adapter;
    private SessionManager sm;
    private SupabaseRestApi rest;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_users);

        sm = new SessionManager(this);
        rest = new SupabaseRestApi();

        String token = sm.getAccessToken();
        if (token == null) {
            startActivity(new Intent(this, LoginActivity.class));
            finish();
            return;
        }

        RecyclerView rv = findViewById(R.id.recycler);
        rv.setLayoutManager(new LinearLayoutManager(this));
        adapter = new UsersAdapter(u -> {
            if (u.id.equals(sm.getUserId())) {
                Toast.makeText(this, "That's you", Toast.LENGTH_SHORT).show();
                return;
            }
            Intent i = new Intent(this, ChatActivity.class);
            i.putExtra("other_id", u.id);
            i.putExtra("other_name", u.name);
            i.putExtra("other_code", u.code);
            startActivity(i);
        });
        rv.setAdapter(adapter);

        Button settings = findViewById(R.id.btn_settings);
        settings.setOnClickListener(v -> startActivity(new Intent(this, SettingsActivityNew.class)));

        EditText search = findViewById(R.id.search);
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {}
            @Override public void afterTextChanged(Editable s) {
                load(s.toString().trim());
            }
        });

        load("");
    }

    @Override
    protected void onResume() {
        super.onResume();
        pingLastSeen();
    }

    private void pingLastSeen() {
        String token = sm.getAccessToken();
        String uid = sm.getUserId();
        if (token == null || uid == null) return;

        String iso = OffsetDateTime.now().toString();
        exec.execute(() -> {
            try {
                rest.updateLastSeenIso(token, uid, iso);
            } catch (Exception ignored) {}
        });
    }

    private void load(String q) {
        String token = sm.getAccessToken();
        if (token == null) return;

        exec.execute(() -> {
            try {
                JSONArray arr = rest.searchProfiles(token, q);
                ArrayList<UserProfile> out = new ArrayList<>();
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject o = arr.getJSONObject(i);
                    out.add(new UserProfile(
                            o.getString("id"),
                            o.optString("name", ""),
                            o.optString("code", ""),
                            o.optString("last_seen", null)
                    ));
                }
                runOnUiThread(() -> adapter.setItems(out));
            } catch (Exception e) {
                runOnUiThread(() -> Toast.makeText(this, "Search error: " + e.getMessage(), Toast.LENGTH_SHORT).show());
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        exec.shutdownNow();
    }
}
