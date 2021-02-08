//
//  Facebook.h
//
//  Created by DrMoriarty on 11.02.19.
//
//

#ifndef Facebook_h
#define Facebook_h

#include <Godot.hpp>
#include <Object.hpp>

class FacebookPlugin : public godot::Object {
    GODOT_CLASS(FacebookPlugin, godot::Object);

    static godot::Object * fbCallbackObj;
    static void _bind_methods();

public:
    FacebookPlugin();
    ~FacebookPlugin();

    static void _register_methods();
    void _init();
    
    void init(const godot::String& key);
    void setFacebookCallbackId(godot::Object* facebookcallback);
    void gameRequest(const godot::String& message, const godot::String& recipient, const godot::String& objectId);
    void login(const godot::Array permissions);
    void logout();
    bool isLoggedIn();
    void userProfile(Object *callbackOb, const godot::String& callbackMethod);
    void callApi(const godot::String& path, const godot::Dictionary properties, Object *callbackOb, const godot::String& callbackMethod);

    void pushToken(const godot::String& token);
    void logEvent(const godot::String& event);
    void logEventValue(const godot::String& event, double value);
    void logEventParams(const godot::String& event, const godot::Dictionary params);
    void logEventValueParams(const godot::String& event, double value, const godot::Dictionary params);

    godot::String advertisingID();
    godot::Array extinfo();
};

#endif /* Facebook_h */
