#ifndef TOLUA_BASIC_TYPES_H
#define TOLUA_BASIC_TYPES_H

extern "C" {
	#include "lualib.h"
};
#include "tolua++.h"

#include <QVariant>

// QString
#define tolua_toqtstring(L, i, d) QString::fromUtf8(tolua_tostring(L,i,d), -1)
#define tolua_isqtstring tolua_isstring
#define tolua_pushqtstring(L,s) tolua_pushstring(L, s.toUtf8().constData())

// QFlags
#define tolua_toqtflags (int)tolua_tonumber
#define tolua_isqtflags tolua_isnumber
#define tolua_pushqtflags tolua_pushnumber

// QVariant
QVariant tolua_toQVariant(lua_State* L, int lo, void* def);
int tolua_isQVariant(lua_State* L, int lo, int def, tolua_Error* err);
void tolua_pushQVariant(lua_State* L, const QVariant& val);

#endif
