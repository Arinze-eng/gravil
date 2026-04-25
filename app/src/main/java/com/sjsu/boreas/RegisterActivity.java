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

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        setContentView(R.layout.activity_register);

        DisplayMetrics displayMetrics = new DisplayMetrics();
        getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int width = displayMetrics.widthPixels;
        int margin = (width / 6);
        registerLayout = (LinearLayout) findViewById(R.id.signup_layout);
        ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) registerLayout.getLayoutParams();
        params.setMargins(margin, 0, 0, 0);

        fullNameEditor = (EditText) findViewById(R.id.register_username);
        password = (EditText) findViewById(R.id.register_password);
        confirmPassword = (EditText) findViewById(R.id.register_confirm_password);
        signUp = (Button) findViewById(R.id.signup);
        logIn = (TextView) findViewById(R.id.login_register_act);

        password.setTypeface(Typeface.DEFAULT);
        password.setTransformationMethod(new PasswordTransformationMethod());
        confirmPassword.setTypeface(Typeface.DEFAULT);
        confirmPassword.setTransformationMethod(new PasswordTransformationMethod());

        logIn.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                MainActivity.context.onActivityResult(0, MainActivity.LOGIN_ACTIVITY_REQUEST_CODE, null);
            }
        });

        signUp.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Log.e(TAG, SUB_TAG + "Sign up clicked");
                showLoading();
                completeRegistration();
            }
        });

        TextView helper = (TextView) findViewById(R.id.permission_text);
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

        findViewById(R.id.register_main).post(new Runnable() {
            @Override
            public void run() {
                mPopupWindow.showAtLocation(findViewById(R.id.register_main), Gravity.CENTER, 0, 0);
            }
        });
    }

    private String generate4DigitCode() {
        int n = 1000 + new Random().nextInt(9000);
        return String.valueOf(n);
    }

    public void completeRegistration() {
        final String passwordStr = password.getText().toString();
        final String confirmPasswordStr = confirmPassword.getText().toString();

        if (fullNameEditor.getText().toString().trim().equals("") || passwordStr.equals("") || confirmPasswordStr.equals("")) {
            Toast.makeText(this, R.string.reg_error_unfilled, Toast.LENGTH_LONG).show();
            dismissLoading();
            return;
        }

        if (!passwordStr.equals(confirmPasswordStr)) {
            Toast.makeText(this, R.string.reg_error_passwords_dont_match, Toast.LENGTH_LONG).show();
            dismissLoading();
            return;
        }

        final String name = fullNameEditor.getText().toString().trim();
        final String hashedPassword = PasswordManager.hashThePassword(passwordStr);

        if (hashedPassword == null) {
            Toast.makeText(this, "Password error", Toast.LENGTH_LONG).show();
            dismissLoading();
            return;
        }

        final String[] keys = EncryptionController.getInstance().generateKeys("RSA", 514);
        final String publicKey = keys[1];
        final String privateKey = keys[0];

        final double lat = 0.0;
        final double lon = 0.0;

        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    boolean registered = false;
                    LoggedInUser myUser = null;

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
                            runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    Toast.makeText(RegisterActivity.this, "Signup failed (" + s + ")", Toast.LENGTH_LONG).show();
                                }
                            });
                            break;
                        }
                    }

                    if (!registered || myUser == null) {
                        runOnUiThread(new Runnable() {
                            @Override
                            public void run() {
                                dismissLoading();
                            }
                        });
                        return;
                    }

                    localDatabaseReference.registerUser(myUser);
                    MainActivity.currentUser = myUser;
                    MainActivity.newAcct = true;

                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            dismissLoading();
                            MainActivity.context.onActivityResult(0, MainActivity.REGISTER_ACTIVITY_DONE_CODE, null);
                        }
                    });

                } catch (Exception e) {
                    Log.e(TAG, SUB_TAG + "Registration error", e);
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            dismissLoading();
                            Toast.makeText(RegisterActivity.this, "Signup error", Toast.LENGTH_LONG).show();
                        }
                    });
                }
            }
        });
    }

    private void dismissLoading() {
        try {
            if (mPopupWindow != null) mPopupWindow.dismiss();
        } catch (Exception ignored) {}
        mPopupWindow = null;
    }
}
