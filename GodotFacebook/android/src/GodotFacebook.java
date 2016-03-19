package org.godotengine.godot;

import com.facebook.FacebookSdk;
import com.facebook.share.widget.AppInviteDialog;
import com.facebook.share.model.AppInviteContent;
import com.facebook.FacebookSdkNotInitializedException;
import android.app.Activity;
import android.util.Log;

public class GodotFacebook extends Godot.SingletonBase {

    private Activity activity = null;

    static public Godot.SingletonBase initialize(Activity p_activity) 
    { 
        return new GodotFacebook(p_activity); 
    } 

    public GodotFacebook(Activity p_activity) 
    {
        registerClass("GodotFacebook", new String[]{"init", "appInvite"});
        activity = p_activity;
    }

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

    public void appInvite(final String appLinkUrl, final String previewImageUrl)
    {
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

}
