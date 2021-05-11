#include "facebook_module.h"

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#else
#include "core/engine.h"
#endif

#include "Facebook.hpp"

FacebookPlugin *singleton = NULL;

void register_facebook_types() {
	singleton = memnew(FacebookPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Facebook", singleton));
}

void unregister_facebook_types() {
	if (singleton) {
		memdelete(singleton);
	}
}
