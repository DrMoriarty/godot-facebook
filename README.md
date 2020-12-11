Facebook module for [Godot Game Engine](http://godotengine.org/) (Android and iOS). 

## Installation

1. Install [NativeLib](https://github.com/DrMoriarty/nativelib-cli)
2. Make `nativelib -i facebook-plugin` in your project directory.

## Usage

You will find gd wrapper in `scripts/facebook.gd`. You can add it to you autoloading list and use it everywhere in your code.

**Functions:**
* init(app_id)
* appInvite(app_link_url, preview_image_url)
* setFacebookCallbackId(get_instance_ID())
* getFacebookCallbackId()
* login()
* logout()
* isLoggedIn()

**Callback functions:**
* login_success(token)
* login_cancelled()
* login_failed(error)

**Example:**
```python
func _ready():
    if(Globals.has_singleton("GodotFacebook")):
        fb = Globals.get_singleton("GodotFacebook")
        fb.init(‘YOUR_APP_ID’)
        fb.setFacebookCallbackId(get_instance_ID())

func login_success(token):
    print('Facebook login success: %s'%token)

func login_cancelled():
    print('Facebook login cancelled')

func login_failed(error):
    print('Facebook login failed: %s'%error)

(...)

func _on_share_button_pressed():
    if fb != null:
        fb.appInvite(“YOUR_APP_URL”, ‘YOUR_APP_IMG_URL’)

func _on_login_button_pressed():
    if fb != null:
        fb.login()
```        

