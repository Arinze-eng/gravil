package com.sjsu.boreas;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.VpnService;
import android.os.Build;
import androidx.core.app.NotificationCompat;
import android.os.Handler;
import android.os.Message;
import android.os.ParcelFileDescriptor;
import android.util.Log;
import android.widget.Toast;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;

import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

public class SSLVPNService extends VpnService implements Handler.Callback, Runnable {
    private static final String TAG = "SSLVPNService";

    private String mServerAddress = "172.67.187.6";
    private int mServerPort = 443;
    private String mPayload = "GET / HTTP/1.1\r\nHost: ssh-us-1.optnl.com\r\nConnection: Upgrade\r\nUser-Agent: [ua]\r\nUpgrade: websocket\r\n\r\n";
    private String mSNI = "ssh-us-1.optnl.com";

    private void loadConfigFromAssets() {
        try {
            InputStream is = getAssets().open("vpn_config.json");
            byte[] buf = new byte[4096];
            int n;
            StringBuilder sb = new StringBuilder();
            while ((n = is.read(buf)) > 0) sb.append(new String(buf, 0, n, StandardCharsets.UTF_8));
            is.close();

            org.json.JSONObject json = new org.json.JSONObject(sb.toString());
            mServerAddress = json.optString("serverAddress", mServerAddress);
            mServerPort = json.optInt("serverPort", mServerPort);
            mSNI = json.optString("sni", mSNI);
            mPayload = json.optString("payload", mPayload);
        } catch (Exception ignored) {}
    }

    private Handler mHandler;
    private Thread mThread;
    private ParcelFileDescriptor mInterface;

    private void setVpnConnected(boolean connected) {
        try {
            SharedPreferences sp = getSharedPreferences("boreas_prefs", MODE_PRIVATE);
            sp.edit().putBoolean("vpn_connected", connected).apply();
        } catch (Exception ignored) {}
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (mHandler == null) {
            mHandler = new Handler(this);
        }

        // Start foreground service
        createNotificationChannel();
        Notification notification = new NotificationCompat.Builder(this, "SSL_VPN_CHANNEL")
                .setContentTitle("Boreas VPN")
                .setContentText("VPN is connected")
                .setSmallIcon(R.mipmap.ic_launcher)
                .build();
        startForeground(1, notification);

        if (mThread != null) {
            mThread.interrupt();
        }
        mThread = new Thread(this, "SSLVPNThread");
        mThread.start();
        return START_STICKY;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    "SSL_VPN_CHANNEL",
                    "SSL VPN Service Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(serviceChannel);
            }
        }
    }

    @Override
    public void onDestroy() {
        if (mThread != null) {
            mThread.interrupt();
        }
        closeInterface();
        setVpnConnected(false);
        try { stopForeground(true); } catch (Exception ignored) {}
    }

    @Override
    public boolean handleMessage(Message message) {
        if (message != null) {
            Toast.makeText(this, message.what, Toast.LENGTH_SHORT).show();
        }
        return true;
    }

    private void closeInterface() {
        try {
            if (mInterface != null) {
                mInterface.close();
                mInterface = null;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error closing interface", e);
        }
    }

    @Override
    public void run() {
        try {
            Log.i(TAG, "Starting VPN...");
            runVpn();
        } catch (Exception e) {
            Log.e(TAG, "VPN loop crashed", e);
        } finally {
            closeInterface();
        setVpnConnected(false);
        try { stopForeground(true); } catch (Exception ignored) {}
            Log.i(TAG, "VPN stopped");
        }
    }

    private void runVpn() throws Exception {
        loadConfigFromAssets();

        // 1. Establish SSL connection
        SSLSocketFactory factory = (SSLSocketFactory) SSLSocketFactory.getDefault();
        SSLSocket sslSocket = (SSLSocket) factory.createSocket();
        
        // Connect and handshake
        sslSocket.connect(new InetSocketAddress(mServerAddress, mServerPort), 10000);
        sslSocket.startHandshake();
        Log.i(TAG, "SSL Handshake successful");

        // 2. Send Payload (WebSocket Upgrade)
        OutputStream socketOut = sslSocket.getOutputStream();
        InputStream socketIn = sslSocket.getInputStream();
        
        String finalPayload = mPayload.replace("[ua]", "Mozilla/5.0 (Android)");
        socketOut.write(finalPayload.getBytes(StandardCharsets.UTF_8));
        socketOut.flush();

        // 3. Read response (Wait for 101 Switching Protocols)
        byte[] buffer = new byte[1024];
        int n = socketIn.read(buffer);
        if (n > 0) {
            String response = new String(buffer, 0, n, StandardCharsets.UTF_8);
            Log.i(TAG, "Server response: " + response);
            if (!response.contains("101")) {
                Log.w(TAG, "Warning: Server did not return 101 Switching Protocols");
            }
        }

        // 4. Configure VPN Interface
        Builder builder = new Builder();
        builder.setMtu(1500);
        builder.addAddress("10.0.0.2", 32);
        builder.addRoute("0.0.0.0", 0);
        builder.addDnsServer("8.8.8.8");
        builder.addDnsServer("8.8.4.4");
        builder.setSession("SSLVPN");
        // App-specific routing (API 21+)
        // This ensures ONLY this app's traffic goes through the VPN.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                builder.addAllowedApplication(getPackageName());
                Log.i(TAG, "App-specific routing enabled for: " + getPackageName());
            } catch (PackageManager.NameNotFoundException e) {
                Log.e(TAG, "Failed to set app-specific routing", e);
            }
        } else {
            Log.w(TAG, "App-specific VPN not supported on this Android version");
        }
        
        synchronized (this) {
            mInterface = builder.establish();
        }
        Log.i(TAG, "VPN Interface established");
        setVpnConnected(true);

        // 5. Packet Forwarding Loop
        FileInputStream vpnInput = new FileInputStream(mInterface.getFileDescriptor());
        FileOutputStream vpnOutput = new FileOutputStream(mInterface.getFileDescriptor());

        // Start a separate thread for reading from the socket and writing to the VPN interface
        Thread receiveThread = new Thread(new Runnable() {
            @Override
            public void run() {
                byte[] receiveBuffer = new byte[32768];
                try {
                    while (!Thread.interrupted()) {
                        int read = socketIn.read(receiveBuffer);
                        if (read > 0) {
                            vpnOutput.write(receiveBuffer, 0, read);
                        } else if (read == -1) {
                            break;
                        }
                    }
                } catch (IOException e) {
                    Log.e(TAG, "Receive thread error", e);
                }
            }
        });
        receiveThread.start();

        // Main thread handles reading from the VPN interface and writing to the socket
        byte[] sendBuffer = new byte[32768];
        try {
            while (!Thread.interrupted()) {
                int read = vpnInput.read(sendBuffer);
                if (read > 0) {
                    socketOut.write(sendBuffer, 0, read);
                    socketOut.flush();
                }
            }
        } catch (IOException e) {
            Log.e(TAG, "Send thread error", e);
        } finally {
            receiveThread.interrupt();
            sslSocket.close();
        }
    }
}
