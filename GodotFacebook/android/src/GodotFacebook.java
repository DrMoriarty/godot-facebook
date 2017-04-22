package org.godotengine.godot;

import com.facebook.FacebookSdk;
import com.facebook.CallbackManager;
import com.facebook.AccessToken;
import com.facebook.FacebookCallback;
import com.facebook.LoginStatusCallback;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.facebook.share.widget.AppInviteDialog;
import com.facebook.share.model.AppInviteContent;
import com.facebook.FacebookException;
import com.facebook.FacebookSdkNotInitializedException;
import android.app.Activity;
import android.content.Intent;
import android.util.Log;

public class GodotFacebook extends Godot.SingletonBase {

    private Godot activity = null;
    private Integer facebookCallbackId = 0;
    private CallbackManager callbackManager;

    static public Godot.SingletonBase initialize(Activity p_activity) 
    { 
        return new GodotFacebook(p_activity); 
    } 

    public GodotFacebook(Activity p_activity) 
    {
        registerClass("GodotFacebook", new String[]{"init", "setFacebookCallbackId", "getFacebookCallbackId", "appInvite", "login", "logout", "isLoggedIn"});
        activity = (Godot)p_activity;
        callbackManager = CallbackManager.Factory.create();

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

    public void appInvite(final String appLinkUrl, final String previewImageUrl)
    {
        Log.i("godot", "Facebook appInvite");
        activity.runOnUiThread(new Runnable()
        {
            @Override public void run()
            {
                if (FacebookSdk.isInitialized()) {
                    if (AppInviteDialog.canShow()) {
                        AppInviteContent content = new AppInviteContent.Builder()
                                    .setApplinkUrl(appLinkUrl)
                                    .setPreviewImageUrl(previewImageUrl)
                                    .build();
                        AppInviteDialog.show(activity, content);
                    }
                } else {
                    Log.d("godot", "Facebook sdk not initialized");   
                }
            }
        });
    }

    public void login()
    {
        Log.i("godot", "Facebook login");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken != null && !accessToken.isExpired()) {
            GodotLib.calldeferred(facebookCallbackId, "login_success", new Object[]{accessToken.getToken()});
        } else {
            LoginManager.getInstance().logInWithPublishPermissions(activity, null);
        }
    }

    public void logout()
    {
        Log.i("godot", "Facebook logout");
        LoginManager.getInstance().logOut();
    }

    public void isLoggedIn()
    {
        Log.i("godot", "Facebook isLoggedIn");
        AccessToken accessToken = AccessToken.getCurrentAccessToken();
        if(accessToken == null) {
            GodotLib.calldeferred(facebookCallbackId, "login_failed", new Object[]{"No token"});
        } else if(accessToken.isExpired()) {
            GodotLib.calldeferred(facebookCallbackId, "login_failed", new Object[]{"No expired"});
        } else {
            GodotLib.calldeferred(facebookCallbackId, "login_success", new Object[]{accessToken.getToken()});
        }
    }

    // Internal methods

    public void callbackSuccess(String ticket, String signature, String sku) {
		//GodotLib.callobject(facebookCallbackId, "purchase_success", new Object[]{ticket, signature, sku});
        //GodotLib.calldeferred(purchaseCallbackId, "consume_fail", new Object[]{});
	}

    @Override protected void onMainActivityResult (int requestCode, int resultCode, Intent data)
    {
        callbackManager.onActivityResult(requestCode, resultCode, data);
    }

}
