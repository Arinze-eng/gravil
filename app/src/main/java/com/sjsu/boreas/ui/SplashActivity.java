package com.sjsu.boreas.ui;

import android.content.Intent;
import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;

import com.sjsu.boreas.supabase.SessionManager;
import com.sjsu.boreas.supabase.SupabaseAuthApi;
import com.sjsu.boreas.ui.auth.LoginActivity;
import com.sjsu.boreas.ui.main.UsersActivity;

import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SplashActivity extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(com.sjsu.boreas.R.layout.activity_splash);

        SessionManager sm = new SessionManager(this);
        String token = sm.getAccessToken();

        if (token == null) {
            startActivity(new Intent(this, LoginActivity.class));
            finish();
            return;
        }

        exec.execute(() -> {
            try {
                SupabaseAuthApi auth = new SupabaseAuthApi();
                JSONObject me = auth.getUser(token);
                int status = me.optInt("http_status", 0);

                runOnUiThread(() -> {
                    if (status == 200) {
                        startActivity(new Intent(this, UsersActivity.class));
                    } else {
                        sm.clear();
                        startActivity(new Intent(this, LoginActivity.class));
                    }
                    finish();
                });
            } catch (Exception e) {
                runOnUiThread(() -> {
                    sm.clear();
                    startActivity(new Intent(this, LoginActivity.class));
                    finish();
                });
            }
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        exec.shutdownNow();
    }
}
