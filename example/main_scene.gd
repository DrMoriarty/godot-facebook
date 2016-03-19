extends Node

var fb
var app_id = "YOUR FB APP ID"
var app_url = "YOUR FB APP URL"
var app_img_url = "YOUR FB APP IMAGE URL"

func _ready():
	if(Globals.has_singleton("GodotFacebook")):
		fb = Globals.get_singleton("GodotFacebook")
		fb.init(app_id)
		pass
	get_node("Button").connect("pressed", self, "_on_Button_pressed")
	
	
func _on_Button_pressed():
	if fb != null:
		fb.appInvite(app_url, app_img_url)
		fb.test()
	pass


