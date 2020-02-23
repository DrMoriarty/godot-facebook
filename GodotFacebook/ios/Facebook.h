//
//  Facebook.h
//
//  Created by Vasiliy on 11.02.19.
//
//

#ifndef Facebook_h
#define Facebook_h

#include "core/object.h"

class GodotFacebook : public Object {
    GDCLASS(GodotFacebook, Object);

    static int fbCallbackId;
    static void _bind_methods();

public:
    GodotFacebook();
    ~GodotFacebook();

    void init(const String& key);
    void setFacebookCallbackId(int facebookcallbackId);
    int  getFacebookCallbackId();
    void gameRequest(const String& message, const String& recipient, const String& objectId);
    void login(const Array& permissions);
    void logout();
    bool isLoggedIn();
    void userProfile(int callbackObject, const String& callbackMethod);
    void callApi(const String& path, const Dictionary& properties, int callbackObject, const String& callbackMethod);

    void pushToken(const String& token);
    void logEvent(const String& event);
    void logEventValue(const String& event, double value);
    void logEventParams(const String& event, const Dictionary& params);
    void logEventValueParams(const String& event, double value, const Dictionary& params);

    String advertisingID();
    Array extinfo();
};

#endif /* Facebook_h */
