package com.sjsu.boreas.ui.auth;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.sjsu.boreas.R;
import com.sjsu.boreas.supabase.SessionManager;
import com.sjsu.boreas.supabase.SupabaseAuthApi;
import com.sjsu.boreas.supabase.SupabaseRestApi;
import com.sjsu.boreas.ui.main.UsersActivity;

import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LoginActivity extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_login_new);

        EditText email = findViewById(R.id.email);
        EditText password = findViewById(R.id.password);
        Button btnLogin = findViewById(R.id.btn_login);
        Button btnSignup = findViewById(R.id.btn_signup);
        TextView status = findViewById(R.id.status);

        btnSignup.setOnClickListener(v -> startActivity(new Intent(this, SignupActivity.class)));

        btnLogin.setOnClickListener(v -> {
            status.setText("");
            String e = email.getText().toString().trim();
            String p = password.getText().toString();
            if (e.isEmpty() || p.isEmpty()) {
                status.setText("Email and password are required");
                return;
            }

            btnLogin.setEnabled(false);

            exec.execute(() -> {
                try {
                    SupabaseAuthApi auth = new SupabaseAuthApi();
                    JSONObject tokenResp = auth.signInWithPassword(e, p);
                    int code = tokenResp.optInt("http_status", 0);
                    if (code != 200) {
                        String msg = tokenResp.optString("error_description", tokenResp.optString("msg", tokenResp.toString()));
                        runOnUiThread(() -> {
                            btnLogin.setEnabled(true);
                            status.setText("Login failed: " + msg);
                        });
                        return;
                    }

                    String accessToken = tokenResp.getString("access_token");
                    String refreshToken = tokenResp.optString("refresh_token", null);

                    JSONObject me = auth.getUser(accessToken);
                    if (me.optInt("http_status", 0) != 200) {
                        runOnUiThread(() -> {
                            btnLogin.setEnabled(true);
                            status.setText("Login failed: can't fetch user");
                        });
                        return;
                    }

                    String confirmedAt = me.optString("email_confirmed_at", null);
                    if (confirmedAt == null || confirmedAt.equals("null") || confirmedAt.isEmpty()) {
                        runOnUiThread(() -> {
                            btnLogin.setEnabled(true);
                            startActivity(new Intent(this, VerifyEmailActivity.class));
                            finish();
                        });
                        return;
                    }

                    String userId = me.getString("id");

                    SessionManager sm = new SessionManager(this);
                    sm.saveSession(accessToken, refreshToken, userId, e);

                    // Fetch profile (name/code)
                    SupabaseRestApi rest = new SupabaseRestApi();
                    JSONObject profileResp = rest.fetchMyProfile(accessToken, userId);
                    JSONObject profile = profileResp.optJSONObject("profile");
                    if (profile != null) {
                        sm.saveProfile(profile.optString("name", ""), profile.optString("code", ""));
                    }

                    runOnUiThread(() -> {
                        startActivity(new Intent(this, UsersActivity.class));
                        finish();
                    });

                } catch (Exception ex) {
                    runOnUiThread(() -> {
                        btnLogin.setEnabled(true);
                        status.setText("Login error: " + ex.getMessage());
                    });
                }
            });
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        exec.shutdownNow();
    }
}
