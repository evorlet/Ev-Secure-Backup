;;//Loading animation, thanks to UEZ & original creators
Global $cPic, $g_LoadingText
Global Const $STM_SETIMAGE = 0x0172


Func PlayAnim()
	$hHBmp_BG = _GDIPlus_MultiColorLoader(300, 300, $g_LoadingText)
	$hB = GUICtrlSendMsg($cPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hHBmp_BG)
	If $hB Then _WinAPI_DeleteObject($hB)
	_WinAPI_DeleteObject($hHBmp_BG)
EndFunc   ;==>PlayAnim


Func _GDIPlus_MultiColorLoader($iW, $iH, $sText = "LOADING", $sFont = "Verdana", $bHBitmap = True)
	Local Const $hBitmap = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
	Local Const $hGfx = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	Local $sGUIThemeColor = "0xFF" & StringRight($GUIThemeColor, 6)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx, 4 + (@OSBuild > 5999))
	_GDIPlus_GraphicsSetTextRenderingHint($hGfx, 3)
	_GDIPlus_GraphicsSetPixelOffsetMode($hGfx, $GDIP_PIXELOFFSETMODE_HIGHQUALITY)
	_GDIPlus_GraphicsClear($hGfx, $sGUIThemeColor)

	Local $iRadius = ($iW > $iH) ? $iH * 0.6 : $iW * 0.6

	Local Const $hPath = _GDIPlus_PathCreate()
	_GDIPlus_PathAddEllipse($hPath, ($iW - ($iRadius + 24)) / 2, ($iH - ($iRadius + 24)) / 2, $iRadius + 24, $iRadius + 24)

	Local $hBrush = _GDIPlus_PathBrushCreateFromPath($hPath)
	_GDIPlus_PathBrushSetCenterColor($hBrush, $sGUIThemeColor)
	_GDIPlus_PathBrushSetSurroundColor($hBrush, 0x08F5F5F5)
	_GDIPlus_PathBrushSetGammaCorrection($hBrush, True)

	Local $aBlend[4][2] = [[3]]
	$aBlend[1][0] = 0 ;0% center color
	$aBlend[1][1] = 0 ;position = boundary
	$aBlend[2][0] = 0.33 ;70% center color
	$aBlend[2][1] = 0.1 ;10% of distance boundary->center point
	$aBlend[3][0] = 1 ;100% center color
	$aBlend[3][1] = 1 ;center point
	_GDIPlus_PathBrushSetBlend($hBrush, $aBlend)

	Local $aRect = _GDIPlus_PathBrushGetRect($hBrush)
	_GDIPlus_GraphicsFillRect($hGfx, $aRect[0], $aRect[1], $aRect[2], $aRect[3], $hBrush)

	_GDIPlus_PathDispose($hPath)
	_GDIPlus_BrushDispose($hBrush)

	Local Const $hBrush_Gray = _GDIPlus_BrushCreateSolid("0xFF" & StringRight($GUIThemeColor, 6))
	_GDIPlus_GraphicsFillEllipse($hGfx, ($iW - ($iRadius + 10)) / 2, ($iH - ($iRadius + 10)) / 2, $iRadius + 10, $iRadius + 10, $hBrush_Gray)

	Local Const $hBitmap_Gradient = _GDIPlus_BitmapCreateFromScan0($iRadius, $iRadius)
	Local Const $hGfx_Gradient = _GDIPlus_ImageGetGraphicsContext($hBitmap_Gradient)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx_Gradient, 4 + (@OSBuild > 5999))
	Local Const $hMatrix = _GDIPlus_MatrixCreate()
	Local Static $r = 0
	_GDIPlus_MatrixTranslate($hMatrix, $iRadius / 2, $iRadius / 2)
	_GDIPlus_MatrixRotate($hMatrix, $r)
	_GDIPlus_MatrixTranslate($hMatrix, -$iRadius / 2, -$iRadius / 2)
	_GDIPlus_GraphicsSetTransform($hGfx_Gradient, $hMatrix)
	$r += 10
	Local Const $hBrush_Gradient = _GDIPlus_LineBrushCreate($iRadius, $iRadius / 2, $iRadius, $iRadius, 0xFF000000, 0xFF33CAFD, 1)
	_GDIPlus_LineBrushSetGammaCorrection($hBrush_Gradient)
	_GDIPlus_GraphicsFillEllipse($hGfx_Gradient, 0, 0, $iRadius, $iRadius, $hBrush_Gradient)
	_GDIPlus_GraphicsFillEllipse($hGfx_Gradient, 4, 4, $iRadius - 8, $iRadius - 8, $hBrush_Gray)
	_GDIPlus_GraphicsDrawImageRect($hGfx, $hBitmap_Gradient, ($iW - $iRadius) / 2, ($iH - $iRadius) / 2, $iRadius, $iRadius)
	_GDIPlus_BrushDispose($hBrush_Gradient)
	_GDIPlus_BrushDispose($hBrush_Gray)
	_GDIPlus_GraphicsDispose($hGfx_Gradient)
	_GDIPlus_BitmapDispose($hBitmap_Gradient)
	_GDIPlus_MatrixDispose($hMatrix)

	Local Const $hFormat = _GDIPlus_StringFormatCreate()
	Local Const $hFamily = _GDIPlus_FontFamilyCreate($sFont)
	Local Const $hFont = _GDIPlus_FontCreate($hFamily, $iRadius / 10)
	_GDIPlus_StringFormatSetAlign($hFormat, 1)
	_GDIPlus_StringFormatSetLineAlign($hFormat, 1)
	Local $tLayout = _GDIPlus_RectFCreate(0, 0, $iW, $iH)
	Local Static $iColor = 0x00, $iDir = 13
	Local $hBrush_txt = _GDIPlus_BrushCreateSolid(0xFF000000 + 0x010000 * $iColor + 0x0100 * $iColor + $iColor)
	_GDIPlus_GraphicsDrawStringEx($hGfx, $sText, $hFont, $tLayout, $hFormat, $hBrush_txt)
	$iColor += $iDir
	If $iColor > 0xFF Then
		$iColor = 0xFF
		$iDir *= -1
	ElseIf $iColor < 0x16 Then
		$iDir *= -1
		$iColor = 0x16
	EndIf
	_GDIPlus_BrushDispose($hBrush_txt)
	_GDIPlus_FontDispose($hFont)
	_GDIPlus_FontFamilyDispose($hFamily)
	_GDIPlus_StringFormatDispose($hFormat)
	_GDIPlus_GraphicsDispose($hGfx)

	If $bHBitmap Then
		Local $hHBITMAP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)
		_GDIPlus_BitmapDispose($hBitmap)
		Return $hHBITMAP
	EndIf
	Return $hBitmap
EndFunc   ;==>_GDIPlus_MultiColorLoader
