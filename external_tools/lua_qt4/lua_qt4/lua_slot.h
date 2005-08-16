#ifndef LUA_SLOT_H
#define LUA_SLOT_H

#include <string>
using std::string;


#ifndef LUA_QT
#include "defines/ref.h"
#endif

extern "C" {
	#include "lualib.h"
};
#include "tolua++.h"
typedef int lua_Object;


#ifdef LUA_QT // patch
inline int lua_dbcall(lua_State* L, int p, int r, std::string f = "print_traceback") {

	lua_getglobal(L,f.c_str());
	lua_insert(L,(-p)-2);
	int ret = lua_pcall(L,p,r,(-p)-2);
	if (ret) {
		return ret;
	} else {
		lua_remove(L, (-r)-1);
	};
	return ret;
};

#endif

// this is not really a slot but the reference to the actual LuaSlot object on the luastate

struct _LuaSlot {

	int slot;
	lua_State* ls;

	void init(lua_State* p_ls, lua_Object p_obj) {

		clear();

		ls = p_ls;
		lua_pushvalue(ls, p_obj);
		slot = lua_ref(ls, 1);
	};
	void clear() {
		if (ls) {
			lua_unref(ls, slot);
			ls = NULL;
		};
	};

	inline bool is_empty() {
		return ls != NULL;
	};

	inline void push_call() {

		lua_getref(ls, slot); // that's all
	};


	_LuaSlot(lua_State* p_ls, lua_Object p_obj) {
		ls = NULL;
		init(p_ls, p_obj);
	};

	_LuaSlot() {

		ls = NULL;
	};

	~_LuaSlot() {

		clear();
	};
};

#ifndef LUA_QT
typedef Ref<_LuaSlot> LuaSlot;
#endif

#endif

