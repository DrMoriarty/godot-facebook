//
//  Facebook.h
//
//  Created by DrMoriarty on 11.02.19.
//
//

#pragma once

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

class FacebookPlugin : public Object {
    GDCLASS(FacebookPlugin, Object);

    static Object * fbCallbackObj;
    static void _bind_methods();

public:
    FacebookPlugin();
    ~FacebookPlugin();

    void _init();
    
    void init(const String& key);
    void setFacebookCallbackId(Object* facebookcallback);
    void gameRequest(const String message, const String recipient, const String objectId);
    void login(const Array permissions);
    void logout();
    bool isLoggedIn();
    void userProfile(Object *callbackOb, const String& callbackMethod);
    void callApi(const String path, const Dictionary properties, Object *callbackOb, const String callbackMethod);

    void pushToken(const String& token);
    void logEvent(const String& event);
    void logEventValue(const String& event, double value);
    void logEventParams(const String& event, const Dictionary params);
    void logEventValueParams(const String& event, double value, const Dictionary params);
    void setAdvertiserTracking(bool tracking);

    String advertisingID();
    Array extinfo();
};

