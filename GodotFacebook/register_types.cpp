#include "register_types.h"
#if defined(__APPLE__)
#include "ios/Facebook.h"
#endif

void register_GodotFacebook_types() {
#if defined(__APPLE__)
	ClassDB::register_class<GodotFacebook>();
#endif
}

void unregister_GodotFacebook_types() {
}
