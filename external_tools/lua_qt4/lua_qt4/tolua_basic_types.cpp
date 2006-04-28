#include "tolua_basic_types.h"

// QtCore
#include <QBitArray>
#include <QByteArray>
#include <QDate>
#include <QDateTime>
#include <QLineF>
#include <QLine>
#include <QPoint>
#include <QPointF>
#include <QRect>
#include <QRectF>
#include <QSize>
#include <QSizeF>
#include <QStringList>
#include <QTime>
#include <QLocale>
#include <QUrl>

// QtGui
#ifdef QT_GUI

#include <QKeySequence>
#include <QQBitmap>
#include <QQBrush>
#include <QQColor>
#include <QCursor>
#include <QFont>
#include <QIcon>
#include <QImage>
#include <QPalette>
#include <QPen>
#include <QPixmap>
#include <QPolygon>
#include <QRegion>
#include <QSizePolicy>
#include <QTextLength>
#include <QTextFormat>
#include <QPointArray>

#endif


// QVariant
QVariant tolua_toQVariant(lua_State* L, int lo, void* def) {

	if (lua_gettop(L) < abs(lo)) {

		return QVariant();
	};

	int type = lua_type(L, lo);
	switch (type) {

	case LUA_TNIL:
		return QVariant();

	case LUA_TSTRING:
		return QVariant(tolua_tostring(L, lo, 0));

	case LUA_TBOOLEAN:
	case LUA_TNUMBER:
		return QVariant(tolua_tonumber(L, lo, 0));

	case LUA_TUSERDATA:

		tolua_Error err;
		if (tolua_isusertype(L, lo, "QVariant", (int)def, &err)) {

			return (QVariant)*(QVariant*)tolua_tousertype(L, -1, def);
		};

		lua_pushstring(L, ".QVariant");
		lua_gettable(L, lo);
		if (lua_isfunction(L, -1)) {

			lua_pushvalue(L, lo);
			lua_call(L, 1, 1);

			if (tolua_isusertype(L, lua_gettop(L), "QVariant", 0, &err)) {

				QVariant ret(*((QVariant*)tolua_tousertype(L, -1, def)));
				lua_pop(L, 1);
				return ret;
			};
		};

		/* fallthrough */

	default:
		; // wtf?
	};

	return QVariant();
};

int tolua_isQVariant(lua_State* L, int lo, int def, tolua_Error* err) {

	if (def && lua_gettop(L)<abs(lo))
		return 1;


	int type = lua_type(L, lo);
	switch (type) {

	case LUA_TNIL:
	case LUA_TSTRING:
	case LUA_TBOOLEAN:
	case LUA_TNUMBER:

		return 1;

	case LUA_TUSERDATA:

		if (tolua_isusertype(L, lo, "QVariant", def, err)) {

			return 1;
		} else {
			lua_pushstring(L, ".QVariant");
			lua_gettable(L, lo);
			int ret = !lua_isnil(L, -1);
			lua_pop(L, 1);
			return ret;
		};

	default:
		/* fallthrough */;
	};

	err->index = lo;
	err->array = 0;
	err->type = "QVariant";
	return 0;
};

#define PUSH_TYPE(T) \
	case QVariant::T: {\
		Q##T* obj = new Q##T(val.value<Q##T>());\
		tolua_pushusertype_and_takeownership(L, obj, "Q"#T);\
		return;\
	};


void tolua_pushQVariant(lua_State* L, const QVariant& val) {

	QVariant::Type type = val.type();

	// convert to native object
	switch (type) {

	case QVariant::Invalid:
		lua_pushnil(L);
		return;

	case QVariant::Bool:
		tolua_pushboolean(L, val.toBool());
		return;

	case QVariant::Int:
	case QVariant::UInt:
	case QVariant::LongLong:
	case QVariant::ULongLong:
	case QVariant::Char:
	case QVariant::Double:
		tolua_pushnumber(L, val.toDouble());
		return;

	case QVariant::String:
		tolua_pushqtstring(L, val.toString());
		return;

	PUSH_TYPE(BitArray);
	PUSH_TYPE(ByteArray);
	PUSH_TYPE(Date);
	PUSH_TYPE(DateTime);
	PUSH_TYPE(LineF);
	PUSH_TYPE(Line);
	PUSH_TYPE(Point);
	PUSH_TYPE(PointF);
	PUSH_TYPE(Rect);
	PUSH_TYPE(RectF);
	PUSH_TYPE(Size);
	PUSH_TYPE(SizeF);
	PUSH_TYPE(StringList);
	PUSH_TYPE(Time);
	PUSH_TYPE(Locale);
	PUSH_TYPE(Url);

	case QVariant::List: {

		QList<QVariant>* obj = new QList<QVariant>(val.value<QList<QVariant> >());
		tolua_pushusertype_and_takeownership(L, obj, "QList<QVariant>");
		return;
	};
	case QVariant::Map: {

		QMap<QString,QVariant>* obj = new QMap<QString,QVariant>(val.value<QMap<QString,QVariant> >());
		tolua_pushusertype_and_takeownership(L, obj, "QList<QVariant>");
		return;
	};

	#ifdef QT_GUI
	PUSH_TYPE(Bitmap);
	PUSH_TYPE(Brush);
	PUSH_TYPE(Color);
	PUSH_TYPE(Cursor);
	PUSH_TYPE(Font);
	PUSH_TYPE(Icon);
	PUSH_TYPE(Image);
	PUSH_TYPE(KeySequence);
	PUSH_TYPE(Palette);
	PUSH_TYPE(Pen);
	PUSH_TYPE(Pixmap);
	PUSH_TYPE(Polygon);
	PUSH_TYPE(Region);
	PUSH_TYPE(SizePolicy);
	PUSH_TYPE(TextLength);
	PUSH_TYPE(TextFormat);
	PUSH_TYPE(PointArray);
	#endif

	case QVariant::UserType:
	default: {

		const char* type_name = val.typeName();
		QVariant* obj = new QVariant(val);
		tolua_pushusertype_and_takeownership(L, obj, "QVariant");

		if (type_name) {
			luaL_getmetatable(L, "QVariant");
			lua_pushstring(L, "tolua_push_value");
			lua_gettable(L, -2);
			lua_pushvalue(L, -3);
			lua_call(L, 1, 1);
			lua_remove(L, -2); // QVariant mt
			if (lua_isnil(L, -1)) {
				lua_pop(L, 1);
			} else {
				lua_remove(L, -2);
			};
		};
		return;
	};

	}; // switch
};

void tolua_pushQVariant__raw(lua_State* L, const QVariant& p_var) {

	QVariant* nvar = new QVariant(p_var);

	tolua_pushusertype_and_takeownership(L, nvar, "QVariant");
};
