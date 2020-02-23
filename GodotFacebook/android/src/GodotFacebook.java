package org.godotengine.godot;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.Context;
import android.os.Bundle;
import android.os.Build;
import android.os.Environment;
import android.os.StatFs;
import android.util.Log;
import android.util.DisplayMetrics;
import android.telephony.TelephonyManager;
import android.view.WindowManager;
import android.view.Display;
import com.facebook.AccessToken;
import com.facebook.CallbackManager;
import com.facebook.FacebookCallback;
import com.facebook.FacebookException;
import com.facebook.FacebookSdk;
import com.facebook.FacebookSdkNotInitializedException;
import com.facebook.GraphRequest.GraphJSONObjectCallback;
import com.facebook.GraphRequest;
import com.facebook.GraphResponse;
import com.facebook.LoginStatusCallback;
import com.facebook.appevents.AppEventsLogger;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.facebook.share.model.AppInviteContent;
import com.facebook.share.model.GameRequestContent;
import com.facebook.share.widget.AppInviteDialog;
import com.facebook.share.widget.GameRequestDialog;
import com.google.android.gms.ads.identifier.AdvertisingIdClient.Info;
import com.google.android.gms.ads.identifier.AdvertisingIdClient;
//import com.google.android.gms.auth.GooglePlayServicesAvailabilityException;
import com.google.android.gms.common.GooglePlayServicesNotAvailableException;
import java.io.IOException;
import java.io.File;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.TimeZone;
import java.util.Locale;
import java.util.Date;
import java.lang.Exception;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class GodotFacebook extends Godot.SingletonBase {

    private Godot activity = null;
    private Integer facebookCallbackId = 0;
    private GameRequestDialog requestDialog;
    private CallbackManager callbackManager;
    private AppEventsLogger fbLogger;
    private static long totalExternalStorageGB;
    private static long availableExternalStorageGB;

    static public Godot.SingletonBase initialize(Activity p_activity) 
    { 
        return new GodotFacebook(p_activity); 
    } 

    public GodotFacebook(Activity p_activity) 
    {
        registerClass("GodotFacebook", new String[]{
                "init",
                "setFacebookCallbackId",
                "getFacebookCallbackId",
                "gameRequest",
                "login",
                "logout",
                "isLoggedIn",
                "userProfile",
                "callApi",
                "set_push_token",
                "log_event",
                "log_event_value",
                "log_event_params",
                "log_event_value_params",
                "advertising_id",
                "extinfo"
            });
        activity = (Godot)p_activity;
    }

    // Public methods

    public void init(final String key)
    {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    FacebookSdk.setApplicationId(key);
                    FacebookSdk.sdkInitialize(activity.getApplicationContext());

                    callbackManager = CallbackManager.Factory.create();
                    fbLogger = AppEventsLogger.newLogger(activity.getApplicationContext(), key);
                    requestDialog = new GameRequestDialog(activity);
                    requestDialog.registerCallback(callbackManager, new FacebookCallback<GameRequestDialog.Result>() {
                            public void onSuccess(GameRequestDialog.Result result) {
                                String id = result.getRequestId();
                                //result.getRequestRecipients()
                                Log.i("godot", "Facebook game request finished: " + id);
                                Dictionary map;
                                try {
                                    JSONObject object = new JSONObject();
                                    object.put("requestId", result.getRequestId());
                                    object.put("recipientsIds", new JSONArray(result.getRequestRecipients()));
                                    map = JsonHelper.toMap(object);
                                } catch (JSONException e) {
                                    map = new Dictionary();
                                }
                                GodotLib.calldeferred(facebookCallbackId, "request_success", new Object[]{map});
                            }
                            public void onCancel() {
                                Log.w("godot", "Facebook game request cancelled");
                                GodotLib.calldeferred(facebookCallbackId, "request_cancelled", new Object[]{});
                            }
                            public void onError(FacebookException error) {
                                Log.e("godot", "Failed to send facebook game request: " + error.getMessage()); 
                                GodotLib.calldeferred(facebookCallbackId, "request_failed", new Object[]{error.toString()});
                            }
                        });

                    LoginManager.getInstance().registerCallback(callbackManager, new FacebookCallback<LoginResult>() {
                            @Override
                            public void onSuccess(LoginResult loginResult) {
                                AccessToken at = loginResult.getAccessToken();
                                GodotLib.calldeferred(facebookCallbackId, "login_success", new Object[]{at.getToken()});
                            }

                            @Override
                            public void onCancel() {
                                GodotLib.calldeferred(facebookCallbackId, "login_cancelled", new Object[]{});
                            }

                            @Override
                            public void onError(FacebookException exception) {
                                GodotLib.calldeferred(facebookCallbackId, "login_failed", new Object[]{exception.toString()});
                            }
                        });

                } catch (FacebookSdkNotInitializedException e) {
                    Log.e("godot", "Failed to initialize FacebookSdk: " + e.getMessage()); 
                } catch (Exception e) {
                    Log.e("godot", "Exception: " + e.getMessage());  
                }
            }
        });
    }

    public void setFacebookCallbackId(int facebookCallbackId) {
		this.facebookCallbackId = facebookCallbackId;
	}

    public int getFacebookCallbackId() {
		return facebookCallbackId;
	}

    public void gameRequest(final String message, final String recipient, final String objectId)
    {
        Log.i("godot", "Facebook gameRequest");
        activity.runOnUiThread(new Runnable()
        {
            @Override public void run()
            {
                if (FacebookSdk.isInitialized()) {
                    GameRequestContent.Builder builder = new GameRequestContent.Builder();
                    builder.setMessage(message);
                    if(recipient != null && recipient.length() > 0)
                        builder.setTo(recipient);
                    if(objectId != null && objectId.length() > 0) {
                        builder.setActionType(GameRequestContent.ActionType.SEND);
                        builder.setObjectId(objectId);
                    }
                    GameRequestContent content = builder.build();
                    requestDialog.show(content);
                } else {
                    Log.d("godot", "Facebook sdk not initialized");   
                }
            }
        });
    }

    public void login(String[] permissions)
    {
        Log.i("godot", "Facebook login");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken != null && !accessToken.isExpired()) {
            GodotLib.calldeferred(facebookCallbackId, "login_success", new Object[]{accessToken.getToken()});
        } else {
            List<String> perm = Arrays.asList(permissions);
            LoginManager.getInstance().logInWithReadPermissions(activity, perm);
        }
    }

    public void logout()
    {
        Log.i("godot", "Facebook logout");
        LoginManager.getInstance().logOut();
    }

    public boolean isLoggedIn()
    {
        Log.i("godot", "Facebook isLoggedIn");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken == null || accessToken.isExpired()) {
            //GodotLib.calldeferred(facebookCallbackId, "login_failed", new Object[]{"No token"});
            return false;
        } else {
            //GodotLib.calldeferred(facebookCallbackId, "login_success", new Object[]{accessToken.getToken()});
            return true;
        }
    }

    public void userProfile(final int callbackObject, final String callbackMethod)
    {
        Log.i("godot", "Facebook userProfile");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken != null && !accessToken.isExpired()) {
            GraphRequest gr = GraphRequest.newMeRequest(accessToken, new GraphJSONObjectCallback() {
                    @Override
                    public void onCompleted(JSONObject object, GraphResponse response) {
                        if(object == null) {
                            Log.e("godot", "Facebook graph request error: "+response.toString());
                            GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{"Error"});
                        } else {
                            Log.i("godot", "Facebook graph response: "+object.toString());
                            try {
                                Dictionary map = JsonHelper.toMap(object);
                                //String res = object.toString();
                                GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{map});
                            } catch (JSONException e) {
                                e.printStackTrace();
                                GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{"JSON Error"});
                            }
                        }
                    }
                });
            gr.executeAsync();
        } else {
            GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{"No token"});
        }
    }

    public void callApi(final String path, final Dictionary properties, final int callbackObject, final String callbackMethod)
    {
        Log.i("godot", "Facebook callApi");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken != null && !accessToken.isExpired()) {
            GraphRequest gr = GraphRequest.newGraphPathRequest(accessToken, path, new GraphRequest.Callback() {
                    @Override
                    public void onCompleted(GraphResponse response) {
                        JSONObject object = response.getJSONObject();
                        if(object == null || response.getError() != null) {
                            String err = response.getError().toString();
                            Log.e("godot", "Facebook graph request error: "+response.toString());
                            GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{err});
                        } else {
                            Log.i("godot", "Facebook graph response: "+object.toString());
                            try {
                                Dictionary map = JsonHelper.toMap(object);
                                Log.i("godot", "Api result: "+map.toString());
                                //String res = object.toString();
                                GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{map});
                            } catch (JSONException e) {
                                e.printStackTrace();
                                GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{e.toString()});
                            }
                        }
                    }
                });
            Bundle params = gr.getParameters();
            for(String key: properties.get_keys()) {
                params.putString(key, properties.get(key).toString());
            }
            gr.setParameters(params);
            gr.executeAsync();
        } else {
            GodotLib.calldeferred(callbackObject, callbackMethod, new Object[]{"No token"});
        }
        
    }

    public void set_push_token(final String token)
    {
        Log.i("godot", "Facebook set_push_token");
        if(fbLogger == null) {
            Log.w("godot", "Facebook logger doesn't inited yet!");
            return;
        }
        fbLogger.setPushNotificationsRegistrationId(token);
    }

    public void log_event(final String event)
    {
        Log.i("godot", "Facebook log_event");
        if(fbLogger == null) {
            Log.w("godot", "Facebook logger doesn't inited yet!");
            return;
        }
        fbLogger.logEvent(event);
    }

    public void log_event_value(final String event, float value)
    {
        Log.i("godot", "Facebook log_event_value");
        if(fbLogger == null) {
            Log.w("godot", "Facebook logger doesn't inited yet!");
            return;
        }
        fbLogger.logEvent(event, value);
    }

    public void log_event_params(final String event, final Dictionary params)
    {
        Log.i("godot", "Facebook log_event_params");
        if(fbLogger == null) {
            Log.w("godot", "Facebook logger doesn't inited yet!");
            return;
        }
        Bundle parameters = new Bundle();
        for(String key: params.get_keys()) {
            parameters.putString(key, params.get(key).toString());
        }
        fbLogger.logEvent(event, parameters);
    }

    public void log_event_value_params(final String event, float value, final Dictionary params)
    {
        Log.i("godot", "Facebook log_event_value_params");
        if(fbLogger == null) {
            Log.w("godot", "Facebook logger doesn't inited yet!");
            return;
        }
        Bundle parameters = new Bundle();
        for(String key: params.get_keys()) {
            if(params.get(key) != null) 
                parameters.putString(key, params.get(key).toString());
        }
        fbLogger.logEvent(event, value, parameters);
    }

    public String advertising_id()
    {
        Info adInfo = null;
        try {
            adInfo = AdvertisingIdClient.getAdvertisingIdInfo(activity);
            String userId = adInfo.getId();
            return userId;
        } catch (IOException e) {
            Log.e("godot", e.toString());
        //} catch (GooglePlayServicesAvailabilityException e) {
            //Log.e("godot", e.toString());
        } catch (GooglePlayServicesNotAvailableException e) {
            Log.e("godot", e.toString());
        } catch (Exception e) {
            Log.e("godot", e.toString());
        }
        return "";
    }

    public String[] extinfo()
    {
        String[] res = new String[16];
        res[0] = "a2";

        String pkgName = activity.getApplicationContext().getPackageName();
        res[1] = pkgName;

        try {
            PackageInfo pi = activity.getApplicationContext().getPackageManager().getPackageInfo(pkgName, 0);
            res[2] = ""+pi.versionCode;
            res[3] = ""+pi.versionName;
        } catch (NameNotFoundException e) {
        }

        res[4] = Build.VERSION.RELEASE;
        res[5] = Build.MODEL;

        Locale locale;
        try {
            locale = activity.getApplicationContext().getResources().getConfiguration().locale;
        } catch (Exception e) {
            locale = Locale.getDefault();
        }
        res[6] = locale.getLanguage() + "_" + locale.getCountry();
        
        TimeZone tz = TimeZone.getDefault();
        String deviceTimezoneAbbreviation = tz.getDisplayName(tz.inDaylightTime(new Date()), TimeZone.SHORT);
        String deviceTimeZoneName = tz.getID();
        res[7] = deviceTimezoneAbbreviation;

        TelephonyManager telephonyManager = ((TelephonyManager) activity.getApplicationContext().getSystemService(Context.TELEPHONY_SERVICE));
        String carrierName = telephonyManager.getNetworkOperatorName();
        res[8] = carrierName;

        int width = 0;
        int height = 0;
        double density = 0;
        try {
            WindowManager wm = (WindowManager) activity.getApplicationContext().getSystemService(Context.WINDOW_SERVICE);
            if (wm != null) {
                Display display = wm.getDefaultDisplay();
                DisplayMetrics displayMetrics = new DisplayMetrics();
                display.getMetrics(displayMetrics);
                width = displayMetrics.widthPixels;
                height = displayMetrics.heightPixels;
                density = displayMetrics.density;
            }
        } catch (Exception e) {
            // Swallow
        }
        String densityStr = String.format("%.2f", density);
        res[9] = "" + width;
        res[10] = "" + height;
        res[11] = densityStr;

        int numCPUCores = Math.max(Runtime.getRuntime().availableProcessors(), 1);
        res[12] = "" + numCPUCores;

        refreshTotalExternalStorage();
        refreshAvailableExternalStorage();
        res[13] = "" + totalExternalStorageGB;
        res[14] = "" + availableExternalStorageGB;

        res[15] = deviceTimeZoneName;

        return res;
    }

    // Internal methods

    public void callbackSuccess(String ticket, String signature, String sku) {
		//GodotLib.callobject(facebookCallbackId, "purchase_success", new Object[]{ticket, signature, sku});
        //GodotLib.calldeferred(purchaseCallbackId, "consume_fail", new Object[]{});
	}

    /**
     * @return whether there is external storage:
     */
    private static boolean externalStorageExists() {
        return Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState());
    }

    // getAvailableBlocks/getBlockSize deprecated but required pre-API v18
    @SuppressWarnings("deprecation")
    private static void refreshAvailableExternalStorage() {
        try {
            if (externalStorageExists()) {
                File path = Environment.getExternalStorageDirectory();
                StatFs stat = new StatFs(path.getPath());
                availableExternalStorageGB = (long)stat.getAvailableBlocks() * (long)stat.getBlockSize();
            }
            availableExternalStorageGB = convertBytesToGB(availableExternalStorageGB);
        } catch (Exception e) {
            // Swallow
        }
    }

    // getAvailableBlocks/getBlockSize deprecated but required pre-API v18
    @SuppressWarnings("deprecation")
    private static void refreshTotalExternalStorage() {
        try {
            if (externalStorageExists()) {
                File path = Environment.getExternalStorageDirectory();
                StatFs stat = new StatFs(path.getPath());
                totalExternalStorageGB = (long)stat.getBlockCount() * (long)stat.getBlockSize();
            }
            totalExternalStorageGB = convertBytesToGB(totalExternalStorageGB);
        } catch (Exception e) {
            // Swallow
        }
    }

    private static long convertBytesToGB(double bytes) {
        return Math.round(bytes / (1024.0 * 1024.0 * 1024.0));
    }

    @Override protected void onMainActivityResult (int requestCode, int resultCode, Intent data)
    {
        if(callbackManager != null) {
            callbackManager.onActivityResult(requestCode, resultCode, data);
        }
    }
}
