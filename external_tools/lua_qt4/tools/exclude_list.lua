exclude_class_list = {

	'QString',
	'QTextCodec',
	"QTextStream",
	"QByteArray",

	"QX11EmbedContainer",
	"QX11EmbedWidget",
	"QWindowsXPStyle",

	-- windows
	"QX11Info",
	"XEvent",
}

exclude_method_list = {

	"QAccessibleObject",
	"QAbstractTableModel",
	"QAbstractListModel",
	"QIODevice",
	"QThread",
	"QAbstractButton",

	-- undefined symbols
	"supportedOperations", -- QHttp
	"formatType", -- QTextObject
	-- "error", -- QX11EmbedContainer
	"QFontMetrics",

	-- windows
	"x11SetScreen",
	"x11SetInfo",
	"x11PictureHandle",
	"x11SetDefaultScreen",
	"x11FilterEvent",
	"x11Info",
	"setPrinterSelectionOption",
	"printerSelectionOption",
}


