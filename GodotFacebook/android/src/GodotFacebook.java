package org.godotengine.godot;

import com.facebook.FacebookSdk;
import com.facebook.CallbackManager;
import com.facebook.AccessToken;
import com.facebook.FacebookCallback;
import com.facebook.LoginStatusCallback;
import com.facebook.GraphRequest;
import com.facebook.GraphRequest.GraphJSONObjectCallback;
import com.facebook.GraphResponse;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.facebook.share.model.AppInviteContent;
import com.facebook.share.model.GameRequestContent;
import com.facebook.share.widget.AppInviteDialog;
import com.facebook.share.widget.GameRequestDialog;
import com.facebook.FacebookException;
import com.facebook.FacebookSdkNotInitializedException;
import android.app.Activity;
import android.content.Intent;
import android.util.Log;
import android.os.Bundle;
import java.util.Map;
import java.util.List;
import java.util.Arrays;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

public class GodotFacebook extends Godot.SingletonBase {

    private Godot activity = null;
    private Integer facebookCallbackId = 0;
    private GameRequestDialog requestDialog;
    private CallbackManager callbackManager;

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
                "callApi"});
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
