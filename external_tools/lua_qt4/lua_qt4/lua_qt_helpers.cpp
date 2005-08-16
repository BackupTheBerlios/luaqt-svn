#include "lua_qt_helpers.h"

extern "C" {
	#include "lualib.h"
};
#include <string.h>
#include <tolua++.h>
#include <string>

int LuaQt::argc = 0;
char** LuaQt::argv = NULL;

void LuaQt::init_args(lua_State* ls, lua_Object lo) {

	lua_pushvalue(ls, lo);
	lua_pushstring(ls, "n");
	lua_gettable(ls, -2);
	argc = (int)lua_tonumber(ls, -1)+1;
	argv = new char*[argc];
	lua_pop(ls, 1);

	for (int i=0; i<argc; i++) {

		lua_rawgeti(ls, -1, i);
		if (!lua_isstring(ls, -1)) {
			lua_pop(ls, 1);
			continue;
		};
		int size = lua_strlen(ls, -1);
		argv[i] = new char[size+1];
		strcpy(argv[i], lua_tostring(ls, -1));
		lua_pop(ls, 1);
	};

	lua_pop(ls, 1);

	/*
	// set argc and argv
	lua_getglobal(ls, "LuaQt");
	lua_pushstring(ls, "argv");
	tolua_pushusertype(ls, (void*)argv, "arg_list");
	lua_settable(ls, -3);

	lua_pushstring(ls, "argc");
	tolua_pushusertype(ls, (void*)&argc, "arg_count");
	lua_settable(ls, -3);
	*/
};


void LuaQt::setmetatable(lua_State* ls, lua_Object obj, lua_Object mt) {

	lua_pushvalue(ls, mt);
	lua_setmetatable(ls, obj);
};


void LuaQt::c_class(lua_State* ls, char* name, char* base) {

	std::string lname = name;
	tolua_beginmodule(ls, NULL);
	tolua_beginmodule(ls, name);
	tolua_cclass(ls, name, (char*)lname.c_str(), base, NULL);
	tolua_endmodule(ls);
	tolua_endmodule(ls);
};

lua_Object LuaQt::get_registry(lua_State* ls) {

	return LUA_REGISTRYINDEX;
};


int LuaQt::or_list(lua_State* L, lua_Object t) {

	int ret;

	lua_pushnil(L);  /* first key */
	if (lua_next(L, t) == 0) return 0;
	ret = (int)lua_tonumber(L, -1);
	lua_pop(L, 1);

	/* table is in the stack at index `t' */
	while (lua_next(L, t) != 0) {
		/* `key' is at index -2 and `value' at index -1 */

		ret = ret | (int)lua_tonumber(L, -1);

		lua_pop(L, 1);  /* removes `value'; keeps `key' for next iteration */
	}

	return ret;
};

int LuaQt::and_list(lua_State* L, lua_Object t) {

	int ret;

	lua_pushnil(L);  /* first key */
	if (lua_next(L, t) == 0) return 0;
	ret = (int)lua_tonumber(L, -1);
	lua_pop(L, 1);

	/* table is in the stack at index `t' */
	while (lua_next(L, t) != 0) {
		/* `key' is at index -2 and `value' at index -1 */

		ret = ret & (int)lua_tonumber(L, -1);

		lua_pop(L, 1);  /* removes `value'; keeps `key' for next iteration */
	}

	return ret;
};

