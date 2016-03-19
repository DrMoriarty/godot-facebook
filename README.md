Simple *App invite on Facebook* module for [Godot Game Engine](http://godotengine.org/) (Android only). 

To use it, make sure you're able to compile the Godot android template, you can find the instructions [here](http://docs.godotengine.org/en/latest/reference/compiling_for_android.html). Just copy the the GodotFacebook folder to godot/modules and recompile it.


**Module name (engine.cfg):**
```
[android]
modules="org/godotengine/godot/GodotFacebook"
```

**Functions:**
* init(app_id)
* appInvite(app_link_url, preview_image_url)

**Example:**
```python
func _ready():
if(Globals.has_singleton("GodotFacebook")):
        fb = Globals.get_singleton("GodotFacebook")
fb.init(‘YOUR_APP_ID’)

(...)

func _on_share_button_pressed():
if fb != null:
fb.appInvite(“YOUR_APP_URL”, ‘YOUR_APP_IMG_URL’)
```        

Any questions? Leave a comment on my blog [http://shinnil.blogspot.com.br](http://shinnil.blogspot.com.br)