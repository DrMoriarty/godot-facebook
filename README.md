Facebook module for [Godot Game Engine](http://godotengine.org/) (Android and iOS). 

## Installation

1. Install [NativeLib-CLI](https://github.com/DrMoriarty/nativelib-cli) or [NativeLib Addon](https://github.com/DrMoriarty/nativelib).
2. Make `nativelib -i facebook` in your project directory if your are using CLI.
5. Setup your Facebook App ID in package details or Project settings (`Facebook/FB_APP_ID`). 
3. Enable **NativeLib export plugin** in Project settings.
6. Enable **Custom Build** for using in Android.

## Usage

Gd script wrapper (in `scripts/facebook.gd`) will be automatically added to your autoloading list. You can use it everywhere in your code.

## API

### Common Functions
* login(permissions: Array)
* game_request(message: String, recipients: String, objectId: String)
* game_requests(callback_object: Object, callback_method: String)
* logout()
* is_logged_in() -> bool
* user_profile(callback_object: Object, callback_method: String)
* get_friends(callback_object: Object, callback_method: String)
* get_invitable_friends(callback_object: Object, callback_method: String)

### Analytics Functions
* set_push_token(token: String)
* log_event(event: String, value: int = 0, params: Dictionary = null)
* log_purchase(price: float, currency: String = 'USD', params : Dictionary = null)
* deep_link_uri() -> String
* deep_link_ref() -> String
* deep_link_promo() -> String

### Signals
* fb_inited
* login_success(token)
* login_cancelled
* login_failed(error)
* request_success(result)
* request_cancelled
* request_failed(error)
* logout
