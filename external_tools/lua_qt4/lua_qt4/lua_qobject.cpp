#include "lua_qobject.h"

//bool LuaQObject::list_init = false;
//QMap<QString, int> LuaQObject::signal_list;

LuaQConnection LuaQObject::connect_signal(lua_State* ls, QObject* p_sender, const char* p_signal, lua_Object p_slot, const char* p_slot_vars) {

	lua_slot.init(ls, p_slot);
	QObject::connect(p_sender, (QString("2")+p_signal).toAscii().constData(), this, (QString("1slot")+p_slot_vars).toAscii().constData());

	return LuaQConnection(this);
};


