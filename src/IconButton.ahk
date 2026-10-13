/*
IconButton
AHK v2 button class with icon support
-------------------------------------------
Version: 1.1
13/10/2026

https://github.com/mesutakcan/IconButton

-------------------------------------------
Mesut Akcan
github: https://github.com/mesutakcan
blog: https://mesutakcan.blogspot.com
youtube: https://www.youtube.com/mesutakcan
--------------------------------------------

Usage:
------
  btn := IconButton(gui, options, text)
  btn.SetIcon(file, index, size, position)
  btn.ClearIcon()
  btn.IconSize := 24

SetIcon parameters:
--------------------
  file : Icon source file (dll, exe, ico)
  index : 1-based icon index (default: 1)
  size : Icon size in px — logical, DPI-independent (default: 16)
  position : "left" | "right" | "top" | "bottom" (default: "left")
  Ignored when button has no text (icon is centered).

Features:
---------
  • Grayscale on disabled — setting Enabled := false automatically renders the
  existing icon in grayscale; re-enabling restores it.
  • IconSize property — get/set the logical icon size at runtime without
  calling SetIcon again (btn.IconSize := 24).
  • ClearIcon() — completely removes the icon from the button.
  • Auto DPI tracking — listens for WM_DPICHANGED and rescales the icon
  when the window moves to a different-DPI monitor.
*/

#Requires AutoHotkey v2.0

class IconButton {
	static _alignMap := Map("left", 0, "right", 1, "top", 2, "bottom", 3, "center", 4)

	; Construction / destruction

	__New(gui, options := "", text := "") {
		this.DefineProp("_btn", { Value: gui.Add("Button", options, text) })
		this.DefineProp("_gui", { Value: gui })
		this.DefineProp("_text", { Value: text })
		this.DefineProp("_hIL", { Value: 0 }) ; normal ImageList handle
		this.DefineProp("_hILGray", { Value: 0 }) ; grayscale ImageList handle (lazy)
		this.DefineProp("_hIcon", { Value: 0 }) ; raw HICON kept for grayscale
		this.DefineProp("_file", { Value: "" })
		this.DefineProp("_index", { Value: 1 })
		this.DefineProp("_size", { Value: 16 })
		this.DefineProp("_scaledSize", { Value: 0 })  ; cached DPI-scaled icon size
		this.DefineProp("_position", { Value: "left" })

		; Save original text-alignment style bits so ClearIcon can restore them.
		; BS_LEFT=0x0100, BS_RIGHT=0x0200, BS_CENTER=0x0300 — mask is 0x0300.
		; GetWindowLong works on both 32-bit and 64-bit processes; GetWindowLongPtr
		; is unavailable in 32-bit builds.
		origStyle := DllCall("GetWindowLong", "Ptr", this._btn.Hwnd, "Int", -16, "Int")
		this.DefineProp("_origTextAlign", { Value: origStyle & 0x0300 })

		; Register DPI-change handler
		this.DefineProp("_dpiCB", { Value: this._OnDpiChanged.Bind(this) })
		OnMessage(0x02E0, this._dpiCB) ; WM_DPICHANGED
	}

	__Delete() {
		OnMessage(0x02E0, this._dpiCB, 0) ; unregister
		this._DestroyAll()
	}

	__Get(name, params) {
		if name = "Text"
			return this._text
		return this._btn.%name%
	}

	__Call(name, params) => this._btn.%name%(params*)

	__Set(name, params, value) {
		if name = "Enabled" {
			this._btn.Enabled := value
			this._ApplyIL()
			return
		}

		if name = "Text" {
			this.DefineProp("_text", { Value: value })
			this._RefreshText()
			this._ApplyIL()
			return
		}

		this._btn.%name% := value
	}

	; IconSize property

	IconSize {
		get => this._size
		set {
			this.DefineProp("_size", { Value: value })
			if this._file != ""
				this.SetIcon(this._file, this._index, value, this._position)
		}
	}

	; Public API

	/*
	 Attaches (or replaces) an icon on the button.
	
	 @param {string} file - Icon source (dll / exe / ico)
	 @param {number} index - 1-based icon index
	 @param {number} size - Logical icon size in px (DPI scaling applied internally)
	 @param {string} position - "left" | "right" | "top" | "bottom"
	*/
	SetIcon(file, index := 1, size := 16, position := "left") {
		this._DestroyAll()

		; Persist all parameters — needed by IconSize, DPI rescale, grayscale regen
		this.DefineProp("_file", { Value: file })
		this.DefineProp("_index", { Value: index })
		this.DefineProp("_size", { Value: size })
		this.DefineProp("_position", { Value: position })

		scaledSize := this._ScaleSize(size)
		this.DefineProp("_scaledSize", { Value: scaledSize })

		; Build the normal ImageList
		hIL := DllCall("ImageList_Create",
			"Int", scaledSize, "Int", scaledSize, "UInt", 0x21, "Int", 1, "Int", 0, "Ptr")
		IL_Add(hIL, file, index)
		this.DefineProp("_hIL", { Value: hIL })

		; Extract an HICON copy for on-demand grayscale conversion
		hIcon := DllCall("ImageList_GetIcon", "Ptr", hIL, "Int", 0, "UInt", 0, "Ptr")
		this.DefineProp("_hIcon", { Value: hIcon })

		; Re-render text now that icon position is known
		this._RefreshText()

		; Apply the right ImageList depending on current Enabled state
		this._ApplyIL()
	}

	/*
	 Removes the icon from the button and frees all related GDI resources.
	 Passing a zeroed BUTTON_IMAGELIST (hImageList = 0) is more reliable than
	 sending a raw null pointer as lParam.
	*/
	ClearIcon() {
		Psz := A_PtrSize
		BIL := Buffer(Psz + 20, 0) ; all fields zero — hImageList = 0 → detach
		SendMessage(0x1602, 0, BIL.Ptr, this._btn.Hwnd)

		; Restore original text alignment, then free GDI resources
		this._SetTextAlign(this._origTextAlign)
		this._DestroyAll()
		this.DefineProp("_file", { Value: "" })
		this._RefreshText()
	}

	; Private helpers

	; Returns the DPI-scaled pixel count for a logical size value.
	; Uses GetDpiForWindow (Win 10+) with a GetDeviceCaps fallback.
	_ScaleSize(size) {
		dpi := DllCall("GetDpiForWindow", "Ptr", this._btn.Hwnd, "UInt")
		if !dpi {
			hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
			dpi := DllCall("GetDeviceCaps", "Ptr", hDC, "Int", 90, "Int") ; LOGPIXELSY
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
		}
		return Round(size * dpi / 96)
	}
	; Returns text as it should be rendered on the native button.
	; For horizontal icon modes, we insert a single space to force a visual gap.
	_RenderText() {
		text := this._text
		if text = ""
			return ""
		if !this._hIL
			return text
		switch this._position {
			case "left":
				return " " text
			case "right":
				return text " "
			default:
				return text
		}
	}

	_RefreshText() {
		this._btn.Text := this._RenderText()
	}
	; Applies the correct ImageList (normal or grayscale) based on current Enabled state.
	_ApplyIL() {
		if !this._hIL
			return
		if this._btn.Enabled
			this._SendIL(this._hIL)
		else
			this._SendIL(this._EnsureGrayIL())
	}

	; Fills and sends a BUTTON_IMAGELIST structure for the given ImageList handle.
	_SendIL(hIL) {
		position := this._position
		scaledSize := this._scaledSize

		align := (this._text = "")
			? 4
			: (IconButton._alignMap.Has(position) ? IconButton._alignMap[position] : 0)

		mL := 0, mT := 0, mR := 0, mB := 0

		if this._text != "" {
			switch position {
				case "left", "right":
					{
						client := this._GetClientSize()
						tw := this._MeasureText()
						totalW := scaledSize + tw
						side := Max(0, Round((client.W - totalW) / 2))

						if position = "left" {
							mL := side
							this._SetTextAlign(0x0100) ; BS_LEFT
						} else {
							mR := side
							this._SetTextAlign(0x0200) ; BS_RIGHT
						}
					}
				case "top":
					mT := 4, mB := 2
					this._SetTextAlign(this._origTextAlign)
				case "bottom":
					mB := 4, mT := 2
					this._SetTextAlign(this._origTextAlign)
				default:
					this._SetTextAlign(this._origTextAlign)
			}
		} else {
			; Icon-only: restore original alignment
			this._SetTextAlign(this._origTextAlign)
		}

		Psz := A_PtrSize
		BIL := Buffer(Psz + 20, 0)
		NumPut("Ptr", hIL, BIL, 0)
		NumPut("Int", mL, BIL, Psz)
		NumPut("Int", mT, BIL, Psz + 4)
		NumPut("Int", mR, BIL, Psz + 8)
		NumPut("Int", mB, BIL, Psz + 12)
		NumPut("UInt", align, BIL, Psz + 16)

		SendMessage(0x1602, 0, BIL.Ptr, this._btn.Hwnd) ; BCM_SETIMAGELIST
	}

	; Returns the button's client area dimensions as an object {W, H}.
	_GetClientSize() {
		rc := Buffer(16, 0)
		DllCall("GetClientRect", "Ptr", this._btn.Hwnd, "Ptr", rc.Ptr)
		return { W: NumGet(rc, 8, "Int"), H: NumGet(rc, 12, "Int") }
	}

	; Measures the pixel width of the given text using the button's current font.
	_MeasureText(text := "") {
		if text = ""
			text := this._btn.Text
		if text = ""
			return 0
		hDC := DllCall("GetDC", "Ptr", this._btn.Hwnd, "Ptr")
		hFont := SendMessage(0x0031, 0, 0, this._btn.Hwnd) ; WM_GETFONT
		hOld := DllCall("SelectObject", "Ptr", hDC, "Ptr", hFont, "Ptr")
		sz := Buffer(8, 0)
		DllCall("GetTextExtentPoint32W",
			"Ptr", hDC, "Str", text, "Int", StrLen(text), "Ptr", sz.Ptr)
		DllCall("SelectObject", "Ptr", hDC, "Ptr", hOld)
		DllCall("ReleaseDC", "Ptr", this._btn.Hwnd, "Ptr", hDC)
		return NumGet(sz, 0, "Int") ; text width in pixels
	}
	; Sets the button's text-alignment style bits (BS_LEFT / BS_RIGHT / BS_CENTER).
	; All other window-style bits are preserved.
	_SetTextAlign(alignBits) {
		GWL_STYLE := -16
		cur := DllCall("GetWindowLong", "Ptr", this._btn.Hwnd, "Int", GWL_STYLE, "Int")
		DllCall("SetWindowLong", "Ptr", this._btn.Hwnd, "Int", GWL_STYLE,
			"Int", (cur & ~0x0300) | alignBits, "Int")
		DllCall("InvalidateRect", "Ptr", this._btn.Hwnd, "Ptr", 0, "Int", 1)
	}

	; Returns the grayscale ImageList, building it on first call (lazy init).
	_EnsureGrayIL() {
		if this._hILGray
			return this._hILGray
		hILGray := this._BuildGrayscaleIL(this._hIcon, this._scaledSize)
		this.DefineProp("_hILGray", { Value: hILGray })
		return hILGray
	}

	/*
	 Creates an ImageList whose single slot is a grayscale copy of hIcon.
	 Algorithm:
	 1. Draw hIcon into a 32-bit top-down DIB.
	 2. Walk every BGRA pixel and replace R/G/B with the Rec. 601 luminance.
	 Alpha is left unchanged so transparency is fully preserved.
	 3. Wrap the modified bitmap in a fresh ImageList.
	
	 @param {Ptr} hIcon - Source HICON (must remain valid during the call)
	 @param {number} size - Pixel size (already DPI-scaled)
	 @returns {Ptr} Handle to the new grayscale ImageList
	*/
	_BuildGrayscaleIL(hIcon, size) {
		; Create a 32-bit top-down DIB inside a memory DC
		hDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")

		bi := Buffer(40, 0)
		NumPut("Int", 40, bi, 0) ; biSize
		NumPut("Int", size, bi, 4) ; biWidth
		NumPut("Int", -size, bi, 8) ; biHeight — negative = top-down scan order
		NumPut("Short", 1, bi, 12) ; biPlanes
		NumPut("Short", 32, bi, 14) ; biBitCount (BGRA)

		pBits := 0
		hBmp := DllCall("CreateDIBSection",
			"Ptr", hDC,
			"Ptr", bi.Ptr,
			"UInt", 0, ; DIB_RGB_COLORS
			"Ptr*", &pBits,
			"Ptr", 0,
			"UInt", 0,
			"Ptr")
		hOld := DllCall("SelectObject", "Ptr", hDC, "Ptr", hBmp, "Ptr")

		; Render the icon into the DIB
		DllCall("DrawIconEx",
			"Ptr", hDC,
			"Int", 0, "Int", 0,
			"Ptr", hIcon,
			"Int", size, "Int", size,
			"UInt", 0,
			"Ptr", 0,
			"UInt", 0x0003) ; DI_NORMAL

		; Copy pixel data, apply grayscale, write back
		byteCount := size * size * 4
		pixels := Buffer(byteCount)
		DllCall("RtlMoveMemory", "Ptr", pixels.Ptr, "Ptr", pBits, "UPtr", byteCount)

		off := 0
		loop size * size {
			; DIB memory layout per pixel: [B][G][R][A]
			b := NumGet(pixels, off, "UChar")
			g := NumGet(pixels, off + 1, "UChar")
			r := NumGet(pixels, off + 2, "UChar")
			; Rec. 601 luma: Y = 0.299·R + 0.587·G + 0.114·B
			gray := Round(0.299 * r + 0.587 * g + 0.114 * b)
			NumPut("UChar", gray, pixels, off)
			NumPut("UChar", gray, pixels, off + 1)
			NumPut("UChar", gray, pixels, off + 2)
			; Alpha byte (off + 3) intentionally untouched — transparency preserved
			off += 4
		}

		DllCall("RtlMoveMemory", "Ptr", pBits, "Ptr", pixels.Ptr, "UPtr", byteCount)
		DllCall("SelectObject", "Ptr", hDC, "Ptr", hOld)
		DllCall("DeleteDC", "Ptr", hDC)

		; Wrap the grayscale bitmap in a new ImageList
		hIL := DllCall("ImageList_Create",
			"Int", size, "Int", size, "UInt", 0x21, "Int", 1, "Int", 0, "Ptr")
		DllCall("ImageList_Add", "Ptr", hIL, "Ptr", hBmp, "Ptr", 0, "Int")
		DllCall("DeleteObject", "Ptr", hBmp)
		return hIL
	}

	; WM_DPICHANGED handler — fired when the window moves to a different-DPI monitor.
	; Rebuilds both ImageLists at the new DPI so the icon stays pixel-perfect.
	_OnDpiChanged(wParam, lParam, msg, hwnd) {
		if hwnd != this._gui.Hwnd || this._file = ""
			return
		; Re-enter SetIcon with the same logical parameters;
		; _ScaleSize() will read the updated per-window DPI automatically.
		this.SetIcon(this._file, this._index, this._size, this._position)
	}

	; Frees all three GDI handles without clearing stored parameters.
	_DestroyAll() {
		if this._hIL {
			DllCall("ImageList_Destroy", "Ptr", this._hIL)
			this.DefineProp("_hIL", { Value: 0 })
		}
		if this._hILGray {
			DllCall("ImageList_Destroy", "Ptr", this._hILGray)
			this.DefineProp("_hILGray", { Value: 0 })
		}
		if this._hIcon {
			DllCall("DestroyIcon", "Ptr", this._hIcon)
			this.DefineProp("_hIcon", { Value: 0 })
		}
	}
}