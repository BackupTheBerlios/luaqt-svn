exclude_class_list = {

	'QString',
	'QTextCodec',
	"QTextStream",
	--"QByteArray",

	"QX11EmbedContainer",
	"QX11EmbedWidget",
	"QWindowsXPStyle",

	-- windows
	"QX11Info",
	"XEvent",

	-- qt 4.0.1
	"QDesignerImageCollectionInterface",

	-- private constructor and virtual methods
	"QTextBlockGroup",
}

exclude_method_list = {

	"QAccessibleObject",
	"QAbstractTableModel",
	"QAbstractListModel",
	"QIODevice",
	"QThread",
	"QAbstractButton",

	"Q3CanvasItem",

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

	-- virtual methods with protected/weird types
	"sliderChange",
	"moveCursor",
	"resolveEntity",
	"stepEnabled",
}


