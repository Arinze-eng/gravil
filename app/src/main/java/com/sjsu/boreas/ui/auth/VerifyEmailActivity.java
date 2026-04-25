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

import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class VerifyEmailActivity extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_verify_email);

        EditText email = findViewById(R.id.email);
        Button resend = findViewById(R.id.btn_resend);
        TextView status = findViewById(R.id.status);

        // Prefill email if we have it
        String prefEmail = getIntent().getStringExtra("email");
        if (prefEmail == null) {
            prefEmail = new SessionManager(this).getEmail();
        }
        if (prefEmail != null) email.setText(prefEmail);

        resend.setOnClickListener(v -> {
            status.setText("");
            String e = email.getText().toString().trim();
            if (e.isEmpty()) {
                status.setText("Enter your email");
                return;
            }
            resend.setEnabled(false);
            exec.execute(() -> {
                try {
                    JSONObject resp = new SupabaseAuthApi().resendSignupVerificationEmail(e);
                    int code = resp.optInt("http_status", 0);
                    runOnUiThread(() -> {
                        resend.setEnabled(true);
                        if (code == 200) {
                            status.setText("Verification email resent. Check Spam/Junk too.");
                        } else {
                            String msg = resp.optString("msg", resp.optString("message", resp.toString()));
                            status.setText("Resend failed: " + msg);
                        }
                    });
                } catch (Exception ex) {
                    runOnUiThread(() -> {
                        resend.setEnabled(true);
                        status.setText("Resend error: " + ex.getMessage());
                    });
                }
            });
        });

        Button back = findViewById(R.id.btn_back);
        back.setOnClickListener(v -> {
            startActivity(new Intent(this, LoginActivity.class));
            finish();
        });
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        exec.shutdownNow();
    }
}
