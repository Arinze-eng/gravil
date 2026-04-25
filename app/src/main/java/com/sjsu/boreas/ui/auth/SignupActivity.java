package com.sjsu.boreas.ui.auth;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.sjsu.boreas.R;
import com.sjsu.boreas.supabase.SupabaseAuthApi;

import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SignupActivity extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_signup);

        EditText name = findViewById(R.id.name);
        EditText email = findViewById(R.id.email);
        EditText password = findViewById(R.id.password);
        Button btn = findViewById(R.id.btn_create);
        TextView status = findViewById(R.id.status);

        btn.setOnClickListener(v -> {
            status.setText("");
            String n = name.getText().toString().trim();
            String e = email.getText().toString().trim();
            String p = password.getText().toString();

            if (n.isEmpty() || e.isEmpty() || p.isEmpty()) {
                status.setText("Name, email and password are required");
                return;
            }
            if (p.length() < 6) {
                status.setText("Password must be at least 6 characters");
                return;
            }

            btn.setEnabled(false);

            exec.execute(() -> {
                try {
                    SupabaseAuthApi auth = new SupabaseAuthApi();
                    JSONObject resp = auth.signUp(n, e, p);
                    int code = resp.optInt("http_status", 0);
                    if (code != 200 && code != 201) {
                        String msg = resp.optString("msg", resp.optString("message", resp.toString()));
                        runOnUiThread(() -> {
                            btn.setEnabled(true);
                            status.setText("Signup failed: " + msg);
                        });
                        return;
                    }

                    runOnUiThread(() -> {
                        Intent i = new Intent(this, VerifyEmailActivity.class);
                        i.putExtra("email", e);
                        startActivity(i);
                        finish();
                    });

                } catch (Exception ex) {
                    runOnUiThread(() -> {
                        btn.setEnabled(true);
                        status.setText("Signup error: " + ex.getMessage());
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
