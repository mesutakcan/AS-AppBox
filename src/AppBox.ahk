/*
AS AppBox
-----------------------------
This script serves as an application manager that helps organize and manage your frequently used programs.
-----------------------------
v1.1
2026-10-13
-----------------------------
Mesut Akcan
makcan@gmail.com
youtube.com/mesutakcan
mesutakcan.blogspot.com
github.com/mesutakcan
-----------------------------
*/
;@Ahk2Exe-SetDescription AS AppBox - Application Manager
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetFileVersion 1.1
;@Ahk2Exe-SetMainIcon icons\appbox.ico
;@Ahk2Exe-AddResource icons\add.ico, 160
;@Ahk2Exe-AddResource icons\remove.ico, 161
;@Ahk2Exe-AddResource icons\run.ico, 162
;@Ahk2Exe-AddResource icons\save.ico, 163
;@Ahk2Exe-AddResource icons\switch.ico, 164
;@Ahk2Exe-AddResource icons\exit.ico, 165
;@Ahk2Exe-AddResource icons\clear.ico, 166

#Requires AutoHotkey v2.0
#SingleInstance Force
#Include IconButton.ahk

appName := "AS AppBox"
appVer := "1.1"
listFile := A_ScriptDir "\applist.txt"
appListChanged := false

appList := []
appSet := Map()
appSet.CaseSense := false

; Toolbar icons: [file, index, size].
iconDir := A_ScriptDir "\icons\"
if !A_IsCompiled
	TraySetIcon(iconDir "appbox.ico")

settingsFile := A_ScriptDir "\settings.ini"
viewMode := 0
try viewMode := Integer(IniRead(settingsFile, "View", "Mode", "0"))
if (viewMode < 0 || viewMode > 3)
	viewMode := 0

sortCol := 0
sortDesc := false
try sortCol := Integer(IniRead(settingsFile, "Sort", "Column", "0"))
try sortDesc := Integer(IniRead(settingsFile, "Sort", "Descending", "0")) ? true : false
if (sortCol < 0 || sortCol > 2)
	sortCol := 0

ToolIcon(name, id, size := 24) {
	return A_IsCompiled ? [A_ScriptFullPath, -id, size] : [iconDir name ".ico", 1, size]
}

toolIcons := Map(
	"add", ToolIcon("add", 160),
	"remove", ToolIcon("remove", 161),
	"run", ToolIcon("run", 162),
	"save", ToolIcon("save", 163),
	"switch", ToolIcon("switch", 164),
	"exit", ToolIcon("exit", 165),
	"clear", ToolIcon("clear", 166)
)

menuTxt := {
	add: "&Add",
	remove: "Re&move selected",
	run: "&Run application",
	open: "&Open file location",
	copy: "&Copy full path",
	save: "&Save list`tCtrl+S",
	clear: "&Clear list",
	select: "&Select all",
	deselect: "&Deselect all",
	exit: "&Exit`tAlt+F4",
	shortcuts: "&Keyboard shortcuts",
	about: "&About",
	file: "&File",
	help: "&Help"
}

mGui := Gui("+Resize +MinSize540x570", appName)
mGui.Opt("+OwnDialogs")
mGui.SetFont("s9", "Segoe UI")

mGui.Add("Text", "y+10", "Filter:")
txtFilter := mGui.Add("Edit", "x+5 yp-4 w200")
btnClearFilter := IconButton(mGui, "x+3 yp-2 w32 hp+2")
btnClearFilter.SetIcon(toolIcons["clear"][1], toolIcons["clear"][2], toolIcons["clear"][3])
btnClearFilter.OnEvent("Click", ClearFilter)
txtFilter.OnEvent("Change", (*) => SetTimer(FilterList, -100))
filterCue := "Type to filter..."
SendMessage(0x1501, true, StrPtr(filterCue), txtFilter)

btnAdd := MakeToolButton("x10 y+10 w66 h32", "&Add", "add", AddToList)
btnRemove := MakeToolButton("x+5 w86 hp Disabled", "Re&move", "remove", RemoveSelected)
btnRun := MakeToolButton("x+5 w66 hp Disabled", "&Run", "run", RunSelected)
btnSave := MakeToolButton("x+5 w76 hp Disabled", "&Save", "save", SaveList)
MakeToolButton("x+5 w120 hp", "S&witch view", "switch", SwitchView)
MakeToolButton("x+5 w76 hp", "&Exit", "exit", g1Close)

LV1 := mGui.Add("ListView", "x10 y+5 r15 w380 Grid +0x40", ["File name", "Full path"])
LV1.OnEvent("DoubleClick", RunSelected)
LV1.OnEvent("ItemSelect", (*) => SetTimer(UpdateUIState, -15))
LV1.OnEvent("ContextMenu", ShowContextMenu)
LV1.OnEvent("ColClick", OnColClick)

imlSmall := GetSysImageList(false)
imlLarge := GetSysImageList(true)

sbMain := mGui.Add("StatusBar")
sbMain.SetParts(300)
mGui.OnEvent("Size", GuiResize)
mGui.OnEvent("Close", g1Close)
mGui.OnEvent("DropFiles", DropHandler)

fileMenu := Menu()
AddMenuItems(fileMenu)
fileMenu.Add()
fileMenu.Add(menuTxt.exit, g1Close)

rcMenu := Menu()
AddMenuItems(rcMenu)

helpMenu := Menu()
helpMenu.Add(menuTxt.shortcuts, ShowShortcuts)
helpMenu.Add()
helpMenu.Add(menuTxt.about, About)

mnuBar := MenuBar()
mnuBar.Add(menuTxt.file, fileMenu)
mnuBar.Add(menuTxt.help, helpMenu)
mGui.MenuBar := mnuBar

#HotIf WinActive("ahk_id " mGui.Hwnd)
^s:: (btnSave.Enabled ? SaveList() : SoundBeep())
^f:: FocusFilter()
#HotIf WinActive("ahk_id " mGui.Hwnd) && !IsFilterFocused()
Insert:: AddToList()
#HotIf IsListFocused()
^a:: SelectAll(true)
Esc:: SelectAll(false)
Del:: (btnRemove.Enabled ? RemoveSelected() : SoundBeep())
Enter:: RunSelected()
NumpadEnter:: RunSelected()
#HotIf WinActive("ahk_id " mGui.Hwnd) && IsFilterFocused()
Esc:: ClearFilter()
Down:: FocusList()
#HotIf

mGui.Show(GetShowOptions())
SetViewMode(viewMode)
LoadList()

; --- FUNCTIONS ---

IsFilterFocused() {
	return ControlGetFocus("A") = txtFilter.Hwnd
}

IsListFocused() {
	return WinActive("ahk_id " mGui.Hwnd) && ControlGetFocus("A") = LV1.Hwnd
}

FocusFilter(*) {
	txtFilter.Focus()
	SendMessage(0xB1, 0, -1, txtFilter)
}

ClearFilter(*) {
	txtFilter.Value := ""
	FilterList()
}

ApplySort() {
	if sortCol
		LV1.ModifyCol(sortCol, sortDesc ? "SortDesc" : "Sort")
}

OnColClick(ctrl, col) {
	global sortCol, sortDesc
	sortDesc := (sortCol = col) ? !sortDesc : false
	sortCol := col
	ApplySort()
	try {
		IniWrite(sortCol, settingsFile, "Sort", "Column")
		IniWrite(sortDesc ? 1 : 0, settingsFile, "Sort", "Descending")
	}
}

FocusList(*) {
	if (LV1.GetCount() = 0)
		return
	LV1.Focus()
	if !LV1.GetNext()
		LV1.Modify(1, "Select Focus")
}

GetShowOptions() {
	try {
		x := Integer(IniRead(settingsFile, "Window", "X"))
		y := Integer(IniRead(settingsFile, "Window", "Y"))
		w := Integer(IniRead(settingsFile, "Window", "W"))
		h := Integer(IniRead(settingsFile, "Window", "H"))
		vx := SysGet(76), vy := SysGet(77), vw := SysGet(78), vh := SysGet(79)
		if (w >= 540 && h >= 570 && x > vx - 50 && x < vx + vw - 100 && y >= vy - 10 && y < vy + vh - 100)
			return Format("x{1} y{2} w{3} h{4}", x, y, w, h)
	}
	return "w550 h600"
}

SaveWindowState() {
	if (WinGetMinMax(mGui) != 0)
		return
	mGui.GetPos(&x, &y)
	mGui.GetClientPos(, , &w, &h)
	try {
		IniWrite(x, settingsFile, "Window", "X")
		IniWrite(y, settingsFile, "Window", "Y")
		IniWrite(w, settingsFile, "Window", "W")
		IniWrite(h, settingsFile, "Window", "H")
	}
}

ShowShortcuts(*) {
	text := "Filter box`n"
		. "  Esc - clear the filter`n"
		. "  Down - move to the list`n`n"
		. "List`n"
		. "  Enter / Numpad Enter - run selected`n"
		. "  Del - remove selected`n"
		. "  Ctrl+A - select all`n"
		. "  Esc - deselect all`n"
		. "  Click a column header - sort the list`n`n"
		. "Anywhere`n"
		. "  Ctrl+F - go to the filter box`n"
		. "  Insert - add applications`n"
		. "  Ctrl+S - save the list`n"
		. "  Drag & drop - add files or folders"
	MsgBox(text, "Keyboard Shortcuts", "Owner" mGui.Hwnd)
}

MakeToolButton(opts, text, iconKey, handler) {
	global mGui, toolIcons
	btn := IconButton(mGui, opts, text)
	ic := toolIcons[iconKey]
	btn.SetIcon(ic[1], ic[2], ic[3], "left")
	btn.OnEvent("Click", handler)
	return btn
}

AddMenuItems(mnu) {
	global menuTxt

	menuItems := [
		[menuTxt.add, AddToList, true],
		[menuTxt.remove, RemoveSelected],
		[""],
		[menuTxt.run, RunSelected],
		[menuTxt.open, OpenFileLocation],
		[menuTxt.copy, CopyFullPath],
		[menuTxt.save, SaveList],
		[menuTxt.clear, ClearList],
		[""],
		[menuTxt.select, (*) => SelectAll(true)],
		[menuTxt.deselect, (*) => SelectAll(false)]
	]

	for item in menuItems {
		if (item[1] = "")
			mnu.Add()
		else {
			mnu.Add(item[1], item[2])
			if (!item.Has(3))
				mnu.Disable(item[1])
		}
	}
}

GuiResize(thisGui, minMax, width, height) {
	if (minMax = -1)
		return
	LV1.GetPos(&lvX, &lvY, &lvW, &lvH)
	newW := width - 20, newH := height - lvY - 30
	LV1.Move(, , newW, newH)
	LV1.ModifyCol(1, newW * 0.3)
	LV1.ModifyCol(2, newW * 0.7 - 10)
}

FilterList(*) {
	filter := txtFilter.Value
	LV1.Opt("-Redraw")
	LV1.Delete()
	for path in appList {
		if (filter = "" || InStr(path, filter)) {
			SplitPath(path, &name)
			LV1.Add("Icon" (GetIconIndex(path) + 1), name, path)
		}
	}
	ApplySort()
	LV1.Opt("+Redraw")
	UpdateUIState()
	btnClearFilter.Enabled := (filter != "")
	sbMain.SetText(filter = "" ? appList.Length " app(s)" : LV1.GetCount() " of " appList.Length " app(s)", 2)
}

GetSysImageList(large) {
	static sfi := Buffer(A_PtrSize + 688)
	; SHGFI_SYSICONINDEX | SHGFI_USEFILEATTRIBUTES | SHGFI_SMALLICON
	return DllCall("Shell32\SHGetFileInfoW", "Str", "C:\", "UInt", 0, "Ptr", sfi, "UInt", sfi.Size
		, "UInt", 0x4000 | 0x10 | (large ? 0 : 0x1), "Ptr")
}

GetIconIndex(path) {
	static cache := Map(), sfi := Buffer(A_PtrSize + 688)
	static uniqueExt := Map("exe", 1, "lnk", 1, "ico", 1, "scr", 1, "cpl", 1, "msc", 1, "url", 1)

	if cache.Has(path)
		return cache[path]

	SplitPath(path, , , &ext)
	ext := StrLower(ext)
	isUnique := uniqueExt.Has(ext) || (ext = "" && DirExist(path))

	if !isUnique {
		key := "." ext
		if cache.Has(key)
			return cache[key]
		ok := DllCall("Shell32\SHGetFileInfoW", "Str", key, "UInt", 0x80, "Ptr", sfi, "UInt", sfi.Size
			, "UInt", 0x4000 | 0x10, "Ptr")
		return cache[key] := ok ? NumGet(sfi, A_PtrSize, "Int") : 0
	}

	ok := DllCall("Shell32\SHGetFileInfoW", "Str", path, "UInt", 0, "Ptr", sfi, "UInt", sfi.Size
		, "UInt", 0x4000, "Ptr")
	return cache[path] := ok ? NumGet(sfi, A_PtrSize, "Int") : 0
}

AddToList(*) {
	global appListChanged
	files := FileSelect("M35", , "Select Application", "All Files (*.*)")
	if !files.Length
		return

	added := 0
	for file in files
		added += AddToAppList(file) ? 1 : 0

	if added {
		appListChanged := true
		UpdateUIState()
	}

	skipped := files.Length - added
	sbMain.SetText(Format("Added: {1}, Duplicates: {2}", added, skipped))
	FilterList()
}

AddToAppList(path) {
	if appSet.Has(path)
		return false
	appSet[path] := true
	appList.Push(path)
	return true
}

RemoveSelected(*) {
	global appList, appListChanged

	doomed := Map()
	doomed.CaseSense := false
	row := 0
	while (row := LV1.GetNext(row))
		doomed[LV1.GetText(row, 2)] := true

	if !doomed.Count {
		sbMain.SetText("No items selected")
		return
	}

	if (doomed.Count > 1 && MsgBox(Format("Remove {1} selected items from the list?", doomed.Count), "Confirm Remove", "YesNo Icon?") != "Yes") {
		sbMain.SetText("Operation cancelled")
		return
	}

	kept := []
	for path in appList
		if !doomed.Has(path)
			kept.Push(path)

	removed := appList.Length - kept.Length
	appList := kept
	appSet.Clear()
	for path in kept
		appSet[path] := true

	if removed {
		appListChanged := true
		UpdateUIState()
	}
	sbMain.SetText("Removed " removed " item(s)")
	FilterList()
}

RunSelected(*) {
	row := 0, ok := 0, failed := []
	while row := LV1.GetNext(row) {
		path := LV1.GetText(row, 2)
		SplitPath(path, , &dir)
		try {
			Run(path, dir)
			ok++
		} catch as err
			failed.Push(path ": " err.Message)
	}

	if (ok || failed.Length)
		sbMain.SetText(Format("Launched: {1}, Failed: {2}", ok, failed.Length))
	else
		sbMain.SetText("No items selected")

	if failed.Length
		MsgBox("Failed to run:`n`n" Join("`n", failed), "Error", "Icon!")
}

CopyFullPath(*) {
	selected := []
	row := 0
	while (row := LV1.GetNext(row))
		selected.Push(LV1.GetText(row, 2))

	if !selected.Length {
		sbMain.SetText("No items selected")
		return
	}

	A_Clipboard := Join("`r`n", selected)
	sbMain.SetText("Copied " selected.Length " path(s) to clipboard")
}

Join(sep, arr) {
	str := ""
	for i, v in arr
		str .= (i > 1 ? sep : "") v
	return str
}

SaveList(*) {
	global appListChanged
	tmpFile := listFile ".tmp"
	try {
		if FileExist(tmpFile)
			FileDelete(tmpFile)
		FileAppend(Join("`n", appList) "`n", tmpFile, "UTF-8")
		FileMove(tmpFile, listFile, true)
	} catch as err {
		MsgBox("Failed to save list.`nError: " err.Message, "Error", "Icon!")
		return
	}
	appListChanged := false
	UpdateUIState()
	sbMain.SetText("Saved " appList.Length " application(s)")
}

LoadList(*) {
	global appListChanged
	appList.Length := 0
	appSet.Clear()

	if !FileExist(listFile) {
		sbMain.SetText("Drop files here or click Add to get started")
		FilterList()
		return
	}

	text := FileRead(listFile, "UTF-8")
	migrated := InStr(text, Chr(0xFFFD)) ? true : false
	if migrated
		text := FileRead(listFile, "CP0")

	loaded := 0
	for line in StrSplit(text, "`n", "`r") {
		path := Trim(line)
		if (path != "" && AddToAppList(path))
			loaded++
	}

	appListChanged := migrated
	sbMain.SetText(loaded ? "Loaded " loaded " application(s)" : "Drop files here or click Add to get started")
	FilterList()
}

UpdateUIState(*) {
	global appListChanged, menuTxt

	hasSelected := LV1.GetCount("Selected") > 0
	hasItems := LV1.GetCount() > 0

	btnRemove.Enabled := hasSelected
	btnRun.Enabled := hasSelected
	btnSave.Enabled := appListChanged

	menuItems := Map(
		menuTxt.save, appListChanged,
		menuTxt.remove, hasSelected,
		menuTxt.run, hasSelected,
		menuTxt.copy, hasSelected,
		menuTxt.clear, appList.Length > 0,
		menuTxt.select, hasItems,
		menuTxt.deselect, hasItems,
		menuTxt.open, hasSelected
	)

	for mText, enabled in menuItems {
		for menu in [fileMenu, rcMenu] {
			try enabled ? menu.Enable(mText) : menu.Disable(mText)
		}
	}
}

g1Close(*) {
	global appListChanged
	if appListChanged {
		result := MsgBox("The list has been modified. Do you want to save changes?", "Save Changes", "YesNoCancel Icon?")
		if (result = "Cancel")
			return true
		if (result = "Yes") {
			SaveList()
			if appListChanged
				return true
		}
	}
	SaveWindowState()
	ExitApp()
}

ShowContextMenu(LV1, Item, IsRightClick, X, Y) {
	rcMenu.Show(X, Y)
}

ClearList(*) {
	global appListChanged
	if (appList.Length = 0) {
		sbMain.SetText("List is already empty")
		return
	}

	result := MsgBox("All items in the list will be deleted. Are you sure?", "Confirmation", "OKCancel Icon? Default2 T5")
	if (result != "OK") {
		sbMain.SetText("Operation cancelled")
		return
	}

	appList.Length := 0
	appSet.Clear()
	appListChanged := true
	txtFilter.Value := ""
	FilterList()
	sbMain.SetText("List cleared")
}

SelectAll(select) {
	if (select && LV1.GetCount() = 0) {
		sbMain.SetText("No items to select")
		return
	}

	LV1.Modify(0, select ? "Select" : "-Select")
	sbMain.SetText(select ? "All items selected" : "Selection cleared")
	UpdateUIState()
}

SwitchView(*) {
	SetViewMode(Mod(viewMode + 1, 4))
	try IniWrite(viewMode, settingsFile, "View", "Mode")
}

SetViewMode(mode) {
	global viewMode := mode
	LV1.Opt(mode < 2 ? "+Report" : "+Icon")
	LV1.SetImageList((mode & 1) ? imlLarge : imlSmall, mode < 2)
}

DropHandler(gObj, gCtrlObj, FileArray, X, Y) {
	global appListChanged

	if (!FileArray.Length) {
		sbMain.SetText("No valid files dropped")
		return
	}

	added := 0
	for file in FileArray
		added += AddToAppList(file) ? 1 : 0

	if (added) {
		appListChanged := true
		UpdateUIState()
		sbMain.SetText("Added " added " file(s) by drag & drop")
	} else
		sbMain.SetText("No new files added (possibly duplicates)")

	FilterList()
}

OpenFileLocation(*) {
	row := LV1.GetNext()
	if !row {
		sbMain.SetText("No item selected")
		return
	}

	path := LV1.GetText(row, 2)
	if !FileExist(path) {
		sbMain.SetText("File not found")
		MsgBox("File not found: " path, "Error", "Icon!")
		return
	}

	Run('explorer.exe /select,"' path '"')
	sbMain.SetText("Opened file location")
}

About(*) {
	MsgBox(Format("
	(
		{1} v{2}
		Mesut Akcan
		makcan@gmail.com
		mesutakcan.blogspot.com
		github.com/mesutakcan
		youtube.com/mesutakcan
	)", appName, appVer), "About", "Owner" mGui.Hwnd)
}
