#include "LoadingAnim.au3"

;//GUI elements declaration
Global $ipRestore2_ArchiveDir, $btnRestore2_Browse, $lRestore4_Status
Global $hBkUp2_ContextMenu, $lBkUp4_CurrentFile, $lBkUp4_Status, $eReport, $btnOriginal_Backup, $btnOriginal_Restore
Global $nSizeColumn, $btnNext, $lBkUp3_Pwd, $lBkUp3_PwdConfirm, $ipBkUp3_Pwd, $ipBkUp3_PwdConfirm, $btnOriginal_Restore, $cbBkUp3_ShowPwd
Global $lvBkUp2_BackupList, $btnOriginal_Backup
Global $g_aGUIDropFiles, $sTheme, $sState

;//GUI creation
Global $aGUIPos[] = [0, 0, 403, 500]
$hGUI = _Metro_CreateGUI($g_sProgramName, 403, 500, -1, 100, True)
$hGUIControl = _Metro_AddControlButtons(True, False, True, False, True)
$GUI_CLOSE_BUTTON = $hGUIControl[0]
$GUI_MAXIMIZE_BUTTON = $hGUIControl[1]
$GUI_RESTORE_BUTTON = $hGUIControl[2]
$GUI_MINIMIZE_BUTTON = $hGUIControl[3]
$GUI_MENU_BUTTON = $hGUIControl[6]
GUISetFont(9, 0, 0, "Segoe UI")
GUISetStyle($hGUI, $WS_EX_ACCEPTFILES)
_Metro_SetGUIOption($hGUI, True, True, 400, 400)

;//Create global GUI elements that will be re-used through the stages
$cPic = GUICtrlCreatePic("", 50, 5, $aGUIPos[2], $aGUIPos[2]) ;Loading Animation
GUICtrlSetResizing($cPic, 8 + 32 + 128 + 768)
GUICtrlSetState($cPic, $GUI_HIDE)
$btnNext = _Metro_CreateButtonEx("Next", 314, 457, 70, 30, $ButtonBKColor, $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnNext, 768 + 64) ;HCentered
$btnBack = _Metro_CreateButtonEx("Back", 18, 457, 70, 30, $ButtonBKColor, $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnBack, 768 + 64) ;HCentered

;//Create startup GUI elements (first step)
$btnOriginal_Backup = _Metro_CreateButtonEx("Backup", 144, 170, 120, 60, $ButtonBKColor, $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnOriginal_Backup, 8 + 128 + 768) ;Centered
$btnOriginal_Restore = _Metro_CreateButtonEx("Restore", 144, 260, 120, 60, $ButtonBKColor, $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnOriginal_Restore, 8 + 128 + 768) ;Centered
$lOriginal_Credit = GUICtrlCreateLabel("2015 T.H. sandwichdoge@gmail.com", 195, 475)
GUICtrlSetColor($lOriginal_Credit, $FontThemeColor)
GUICtrlSetResizing($lOriginal_Credit, 4 + 768) ;DockRight+ConstantSize

;//Create stage-2 Backup GUI elements
$lvBkUp2_BackupList = GUICtrlCreateListView("File", 15, 40, $aGUIPos[2] - 27, $aGUIPos[3] - 95)
_GUICtrlListView_SetExtendedListViewStyle($lvBkUp2_BackupList, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_CHECKBOXES))
$nSizeColumn = _GUICtrlListView_AddColumn($lvBkUp2_BackupList, "Size")
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($lvBkUp2_BackupList), "wstr", 0, "wstr", 0)
GUICtrlSetResizing($lvBkUp2_BackupList, 32 + 64 + 4 + 2) ;Centered+Poly
GUICtrlSetState($lvBkUp2_BackupList, $GUI_DROPACCEPTED)
GUICtrlSetBkColor(-1, $GUIThemeColor)
GUICtrlSetColor(-1, $FontThemeColor)

$sLastListUsed = IniRead("_Res\Settings.ini", "General", "LAST_USED_LIST", "MyNewList")
If Not FileExists("ev_" & $sLastListUsed) Then $sLastListUsed = "MyNewList"
$comboBkUp2_Profile = GUICtrlCreateCombo($sLastListUsed, 135, $aGUIPos[3] - 38, 140)
GUICtrlSetTip($comboBkUp2_Profile, "Select your list, new list will be created if list does not exist.")
$hListFileSearch = FileFindFirstFile("ev_*")
For $i = 0 To 50 ;Maximum 50 profiles are registered.
	$sListFileFullname = FileFindNextFile($hListFileSearch)
	If @error Then ExitLoop
	$aListFileReg = StringRegExp($sListFileFullname, "ev_(.+)", 3)
	GUICtrlSetData($comboBkUp2_Profile, $aListFileReg[0])
	_ArrayAdd($g_aProfiles, $aListFileReg[0])
Next
GUICtrlSetResizing($comboBkUp2_Profile, 768 + 64 + 8) ;HCentered

;//Create stage-3 Backup GUI elements
$lBkUp3_Pwd = GUICtrlCreateLabel("Pick your Password:", 40, 130, 200)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($lBkUp3_Pwd), "wstr", 0, "wstr", 0)
GUICtrlSetColor($lBkUp3_Pwd, $FontThemeColor)
$bShowPwd = IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", $GUI_UNCHECKED)
$ipBkUp3_Pwd = GUICtrlCreateInput("", 40, 150, $aGUIPos[2] - 90, 20)
If $bShowPwd = $GUI_UNCHECKED Then GUICtrlSetStyle($ipBkUp3_Pwd, 0x0020)
$lBkUp3_PwdConfirm = GUICtrlCreateLabel("Repeat your Password:", 40, 180, 200)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($lBkUp3_PwdConfirm), "wstr", 0, "wstr", 0)
GUICtrlSetColor($lBkUp3_PwdConfirm, $FontThemeColor)
$ipBkUp3_PwdConfirm = GUICtrlCreateInput("", 40, 200, $aGUIPos[2] - 90, 20, 0x0020)
$cbBkUp3_ShowPwd = GUICtrlCreateCheckbox("Show Password", 40, 230, 130)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($cbBkUp3_ShowPwd), "wstr", 0, "wstr", 0)
GUICtrlSetColor(-1, $FontThemeColor)
$hBkUp3_Settings = GUICtrlCreateGroup("Settings", 30, 280, $aGUIPos[2] - 80, 50)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($hBkUp3_Settings), "wstr", 0, "wstr", 0)
GUICtrlSetColor($hBkUp3_Settings, $FontThemeColor)
$cbBkUp3_Compress = GUICtrlCreateCheckbox("Compress data", 45, 298, 130)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($cbBkUp3_Compress), "wstr", 0, "wstr", 0)
GUICtrlSetColor(-1, $FontThemeColor)
GUICtrlSetTip($cbBkUp3_Compress, "Use native Zip engine to compress data. The process will take longer but the output file will be smaller.")

GUICtrlSetResizing($cbBkUp3_ShowPwd, 1)
GUICtrlSetState($cbBkUp3_ShowPwd, $bShowPwd)

;//Create stage-4 Backup GUI elements
$cbBkUp4_ShowEncryptedFile = GUICtrlCreateCheckbox("Show result file", 160, $aGUIPos[3] - 43)
DllCall("UxTheme.dll", "int", "SetWindowTheme", "hwnd", GUICtrlGetHandle($cbBkUp4_ShowEncryptedFile), "wstr", 0, "wstr", 0)
GUICtrlSetColor($cbBkUp4_ShowEncryptedFile, $FontThemeColor)
GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_CHECKED)

;//Create stage-2 Restore GUI elements(first in Restore)
Global $lRestore2_ArchiveDir = GUICtrlCreateLabel("Select container file. Drag 'n Drop accepted.", 40, $aGUIPos[3] - 333, 300)
GUICtrlSetColor(-1, $FontThemeColor)
$ipRestore2_ArchiveDir = GUICtrlCreateInput("", 40, $aGUIPos[3] - 314, $aGUIPos[2] - 115, 20)
GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_DROPACCEPTED)
$btnRestore2_Browse = _Metro_CreateButtonEx("...", $aGUIPos[2] - 72, $aGUIPos[3] - 314, 20, 20, $ButtonBKColor, $ButtonTextColor, "Segoe UI", 11)

;//Create stage-3 Restore GUI elements
$lRestore3_Pwd = GUICtrlCreateLabel("Enter the Password used during backup process", 40, $aGUIPos[3] - 333)
GUICtrlSetColor(-1, $FontThemeColor)
$ipRestore3_Pwd = GUICtrlCreateInput("", 40, $aGUIPos[3] - 313, $aGUIPos[2] - 93, 20)

;//Icons for BkUp2_ListView
$hImage = _GUIImageList_Create(16, 16)
_GUICtrlListView_SetImageList($lvBkUp2_BackupList, $hImage, 1)

;#End of GUI creation


Func _Interface()
	$msg = GUIGetMsg()
	Switch $msg
		Case $GUI_EVENT_DROPPED
			If @GUI_DropId = 16 Then ;//Drag destination is bkup listview
				If UBound($g_aGUIDropFiles) >= 2 Then ;//1st index = number of items dropped,
					_ArrayDelete($g_aGUIDropFiles, 0) ;//need to delete it
					_AddFilesToLV($lvBkUp2_BackupList, $g_aGUIDropFiles)
				EndIf
			EndIf
		Case $GUI_EVENT_SECONDARYDOWN
			$aCursorInfo = GUIGetCursorInfo($hGUI)
			If $aCursorInfo[4] = $lvBkUp2_BackupList Then
				Local $sSelection = "selected items"
				$nItemSelected = _GUICtrlListView_GetSelectedIndices($lvBkUp2_BackupList)
				If $nItemSelected <> "" Then
					$sSelection = "highlighted"
				Else
					$sSelection = "selected items"
				EndIf	
				If $g_bSelectAll = True Then
					$sPrefix = "De-"
				Else
					$sPrefix = ""
				EndIf
				Local $MenuButtonsArray[5] = ["Open file location", "Add files..", "Add folder..", "Remove " & $sSelection, $sPrefix & "Select All"]
				Local $MenuSelect = _Metro_RightClickMenu($hGUI, 160, $MenuButtonsArray)
				Switch $MenuSelect
					Case "0"
						BkUp2_OpenFileLocation()
					Case "1"
						BkUp2_AddFiles()
					Case "2"
						BkUp2_AddFolder()
					Case "3"
						BkUp2_RemoveSelected()
					Case "4"
						BkUp2_SelectAllCM()
				EndSwitch
			EndIf
		Case $GUI_MENU_BUTTON
			If $sTheme = "LightBlueCustom" Then
				$_sNewTheme = "Dark"
			Else
				$_sNewTheme = "Light"
			EndIf
			Local $MenuButtonsArray[5] = [$_sNewTheme & " Theme", "About", "Exit"]
			Local $MenuSelect = _Metro_MenuStart($hGUI, 140, $MenuButtonsArray)
			Switch $MenuSelect
				Case "0"
					If $sTheme = "LightBlueCustom" Then
						IniWrite($g_sScriptDir & "\_Res\Settings.ini", "GUI", "Theme", "DarkTeal")
					Else
						IniWrite($g_sScriptDir & "\_Res\Settings.ini", "GUI", "Theme", "LightBlueCustom")
					EndIf
					_Metro_MsgBox(0, $g_sProgramName, "Theme change will take effect on the next startup.")
				Case "1"
					_AboutCM()
				Case "2"
					ExitS()
			EndSwitch
		Case $GUI_EVENT_CLOSE, $GUI_CLOSE_BUTTON
			_Metro_GUIDelete($hGUI)
			Exit
		Case $GUI_MINIMIZE_BUTTON
			GUISetState(@SW_MINIMIZE)
		Case $comboBkUp2_Profile
			BkUp2_SelectList()
		Case $btnRestore2_Browse
			Restore2_Browse()
		Case $btnOriginal_Backup
			ToBkUp2()
		Case $btnOriginal_Restore
			Restore2()
		Case $btnNext
			Select
				Case $sState = "B2"
					ToBkUp3()
				Case $sState = "B3"
					ToBkUp4()
				Case $sState = "B4"
					ToBkUp5()
				Case $sState = "R2"
					Restore3()
				Case $sState = "R3"
					Restore4()
				Case $sState = "R4"
					Restore5()
			EndSelect
		Case $btnBack
			Select
				Case $sState = "B2"
					ToOriginal()
				Case $sState = "B3"
					ToBkUp2()
				Case $sState = "B4"
					ToBkUp3()
				Case $sState = "R2"
					ToOriginal()
				Case $sState = "R3"
					Restore2()
				Case $sState = "R4"
					Restore3()
			EndSelect
		Case $cbBkUp3_ShowPwd
			BkUp3_ShowPassword()
	EndSwitch
EndFunc   ;==>_Interface

Func HideAllControls($bHideNextBtn = True)
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	GUICtrlSetState($cbBkUp3_Compress, $GUI_HIDE)
	GUICtrlSetState($lBkUp3_Pwd, $GUI_HIDE)
	GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_HIDE)
	GUICtrlSetState($ipBkUp3_Pwd, $GUI_HIDE)
	GUICtrlSetState($hBkUp3_Settings, $GUI_HIDE)
	GUICtrlSetState($ipBkUp3_PwdConfirm, $GUI_HIDE)
	GUICtrlSetState($cbBkUp3_ShowPwd, $GUI_HIDE)
	GUICtrlSetState($btnOriginal_Backup, $GUI_HIDE)
	GUICtrlSetState($btnOriginal_Restore, $GUI_HIDE)
	GUICtrlSetState($lvBkUp2_BackupList, $GUI_HIDE)
	GUICtrlSetState($comboBkUp2_Profile, $GUI_HIDE)
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_HIDE)
	GUICtrlSetState($lRestore2_ArchiveDir, $GUI_HIDE)
	GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_HIDE)
	GUICtrlSetState($btnRestore2_Browse, $GUI_HIDE)
	GUICtrlSetState($ipRestore3_Pwd, $GUI_HIDE)
	GUICtrlSetState($lRestore3_Pwd, $GUI_HIDE)
	GUICtrlSetState($lRestore4_Status, $GUI_HIDE)
	GUICtrlSetState($lOriginal_Credit, $GUI_HIDE)
	If $bHideNextBtn = True Then
		GUICtrlSetState($btnNext, $GUI_HIDE)
		GUICtrlSetState($btnBack, $GUI_HIDE)
	Else
		GUICtrlSetState($btnNext, $GUI_SHOW)
		GUICtrlSetState($btnBack, $GUI_SHOW)
	EndIf
EndFunc   ;==>HideAllControls

Func ToOriginal()
	HideAllControls(True)
	GUICtrlSetState($lOriginal_Credit, $GUI_SHOW)
	GUICtrlSetState($btnOriginal_Backup, $GUI_SHOW)
	GUICtrlSetState($btnOriginal_Restore, $GUI_SHOW)
	
	$sState = "Original"
EndFunc   ;==>ToOriginal
