#ifndef LUA_QT_HELPERS_H
#define LUA_QT_HELPERS_H

#include "qglobal.h"
#include "lua_qobject.h"

typedef int lua_Object;

class lua_State;

typedef int arg_count;
typedef char* arg_list;

// tolua_begin
class LuaQt {

public:

	static arg_count argc;
	static arg_list* argv;

	static void init_args(lua_State* ls, lua_Object lo);
	static void setmetatable(lua_State* ls, lua_Object obj, lua_Object mt);
	static unsigned int or_list(lua_State* ls, lua_Object obj);
	static unsigned int and_list(lua_State* ls, lua_Object obj);
	static void c_class(lua_State* ls, char* name, char* base);
	static lua_Object get_registry(lua_State* ls);
};

// tolua_end

template <class T>
class ConnectionCollector { // tolua_export

	T connection;

public:

	// tolua_begin
	TEMPLATE_BIND((T, LuaQConnection));

	void disconnect() {

		connection.disconnect();
	};

	bool empty() {

		return connection.empty();
	};

	ConnectionCollector(T& p_connection) : connection(p_connection) {};

	~ConnectionCollector() {
		connection.disconnect();
	};
};

// tolua_end

//typedef int LuaQtGenericFlags


class LuaQtGenericFlags {

	int flag;
public:

	template<typename T>
	LuaQtGenericFlags(QFlags<T> &rvalue) {

		flag = (int)rvalue;
	};

	LuaQtGenericFlags(double number) {

		flag = (int)number;
	};

	/*
	template<typename T>
	inline bool operator=(QFlags<T> &rvalue) {

		flag = (int)rvalue;
	};
	*/

	inline int get() {
		return flag;
	};

	inline operator int() const {return flag;};

	template<typename T>
	inline operator QFlags<T>() {

		//return QFlags<T>((QFlags<T>::enum_type)flag);
		return QFlags<T>((T)flag);
	};
};

#endif
