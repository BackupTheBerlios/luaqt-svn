#ifndef LUA_QOBJECT_H
#define LUA_QOBJECT_H

#include <qobject.h>

#include "lua_slot.h"

#include <QObject>
#include <QMap>
#include <QString>
#include <QPointer>

#define tolua_toqtstring(L, i, d) QString::fromUtf8(tolua_tostring(L,i,d), -1)
#define tolua_isqtstring tolua_isstring
#define tolua_pushqtstring(L,s) tolua_pushstring(L, s.toUtf8().constData())

#define tolua_toqtflags (int)tolua_tonumber
#define tolua_isqtflags tolua_isnumber
#define tolua_pushqtflags tolua_pushnumber

class LuaQConnection {

	QPointer<QObject> obj;

public:
	void disconnect() {
		if (!obj.isNull()) {
			obj->deleteLater();
		};
	};
	bool empty() {
		return obj.isNull();
	};

	LuaQConnection(QObject* p_obj = NULL) {
		obj = p_obj;
	};
	LuaQConnection(const LuaQConnection& p_orig) {
		obj = p_orig.obj;
	};
};

class LuaQObject : public QObject {

protected:
	_LuaSlot lua_slot;

public:

	LuaQConnection connect_signal(lua_State* ls, QObject* p_sender, const char* p_signal, lua_Object p_slot, const char* p_slot_vars);

	LuaQObject(QObject* p_parent) : QObject(p_parent) {};
};

class QtSignalHandler {

protected:

	QMap<QString, int> signal_list;
	virtual void init_signal_list()=0;

	_LuaSlot lua_slot;

public:

	virtual LuaQObject* get_q_object(QString p_parameters, QObject* p_parent)=0;

	virtual ~QtSignalHandler() {};
};

#endif
