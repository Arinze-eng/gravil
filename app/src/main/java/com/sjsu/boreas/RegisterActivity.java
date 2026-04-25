package com.sjsu.boreas;

import androidx.appcompat.app.AppCompatActivity;

import android.graphics.Point;
import android.graphics.Typeface;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.text.method.PasswordTransformationMethod;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.PopupWindow;
import android.widget.TextView;
import android.widget.Toast;

import com.sjsu.boreas.Database.LocalDatabaseReference;
import com.sjsu.boreas.Database.LoggedInUser.LoggedInUser;
import com.sjsu.boreas.OnlineConnectionHandlers.FirebaseController;
import com.sjsu.boreas.Security.EncryptionController;
import com.sjsu.boreas.Security.PasswordManager;

import org.json.JSONObject;

import java.util.Random;

public class RegisterActivity extends AppCompatActivity {

    private static final String TAG = "Boreas";
    private static final String SUB_TAG = "---RegisterActivity ";

    private EditText fullNameEditor;
    private EditText password;
    private EditText confirmPassword;
    private Button signUp;
    private TextView logIn;
    private LinearLayout registerLayout;

    public PopupWindow mPopupWindow;

    public LocalDatabaseReference localDatabaseReference = LocalDatabaseReference.get();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.e(TAG, SUB_TAG + "On Create");
        super.onCreate(savedInstanceState);

        this.requestWindowFeature(Window.FEATURE_NO_TITLE);
        this.getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        setContentView(R.layout.activity_register);

        DisplayMetrics displayMetrics = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int width = displayMetrics.widthPixels;
        int margin = (width / 6);
        registerLayout = findViewById(R.id.signup_layout);
        ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) registerLayout.getLayoutParams();
        params.setMargins(margin, 0, 0, 0);

        fullNameEditor = findViewById(R.id.register_username);
        password = findViewById(R.id.register_password);
        confirmPassword = findViewById(R.id.register_confirm_password);
        signUp = findViewById(R.id.signup);
        logIn = findViewById(R.id.login_register_act);

        password.setTypeface(Typeface.DEFAULT);
        password.setTransformationMethod(new PasswordTransformationMethod());
        confirmPassword.setTypeface(Typeface.DEFAULT);
        confirmPassword.setTransformationMethod(new PasswordTransformationMethod());

        logIn.setOnClickListener(v -> MainActivity.context.onActivityResult(0, MainActivity.LOGIN_ACTIVITY_REQUEST_CODE, null));

        signUp.setOnClickListener(v -> {
            Log.e(TAG, SUB_TAG + "Sign up clicked");
            showLoading();
            completeRegistration();
        });

        // Update helper text
        TextView helper = findViewById(R.id.permission_text);
        if (helper != null) helper.setText("*A unique 4-digit code will be generated for you after signup.");
    }

    private void showLoading() {
        if (mPopupWindow != null) return;
        LayoutInflater inflater = (LayoutInflater) getSystemService(LAYOUT_INFLATER_SERVICE);
        final View popupView = inflater.inflate(R.layout.popup_loading, null);

        Point size = new Point();
        getWindowManager().getDefaultDisplay().getSize(size);
        int width = size.x - 60;
        int height = LinearLayout.LayoutParams.WRAP_CONTENT;
        mPopupWindow = new PopupWindow(popupView, width, height, false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            mPopupWindow.setElevation(12);
        }
        findViewById(R.id.register_main).post(() -> mPopupWindow.showAtLocation(findViewById(R.id.register_main), Gravity.CENTER, 0, 0));
    }

    private String generate4DigitCode() {
        int n = 1000 + new Random().nextInt(9000);
        return String.valueOf(n);
    }

    public void completeRegistration() {
        String passwordStr = password.getText().toString();
        String confirmPasswordStr = confirmPassword.getText().toString();

        if (fullNameEditor.getText().toString().trim().equals("") || passwordStr.equals("") || confirmPasswordStr.equals("")) {
            Toast.makeText(this, R.string.reg_error_unfilled, Toast.LENGTH_LONG).show();
            if (mPopupWindow != null) mPopupWindow.dismiss();
            mPopupWindow = null;
            return;
        }

        if (!passwordStr.equals(confirmPasswordStr)) {
            Toast.makeText(this, R.string.reg_error_passwords_dont_match, Toast.LENGTH_LONG).show();
            if (mPopupWindow != null) mPopupWindow.dismiss();
            mPopupWindow = null;
            return;
        }

        final String name = fullNameEditor.getText().toString().trim();
        final String hashedPassword = PasswordManager.hashThePassword(passwordStr);

        if (hashedPassword == null) {
            Toast.makeText(this, "Password error", Toast.LENGTH_LONG).show();
            if (mPopupWindow != null) mPopupWindow.dismiss();
            mPopupWindow = null;
            return;
        }

        final String[] keys = EncryptionController.getInstance().generateKeys("RSA", 514);
        final String publicKey = keys[1];
        final String privateKey = keys[0];

        // No location required
        final double lat = 0.0;
        final double lon = 0.0;

        AsyncTask.execute(() -> {
            try {
                boolean registered = false;
                LoggedInUser myUser = null;

                // retry to avoid collision
                for (int i = 0; i < 30 && !registered; i++) {
                    String uid = generate4DigitCode();
                    LoggedInUser candidate = new LoggedInUser(uid, name, lat, lon, hashedPassword, publicKey, privateKey);

                    int status = FirebaseController.registerUserSync(candidate, RegisterActivity.this);
                    if (status == 201 || status == 200) {
                        registered = true;
                        myUser = candidate;
                    } else if (status == 409) {
                        // collision, retry
                    } else {
                        final int s = status;
                        runOnUiThread(() -> Toast.makeText(RegisterActivity.this, "Signup failed (" + s + ")", Toast.LENGTH_LONG).show());
                        break;
                    }
                }

                if (!registered || myUser == null) {
                    runOnUiThread(() -> {
                        if (mPopupWindow != null) mPopupWindow.dismiss();
                        mPopupWindow = null;
                    });
                    return;
                }

                localDatabaseReference.registerUser(myUser);
                MainActivity.currentUser = myUser;
                MainActivity.newAcct = true;

                runOnUiThread(() -> {
                    if (mPopupWindow != null) mPopupWindow.dismiss();
                    mPopupWindow = null;
                    MainActivity.context.onActivityResult(0, MainActivity.REGISTER_ACTIVITY_DONE_CODE, null);
                });

            } catch (Exception e) {
                Log.e(TAG, SUB_TAG + "Registration error", e);
                runOnUiThread(() -> {
                    if (mPopupWindow != null) mPopupWindow.dismiss();
                    mPopupWindow = null;
                    Toast.makeText(RegisterActivity.this, "Signup error", Toast.LENGTH_LONG).show();
                });
            }
        });
    }
}
