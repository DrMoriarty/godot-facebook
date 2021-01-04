extends Node

static func load_file(fname: String) -> String:
    var f = File.new()
    f.open(fname, File.READ)
    var content = f.get_as_text()
    f.close()
    return content

static func save_file(fname: String, content: String) -> void:
    var f = File.new()
    if f.open(fname, File.WRITE) == OK:
        f.store_string(content)
        f.close()
    else:
        print('File %s not found'%fname)

static func process(features: PoolStringArray, debug: bool, path: String, flags: int) -> void:
    var FBAPPID := 'UNDEFINED'
    if ProjectSettings.has_setting('Facebook/FB_APP_ID'):
        FBAPPID = ProjectSettings.get_setting('Facebook/FB_APP_ID')
    else:
        ProjectSettings.set_setting('Facebook/FB_APP_ID', FBAPPID)
    if FBAPPID == 'UNDEFINED':
        push_warning('Facebook/FB_APP_ID not defined! Setup Facebook App ID in project settings.')
    var APPNAME = 'Godot Game'
    if ProjectSettings.has_setting('application/config/name'):
        APPNAME = ProjectSettings.get_setting('application/config/name')
    # iOS
    if 'iOS' in features:
        var plist = load_file('res://addons/nativelib-export/start_hook/facebook-plugin.plist')
        plist = plist.replace('!FBAPPID!', FBAPPID)
        plist = plist.replace('!FBAPPNAME!', APPNAME)
        save_file('res://addons/nativelib-export/iOS/facebook-plugin.plist', plist)
    # Android
    if 'Android' in features:
        var strings = load_file('res://addons/nativelib-export/start_hook/facebook-strings.xml')
        strings = strings.replace('!FBAPPID!', FBAPPID)
        save_file('res://android/facebook/res/values/strings.xml', strings)
