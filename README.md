Facebook module for [Godot Game Engine](http://godotengine.org/) (Android only). 

To use it, make sure you're able to compile the Godot android template, you can find the instructions [here](http://docs.godotengine.org/en/latest/reference/compiling_for_android.html). As the latest Facebook SDK needs Android SDK 15+, edit the file godot/platform/android/build.gradle.template and set minSdkVersion to 15. After that, just copy the the GodotFacebook folder to godot/modules and recompile it.


**Module name (engine.cfg):**
```
[android]
modules="org/godotengine/godot/GodotFacebook"
```

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

Any questions? Leave a comment on my blog [http://shinnil.blogspot.com.br](http://shinnil.blogspot.com.br)
