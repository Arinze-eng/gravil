package com.sjsu.boreas.ui.settings;

import android.content.Intent;
import android.net.VpnService;
import android.os.Build;
import android.os.Bundle;
import android.widget.Button;
import android.widget.Switch;
import android.widget.TextView;

import androidx.appcompat.app.AppCompatActivity;

import com.sjsu.boreas.R;
import com.sjsu.boreas.SSLVPNService;
import com.sjsu.boreas.supabase.SessionManager;
import com.sjsu.boreas.supabase.SupabaseAuthApi;
import com.sjsu.boreas.ui.auth.LoginActivity;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class SettingsActivityNew extends AppCompatActivity {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();

    private Switch vpnSwitch;
    private SessionManager sm;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings_new);

        sm = new SessionManager(this);

        TextView title = findViewById(R.id.title);
        TextView sub = findViewById(R.id.sub);
        vpnSwitch = findViewById(R.id.vpn_switch);
        Button logout = findViewById(R.id.btn_logout);

        String name = sm.getName();
        String email = sm.getEmail();
        String code = sm.getCode();
        title.setText((name != null ? name : "") + " (" + (code != null ? code : "") + ")");
        sub.setText(email != null ? email : "");

        boolean connected = getSharedPreferences("boreas_prefs", MODE_PRIVATE)
                .getBoolean("vpn_connected", false);
        vpnSwitch.setChecked(connected);

        vpnSwitch.setOnCheckedChangeListener((buttonView, isChecked) -> {
            if (isChecked) {
                Intent intent = VpnService.prepare(this);
                if (intent != null) {
                    startActivityForResult(intent, 0);
                } else {
                    onActivityResult(0, RESULT_OK, null);
                }
            } else {
                stopService(new Intent(this, SSLVPNService.class));
            }
        });

        logout.setOnClickListener(v -> {
            String token = sm.getAccessToken();
            sm.clear();

            exec.execute(() -> {
                try {
                    if (token != null) new SupabaseAuthApi().signOut(token);
                } catch (Exception ignored) {}
            });

            stopService(new Intent(this, SSLVPNService.class));
            startActivity(new Intent(this, LoginActivity.class));
            finishAffinity();
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode == RESULT_OK) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(new Intent(this, SSLVPNService.class));
            } else {
                startService(new Intent(this, SSLVPNService.class));
            }
        } else {
            vpnSwitch.setChecked(false);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        exec.shutdownNow();
    }
}
