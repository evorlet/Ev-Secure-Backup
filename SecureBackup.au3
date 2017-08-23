#cs
	Ev-Secure Backup - Gathers your files in one place and encrypt them for easier and more secure backup.

	T.H. evorlet@gmail.com
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>

	Changelog:
	//v1.1:
	- Fixed "add files.." selection issue, strengthen derived password (v1.0 backups can't be retrieved with v1.1 or later)
	//v1.2:
	- [GUI]Corrected "show password" and loading animation's position
	- [List]Removed .txt requirement for lists, list names can't be empty, added option to purge all lists
	- [Other]Added Purge Folders shell for FileShredder, option to Purge YourData restoration folder
	//v1.3:
	- [GUI] Modified "About"
	- [List]Default folders are no longer de-selected when changing list, unchecked items are now saved
	- [Script]Cleanup and added descriptions for future implementation and maintenance
	//v1.3.5:
	- [GUI]Fixed label resizing problem in backup step 3
	- [List]Fixed new files added not auto-checking, fixed bug where default folders were not processed, added option to open file location
	- [Script]Global array for default folders => less constant elements
	//v1.3.7:
	- [List]Fixed bug where switching between lists didn't display correctly, added browser data backup
	//v1.3.9:
	- [List]Browser data states are now saved
	- [Other]List files are now encrypted
	//v1.4.4:
	- [GUI]Show password checkbox state is remembered, corrected git link in "About" section, redesigned buttons
	- [Other]Added option to purge jump lists and event logs in Windows, Icon for FileShredder, FileShredder can now handle UAC-locked files
	- [Script]Replaced _FileInUse() with _FileWriteAccessible()
	//v1.4.8:
	- [Encryption]Shortened derived password for better performance, added compression-free encryption
	- [GUI]Corrected report area positioning, fixed various GUI bugs
	- [Other]Some part of registry are purged during Windows activity wipe to remove traces
	//v1.5.0:
	- [Encryption]Output containers are now named after profile name instead of "EncryptedContainer"
	- [GUI]Cursor for Backup and Restore buttons
	- [Other]Purge all history located in "AppDataLocal\Microsoft\Windows", "\AppData\Local\Microsoft\Windows\InetCache", "AppData\Media Cache" - WinClear
	//v1.5.3
	- [GUI]Metro GUI overhaul
	//v1.6.0
	- [List]User can now selectively backup browser history/bookmarks instead of processing everything
	- [List]Better file/folder size display
	//v1.6.2
	- [GUI]Improved various aesthetics, brought back drag 'n drop for metro GUI
	- [List]Corrected Google Chrome data path
	//v1.6.3
	- [Fix]Compression no longer gets stuck on non-existing files
	//v1.6.4
	- [Fix]Reworked and fixed all bugs with File Shredder
	TODO: (high to low priority)
	- Upload processed files to remote server (Google Drive, Dropbox, FTP, etc.)
	- Option to put the files back where they originally were
	- Generate html file to assist with restoration process
#ce
#include <GuiconstantsEx.au3>
#include <ListViewConstants.au3>
#include <ButtonConstants.au3>
#include <GuiButton.au3>
#include <Array.au3>
#include <GUIListView.au3>
#include <GUIImageList.au3>
#include <WinAPIex.au3>
#include <GUICombobox.au3>
#include <Crypt.au3>
#include <EditConstants.au3>
#include <GUIMenu.au3>
#include <WinAPIShellEx.au3>
#include <File.au3>
#include <String.au3>
#include <GDIPlus.au3>
#include <WindowsConstants.au3>
#include <WinAPIEx.au3>
#include <EventLog.au3>
#include "_Zip.au3"
#include "MetroGUI_UDF.au3"
;//Keywords for compilation
#pragma compile(ProductVersion, 1.6.4)
#pragma compile(FileVersion, 1.6.4)
#pragma compile(UPX, False)
#pragma compile(LegalCopyright, evorlet@wmail.io)
#pragma compile(ProductName, Ev-Secure Backup)
#pragma compile(FileDescription, Securely backup your data)
_SetTheme("WhiteBlue")
Global $g_sProgramName = "Ev-Secure Backup", $g_sScriptDir = @ScriptDir
If StringRight($g_sScriptDir, 1) = "\" Then $g_sScriptDir = StringTrimRight($g_sScriptDir, 1) ;@ScriptDir's properties may change on different OS versions

;//[Shred] cmd if called with parameter
If $CmdLine[0] >= 1 Then
	If StringRegExp($CmdLineRaw, "/shred") Then
		If StringRegExp($CmdLine[1], "\\") Then
			If Not StringRegExp(FileGetAttrib($CmdLine[1]), "D") Then
				If _FileWriteAccessible($CmdLine[1]) = 1 Then
					_FileShred($CmdLine[1])
				Else
					If Not IsAdmin() Then ShellExecute(@AutoItExe, $CmdLine[1] & " /shred", "", "runas")
				EndIf
			Else
				_PurgeDir($CmdLine[1])
				DirRemove($CmdLine[1], 1)
			EndIf
		EndIf
	ElseIf $CmdLineRaw = "/add" Then
		_AddShredderCM()
	EndIf
	Exit
EndIf

Opt("TrayAutoPause", 0)
Opt("TrayMenuMode", 3)
Opt('TrayOnEventMode', 1)

_GDIPlus_Startup()
_Crypt_Startup()
Global Const $STM_SETIMAGE = 0x0172

;//Global vars declaration

;$g_aDefaultItems: list of default folders to be added to the top when creating or loading listview ["Text to show", "DirPath", "IconPath"]
Global $g_aDefaultItems[][] = [["Documents", @UserProfileDir & "\Documents", "\_Res\Doc.bmp"], ["Pictures", @UserProfileDir & "\Pictures", "\_Res\Pic.bmp"], ["Music", @UserProfileDir & "\Music", "\_Res\Music.bmp"], ["Videos", @UserProfileDir & "\Videos", "\_Res\Video.bmp"]]
Global $g_nDefaultFoldersCount = UBound($g_aDefaultItems); Important variable, to be used in various listview functions
Global $g_sProgramVersion = "1.6.4"
Global $g_aToBackupItems[0], $g_bSelectAll = False, $iPerc = 0, $g_iAnimInterval = 20, $g_aProfiles[0], $sCurProfile, $sState, $g_LoadingText

;//GUI elements declaration
Global $ipRestore2_ArchiveDir, $btnRestore2_Browse, $lRestore4_Status
Global $hBkUp2_ContextMenu, $cmBkUp2_SelectAll, $lBkUp4_CurrentFile, $lBkUp4_Status, $eReport, $btnOriginal_Backup, $btnOriginal_Restore
Global $nSizeColumn, $btnNext, $lBkUp3_Pwd, $lBkUp3_PwdConfirm, $ipBkUp3_Pwd, $ipBkUp3_PwdConfirm, $btnOriginal_Restore, $cbBkUp3_ShowPwd
Global $lvBkUp2_BackupList, $btnOriginal_Backup
Global $aGUIPos[] = [0,0,400,500]
;//GUI creation

;$hGUI = GUICreate($g_sProgramName, 400, 500, -1, 100, BitOR($WS_MINIMIZEBOX, $WS_SIZEBOX), $WS_EX_ACCEPTFILES)
$hGUIx =_Metro_CreateGUI($g_sProgramName, 403, 500, -1, 100, True, True)
$GUI_HOVER_REG = $hGUIx[1]
$hGUI = $hGUIx[0]
$GUI_CLOSE_BUTTON = $hGUIx[2]
$GUI_MAXIMIZE_BUTTON = $hGUIx[3]
$GUI_RESTORE_BUTTON = $hGUIx[4]
$GUI_MINIMIZE_BUTTON = $hGUIx[5]

;//Create global GUI elements that will be re-used through the stages
$cPic = GUICtrlCreatePic("", 50, 0, $aGUIPos[2], $aGUIPos[2]);Loading Animation
GUICtrlSetResizing($cPic, 8 + 32 + 128 + 768)
GUICtrlSetState($cPic, $GUI_HIDE)
$btnNext = _Metro_CreateButtonEx($GUI_HOVER_REG, "Next", 314, 457, 70, 30, $ButtonBKColor,  $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnNext, 768 + 64);HCentered
$btnBack = _Metro_CreateButtonEx($GUI_HOVER_REG, "Back", 18, 457, 70, 30, $ButtonBKColor,  $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnBack, 768 + 64);HCentered

;//Create startup GUI elements (first step)
$btnOriginal_Backup = _Metro_CreateButtonEx($GUI_HOVER_REG, "Backup", 144, 170, 120, 60, $ButtonBKColor,  $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnOriginal_Backup, 8 + 128 + 768);Centered
$btnOriginal_Restore = _Metro_CreateButtonEx($GUI_HOVER_REG, "Restore", 144, 260, 120, 60, $ButtonBKColor,  $ButtonTextColor, "Segoe UI", 11)
GUICtrlSetResizing($btnOriginal_Restore, 8 + 128 + 768);Centered
$lOriginal_Credit = GUICtrlCreateLabel("T.H. evorlet@wmail.io", 195, 470)

GUICtrlSetResizing($lOriginal_Credit, 4 + 768);DockRight+ConstantSize

;//Create stage-2 Backup GUI elements
$lvBkUp2_BackupList = GUICtrlCreateListView("File", 15, 40, $aGUIPos[2] - 27, $aGUIPos[3] - 95)
_GUICtrlListView_SetExtendedListViewStyle($lvBkUp2_BackupList, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_CHECKBOXES))
$nSizeColumn = _GUICtrlListView_AddColumn($lvBkUp2_BackupList, "Size")
GUICtrlSetResizing($lvBkUp2_BackupList, 32 + 64 + 4 + 2);Centered+Poly
$hBkUp2_ContextMenu = GUICtrlCreateContextMenu($lvBkUp2_BackupList)
$cmBkUp2_OpenLocation = GUICtrlCreateMenuItem("Open file location", $hBkUp2_ContextMenu)
$cmBkUp2_AddBackupItem = GUICtrlCreateMenuItem("Add files..", $hBkUp2_ContextMenu)
$cmBkUp2_AddBackupFolder = GUICtrlCreateMenuItem("Add folder..", $hBkUp2_ContextMenu)
$cmBkUp2_RemoveBackupItem = GUICtrlCreateMenuItem("Remove from list", $hBkUp2_ContextMenu)
$cmBkUp2_SelectAll = GUICtrlCreateMenuItem("Select-All", $hBkUp2_ContextMenu)



$sLastListUsed = IniRead("_Res\Settings.ini", "General", "LAST_USED_LIST", "MyNewList")
If Not FileExists("ev_" & $sLastListUsed) Then $sLastListUsed = "MyNewList"
$comboBkUp2_Profile = GUICtrlCreateCombo($sLastListUsed, 145, $aGUIPos[3] - 38, 120)
GUICtrlSetTip($comboBkUp2_Profile, "Select your list, new list will be created if list does not exist.")
$hListFileSearch = FileFindFirstFile("ev_*")
For $i = 0 To 50;Maximum 50 list profiles are registered.
	$sListFileFullname = FileFindNextFile($hListFileSearch)
	If @error Then ExitLoop
	$aListFileReg = StringRegExp($sListFileFullname, "ev_(.+)", 3)
	GUICtrlSetData($comboBkUp2_Profile, $aListFileReg[0])
	_ArrayAdd($g_aProfiles, $aListFileReg[0])
Next
GUICtrlSetResizing($comboBkUp2_Profile, 768 + 64 + 8);HCentered

;//Create stage-3 Backup GUI elements
$lBkUp3_Pwd = GUICtrlCreateLabel("Pick your Password:", 40, 130, 200)

$bShowPwd = IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", $GUI_UNCHECKED)
$ipBkUp3_Pwd = GUICtrlCreateInput("", 40, 150, $aGUIPos[2] - 90, 18)
If $bShowPwd = $GUI_UNCHECKED Then GUICtrlSetStyle($ipBkUp3_Pwd, 0x0020)
$lBkUp3_PwdConfirm = GUICtrlCreateLabel("Repeat your Password:", 40, 180, 200)
$ipBkUp3_PwdConfirm = GUICtrlCreateInput("", 40, 200, $aGUIPos[2] - 90, 18, 0x0020)
$cbBkUp3_ShowPwd = GUICtrlCreateCheckbox("Show Password", 40, 230, 130)
$hBkUp3_Settings = GUICtrlCreateGroup("Settings", 30, 280, $aGUIPos[2] - 80, 50)
$cbBkUp3_Compress = GUICtrlCreateCheckbox("Compress data", 45, 298, 130)

GUICtrlSetResizing($cbBkUp3_ShowPwd, 1)
GUICtrlSetState($cbBkUp3_ShowPwd, $bShowPwd)

;//Create stage-4 Backup GUI elements
$cbBkUp4_ShowEncryptedFile = GUICtrlCreateCheckbox("Show result file", 160, $aGUIPos[3] - 43)
GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_CHECKED)

;//Create stage-2 Restore GUI elements(first in Restore)
$lRestore2_ArchiveDir = GUICtrlCreateLabel("Select container file/folder. Drag 'n Drop accepted.", 40, $aGUIPos[3] - 333, 300)
$ipRestore2_ArchiveDir = GUICtrlCreateInput("", 40, $aGUIPos[3] - 314, $aGUIPos[2] - 115, 20)
GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_DROPACCEPTED)
$btnRestore2_Browse = _Metro_CreateButtonEx($GUI_HOVER_REG, "...", $aGUIPos[2] - 72, $aGUIPos[3] - 314, 20, 20, $ButtonBKColor,  $ButtonTextColor, "Segoe UI", 11)

;//Create stage-3 Restore GUI elements
$lRestore3_Pwd = GUICtrlCreateLabel("Enter the Password used during backup process", 40, $aGUIPos[3] - 333)
$ipRestore3_Pwd = GUICtrlCreateInput("", 40, $aGUIPos[3] - 313, $aGUIPos[2] - 93, 18)

;//Icons for BkUp2_ListView
$hImage = _GUIImageList_Create(16, 16)
_GUIImageList_AddBitmap($hImage, $g_sScriptDir & "\_Res\File.bmp")
_GUIImageList_AddBitmap($hImage, $g_sScriptDir & "\_Res\Folder.bmp")

_GUICtrlListView_SetImageList($lvBkUp2_BackupList, $hImage, 1)

;#End of GUI creation

;//Tray stuff
$hTrayAddShred = TrayCreateItem("Integrate File-Shredder")
TrayItemSetOnEvent(-1, "_AddShredderCM")
_GUICtrlMenu_SetItemBmp(TrayItemGetHandle(0), 0, _WinAPI_Create32BitHBITMAP(_WinAPI_ShellExtractIcon("_Res\kwikdisk.ico", 0, 18, 18), 1, 1))
$hTrayMenuPurge = TrayCreateMenu("Purge")
$hTrayPurgeDir = TrayCreateItem("YourData folder", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeDataDirCM")
_GUICtrlMenu_SetItemBmp(TrayItemGetHandle($hTrayMenuPurge), 0, _WinAPI_Create32BitHBITMAP(_WinAPI_ShellExtractIcon("_Res\1442169766_MB__LOCK.ico", 0, 16, 16), 1, 1))
$hTrayPurgeLists = TrayCreateItem("Saved data lists", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeListsCM")
_GUICtrlMenu_SetItemBmp(TrayItemGetHandle($hTrayMenuPurge), 1, _WinAPI_Create32BitHBITMAP(_WinAPI_ShellExtractIcon("_Res\1442169766_MB__LOCK.ico", 0, 16, 16), 1, 1))
$hTrayPurgeLists = TrayCreateItem("All Windows activities", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeRecentsCM")
_GUICtrlMenu_SetItemBmp(TrayItemGetHandle($hTrayMenuPurge), 2, _WinAPI_Create32BitHBITMAP(_WinAPI_ShellExtractIcon("_Res\windows.ico", 0, 16, 16), 1, 1))
$hTrayAbout = TrayCreateItem("About")
TrayItemSetOnEvent(-1, "_AboutCM")
TrayCreateItem("")
$hTrayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitS")

;//Initialize
ToOriginal()
GUISetState(@SW_SHOW)

;//Timer for Loading Animation
DllCall("user32.dll", "int", "SetTimer", "hwnd", $hGUI, "int", 0, "int", $g_iAnimInterval, "int", 0)

While 1
	_Interface()
WEnd

Func _Interface()
	_Metro_HoverCheck_Loop($GUI_HOVER_REG, $hGUI);This hover check has to be added to the main While loop, otherwise the hover effects won't work.
	$msg = GUIGetMsg()
	Switch $msg
		Case $GUI_EVENT_CLOSE, $GUI_CLOSE_BUTTON
			_Metro_GUIDelete($GUI_HOVER_REG, $hGUI)
			Exit
		Case $GUI_MINIMIZE_BUTTON
			GUISetState(@SW_MINIMIZE)
		Case $cmBkUp2_OpenLocation
			BkUp2_OpenFileLocation()
		Case $cmBkUp2_AddBackupItem
			BkUp2_AddFiles()
		Case $cmBkUp2_AddBackupFolder
			BkUp2_AddFolder()
		Case $cmBkUp2_RemoveBackupItem
			BkUp2_RemoveSelected()
		Case $cmBkUp2_SelectAll
			BkUp2_SelectAllCM()
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
EndFunc	

#Region Dealing with GUI elements (buttons, selection..)
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

Func Restore2()
	HideAllControls(False)
	GUICtrlSetState($lRestore2_ArchiveDir, $GUI_SHOW)
	GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_SHOW)
	GUICtrlSetState($btnRestore2_Browse, $GUI_SHOW)
	
	$sState = "R2"
EndFunc   ;==>Restore2

Func Restore3()
	$sContainerPath = GUICtrlRead($ipRestore2_ArchiveDir)
	If Not StringRegExp($sContainerPath, "^(.*\\)(.*)") Then
		_Metro_MsgBox($g_sProgramName, "Please select a container file/folder to restore from.")
		Return
	EndIf
	HideAllControls(False)
	GUICtrlSetState($lRestore3_Pwd, $GUI_SHOW)
	GUICtrlSetState($ipRestore3_Pwd, $GUI_SHOW)
	ControlFocus($hGUI, "", $ipRestore3_Pwd)
	
	$sState = "R3"
EndFunc   ;==>Restore3

Func Restore4()
	;//Main step in restoration, retrieve files from encrypted container
	Local $sReport
	If Not GUICtrlRead($ipRestore3_Pwd) Then
		_Metro_MsgBox($g_sProgramName, "Please enter a Password.")
		Return
	EndIf
	
	DirCreate($g_sScriptDir & "\YourData")
	$sTempZip = $g_sScriptDir & "\_temp.zip"
	$sTempDir = $g_sScriptDir & "\YourData"
	$sPwd = GUICtrlRead($ipRestore3_Pwd)
	$sPwdHashed = _DerivePwd($sPwd)
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)

	HideAllControls(False)
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim");//Show and play loading animation
	GUICtrlSetState($btnBack, $GUI_HIDE)
	GUICtrlSetState($btnNext, $GUI_DISABLE)
	
	$sContainerPath = GUICtrlRead($ipRestore2_ArchiveDir)
	;//Decrypt
	$aGUIPos = WinGetPos($hGUI)
	$lRestore4_Status = GUICtrlCreateLabel("", ($aGUIPos[2] / 2) - 120, $aGUIPos[3] - 233, 280, 30, BitOR(0x0200, 0x01))
	GUICtrlSetFont($lRestore4_Status, 11, 550, Default, "Segoe UI")
	GUICtrlSetResizing($lRestore4_Status, 8 + 32 + 128 + 768)
	$sReport &= "Decrypting container.." & @CRLF
	
	If StringRegExp(FileGetAttrib($sContainerPath), "D") Then ;//Container is folder, therefore wasn't compressed.
		_Crypt_DecryptFolder($sContainerPath, $g_sScriptDir & "\YourData", $hKey, $CALG_USERKEY)
	Else
		If FileExists("_temp.zip") Then _FileShred($sTempZip)
		$g_LoadingText = "Decrypting"
		_Crypt_DecryptFile(StringReplace(GUICtrlRead($ipRestore2_ArchiveDir), "\\", "\"), $g_sScriptDir & "\_temp.zip", $hKey, $CALG_USERKEY)
		$iError = @error		
		If Not $iError Then
			For $i = 0 To 30
				If FileExists("_temp.zip") Then ExitLoop
				Sleep(200)
			Next
			;//Extract data
			GUICtrlSetData($lRestore4_Status, "")
			$g_LoadingText = "Extracting"
			_Zip_UnzipAll($sTempZip, $sTempDir, 20 + 1024 + 4096)
			If $iError Then
				$sReport &= "Error extracting archive. Code: " & $iError & @CRLF
			Else
				$sReport &= "Everything extracted to " & $sTempDir & @CRLF
				$sReport &= "Shredding leftovers.." & @CRLF
			EndIf
			_FileShred($sTempZip)
		Else
			$sTemp = $iError
			$sReport &= "Error decrypting container - " & StringReplace($sTemp, "420", "Invalid password.") & @CRLF
		EndIf
	EndIf
	$sReport &= "Restoration finished." & @CRLF
	_Crypt_DestroyKey($hKey)
	;//Remaining GUI stuff
	GUICtrlSetData($lRestore4_Status, "")
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$eReport = GUICtrlCreateEdit($sReport, 15, 45, $aCtrlPos[0] + $aCtrlPos[2], 200, BitOR($WS_VSCROLL, $ES_READONLY));//This control is deleted in step 5
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_SHOW)
	GUICtrlSetState($btnNext, $GUI_ENABLE)
	_GUICtrlButton_SetImage($btnNext, "_Res\Finish.bmp")
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	
	$sState = "R4"
EndFunc   ;==>Restore4

Func Restore5()
	GUICtrlDelete($eReport)
	_GUICtrlButton_SetImage($btnNext, $g_sScriptDir & "\_Res\Next.bmp")
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then _WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\YourData")
	$sState = "R5"
	ToOriginal()
EndFunc   ;==>Restore5

Func ToBkUp2()
	Local $aBkUpList[] = [], $sTemp
	HideAllControls(False)
	GUICtrlSetState($lvBkUp2_BackupList, $GUI_SHOW)
	GUICtrlSetState($comboBkUp2_Profile, $GUI_SHOW)
	
	If _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) = 0 Then;*If Listview is empty then create new list
		_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
		_AddDefaultFoldersToLV($lvBkUp2_BackupList)
		$sTemp = FileRead($g_sScriptDir & "\ev_" & GUICtrlRead($comboBkUp2_Profile))
		If $sTemp Then $sTemp = BinaryToString(_Crypt_DecryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256));//Decrypt list file
		$aBkUpList = StringSplit($sTemp, "|", 2)
		_AddFilesToLV($lvBkUp2_BackupList, $aBkUpList, True)
		;If Not $aBkUpList Then BkUp2_SelectAll($lvBkUp2_BackupList);*Is new list
		_DefaultItemStates_Load()
		_GUICtrlListView_SetColumnWidth($lvBkUp2_BackupList, 0, $aGUIPos[2] - 105)
		_GUICtrlListView_SetColumnWidth($lvBkUp2_BackupList, $nSizeColumn, 70)
		_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
	EndIf
	
	$sState = "B2"
EndFunc   ;==>ToBkUp2

Func ToBkUp3()
	Local $a, $sTemp, $aAccelKeys, $aAllItems[0], $sRegExPattern
	$sCurProfile = GUICtrlRead($comboBkUp2_Profile)
	If Not $sCurProfile Then
		_Metro_MsgBox($g_sProgramName, "List name must not be empty!")
		ControlFocus($hGUI, "", $comboBkUp2_Profile)
		Return
	EndIf
	
	;//Add new item to profile combo box if list doesn't exist
	_ArraySearch($g_aProfiles, $sCurProfile)
	If @error Then
		GUICtrlSetData($comboBkUp2_Profile, $sCurProfile)
		_ArrayAdd($g_aProfiles, $sCurProfile)
	EndIf
	
	;//Get ready to save to list file
	ReDim $g_aToBackupItems[0]
	For $i = 0 To _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1
		$sBackupItem = _GUICtrlListView_GetItemText($lvBkUp2_BackupList, $i)
		If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $i) = True Then
			_ArrayAdd($g_aToBackupItems, $sBackupItem)
			If $i >= $g_nDefaultFoldersCount Then $sBackupItem &= "::chkd"; Mark if item is checked for future list saving, ignored if is default folder
		EndIf
		_ArrayAdd($aAllItems, $sBackupItem)
	Next
	; $aAllItems: all items - for list saving|$g_aToBackupItems: checked items only
	
	If UBound($g_aToBackupItems) = 0 Then; No item checked
		_Metro_MsgBox($g_sProgramName, "No files were selected for backup.")
		Return
	EndIf
	
	#Region List stuff
	;//Generate [raw] string to save to list file, default folders are removed
	For $i = 0 To UBound($aAllItems) - 1
		$sTemp &= $aAllItems[$i] & "|"
	Next
	;//Remove default folders from list file
	For $i = 0 To UBound($g_aDefaultItems) - 1
		$sRegExPattern &= $g_aDefaultItems[$i][0] & "|"
	Next
	$sRegExPattern = StringTrimRight($sRegExPattern, 1); Remove last "|" delimiter so "|" symbols don't get erased during regex replace
	$sTemp = StringRegExpReplace($sTemp, "\x7C?(" & $sRegExPattern & ")\x7C", "")
	$sTemp = _Crypt_EncryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256);//Encrypt list file
	
	;//Save the name of current list for future program startup
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "LAST_USED_LIST", $sCurProfile)

	;//Save everything from list to file
	$hBkUpList = FileOpen($g_sScriptDir & "\ev_" & $sCurProfile, 2)
	FileWrite($hBkUpList, $sTemp)
	FileClose($hBkUpList)
	
	;//Remember default folders' states
	_DefaultItemStates_Save()
	#EndRegion
	
	;//GUI stuff
	HideAllControls(False)
	GUICtrlSetState($hBkUp3_Settings, $GUI_SHOW)
	GUICtrlSetState($cbBkUp3_Compress, $GUI_SHOW)
	GUICtrlSetState($cbBkUp3_Compress, IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "COMPRESS_DATA", $GUI_CHECKED))
	GUICtrlSetState($lBkUp3_Pwd, $GUI_SHOW)
	GUICtrlSetState($ipBkUp3_Pwd, $GUI_SHOW)
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_UNCHECKED Then
		GUICtrlSetState($ipBkUp3_PwdConfirm, $GUI_SHOW)
		GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_SHOW)
	EndIf
	GUICtrlSetState($cbBkUp3_ShowPwd, $GUI_SHOW)
	
	$sState = "B3"
EndFunc   ;==>ToBkUp3

Func _ConvertDefaultFolderPath($sFolder)
	;//Replace default folders like "Documents" with actual dir path like C:\Users\Sam\Documents, which is stored in [$i][1]
	For $i = 0 To $g_nDefaultFoldersCount - 1
		If $sFolder = $g_aDefaultItems[$i][0] Then
			$sFolder = $g_aDefaultItems[$i][1]
			ExitLoop
		EndIf
	Next
	Return $sFolder
EndFunc   ;==>_ConvertDefaultFolderPath

Func ToBkUp4()
	;//Main step in backup, compress & store files in an encrypted container
	Local $sReport, $nIndex
	$sPwd = GUICtrlRead($ipBkUp3_Pwd)
	If Not $sPwd Then
		_Metro_MsgBox($g_sProgramName, "Please enter a Password.")
		Return
	EndIf
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_UNCHECKED And GUICtrlRead($ipBkUp3_Pwd) <> GUICtrlRead($ipBkUp3_PwdConfirm) Then
		_Metro_MsgBox($g_sProgramName, "Passwords didn't match.")
		Return
	EndIf
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", GUICtrlRead($cbBkUp3_ShowPwd))
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "COMPRESS_DATA", GUICtrlRead($cbBkUp3_Compress))
	HideAllControls(True)
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim")
	GUICtrlSetState($btnNext, $GUI_SHOW)
	$sPwdHashed = _DerivePwd($sPwd)
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$lBkUp4_Status = GUICtrlCreateLabel("", 50, $aCtrlPos[1] - 120, $aCtrlPos[0], 24, BitOR(0x0200, 0x01))
	$lBkUp4_CurrentFile = GUICtrlCreateLabel("", 50, $aCtrlPos[1] - 95, $aCtrlPos[0], 20, BitOR(0x0200, 0x01))
	If GUICtrlRead($cbBkUp3_Compress) = $GUI_CHECKED Then;Use Zip encryption
		$g_LoadingText = "Compressing"
		$sReport &= "Compressing your data.." & @CRLF
		$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
		GUICtrlSetData($lBkUp4_Status, "")
		GUICtrlSetResizing($lBkUp4_Status, 8 + 32 + 128 + 768)
		GUICtrlSetResizing($lBkUp4_CurrentFile, 8 + 32 + 128 + 768);Centered
		GUICtrlSetFont($lBkUp4_Status, 11, 550, Default, "Segoe UI")
		GUICtrlSetState($btnNext, $GUI_DISABLE)
		$sTempZip = $g_sScriptDir & "\_temp.zip"
		_Zip_Create($sTempZip, 1)
		AdlibRegister("HideCompressing", 20) ;// Workaround to hide "Compressing" popup windows
		For $i = 0 To 20
			Sleep(200)
			If _FileWriteAccessible($sTempZip) = 1 Then ExitLoop
		Next
		For $i = 0 To UBound($g_aToBackupItems, 1) - 1 ;// Process all backup items read from listview
			If Mod($i, 8) = 0 Then Sleep(500) ;Take a break every 8 items processed
			$sFileToCompress = _ConvertDefaultFolderPath($g_aToBackupItems[$i])
			GUICtrlSetData($lBkUp4_CurrentFile, $sFileToCompress)
			If Not FileExists($sFileToCompress) Then
				$sReport &= $sFileToCompress & " compression failed. File does not exist." & @CRLF
				ContinueLoop				
			EndIf	
			_Zip_AddItem($sTempZip, $sFileToCompress, "", 4 + 8 + 16 + 1024 + 4096) ;// Add items to container
			If @error Then
				If @error = 9 Then
					$sReport &= $sFileToCompress & " filename duplicate, renaming.." & @CRLF
					$sTemp = "_" & Random(1, 9, 1)
					$sNewFileName = StringRegExpReplace($sFileToCompress, "^(.*\\)(.*)(\.\w+)", "$1$2" & $sTemp & "$3")
					FileRename($sFileToCompress, $sNewFileName)
					For $a = 0 To 10
						Sleep(50)
						If FileExists($sNewFileName) Then ExitLoop
					Next
					_Zip_AddItem($sTempZip, $sNewFileName, "", 4 + 8 + 16 + 1024)
					FileRename($sNewFileName, $sFileToCompress)
				Else
					$sReport &= $sFileToCompress & " compression failed. Error: " & @error & @CRLF
				EndIf
			Else
				$sReport &= $sFileToCompress & "...Done!" & @CRLF
			EndIf
		Next ;// Finished adding items to zip
		AdlibUnRegister("HideCompressing")
		$sReport &= "Encrypting data.." & @CRLF
		GUICtrlSetData($lBkUp4_CurrentFile, "")
		GUICtrlSetData($lBkUp4_Status, "")
		$g_LoadingText = "Encrypting"
		$sContainerName = $sCurProfile
		If FileExists($sContainerName) Then
			$sReport &= "Container " & $sContainerName & " already exists, overwriting.." & @CRLF
			_FileShred($g_sScriptDir & "\" & $sContainerName)
			For $i = 0 To 20
				Sleep(200)
				If _FileWriteAccessible($g_sScriptDir & "\" & $sContainerName) = 1 Then ExitLoop
			Next
		EndIf
		_Crypt_EncryptFile($sTempZip, $g_sScriptDir & "\" & $sContainerName, $hKey, $CALG_USERKEY)
		If @error Then 
			$sReport &= "Encryption error. Attempted key: " & $sPwdHashed & ". Algorithm: AES-256" & @CRLF
		Else	
			GUICtrlSetData($lBkUp4_Status, "Shredding leftovers..")
			_FileShred($sTempZip)
			$sReport &= "File saved to " & $g_sScriptDir & "\" & $sContainerName & @CRLF
		EndIf
	Else ;//No compression, only encrypt files/folders
		For $i = 0 To UBound($g_aToBackupItems, 1) - 1
			_Interface()
			$sFileToEncrypt = _ConvertDefaultFolderPath($g_aToBackupItems[$i])
			GUICtrlSetData($lBkUp4_Status, "Encrypting your data..")
			GUICtrlSetData($lBkUp4_CurrentFile, $sFileToEncrypt)
			$aTemp = StringRegExp($sFileToEncrypt, "^(.*\\)(.*)$", 3)
			If StringRegExp(FileGetAttrib($sFileToEncrypt), "D") Then
				_Crypt_EncryptFolder($sFileToEncrypt, $g_sScriptDir & "\EncryptedData\" & $aTemp[1], $hKey, $CALG_USERKEY)
			Else
				$sDestFile = _Crypt_EncryptData($aTemp[1], $hKey, $CALG_USERKEY)
				While FileExists($g_sScriptDir & "\EncryptedData\" & $sDestFile) ;//File already exists
					$nIndex = "(" & $nIndex + 1 & ")"
					$sDestFile = BinaryToString(_Crypt_EncryptData($aTemp[1] & $nIndex, $hKey, $CALG_USERKEY))
				WEnd
				_Crypt_EncryptFile($sFileToEncrypt, $g_sScriptDir & "\EncryptedData\" & $sDestFile, $hKey, $CALG_USERKEY)
			EndIf
		Next
		$sReport &= "Encryption finished. Destination folder: " & $g_sScriptDir & "\EncryptedData"
	EndIf
	_Crypt_DestroyKey($hKey)
	GUICtrlSetData($lBkUp4_CurrentFile, "")
	GUICtrlSetData($lBkUp4_Status, "")
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$eReport = GUICtrlCreateEdit($sReport, 15, 45, $aCtrlPos[0] + $aCtrlPos[2], 200, BitOR($WS_VSCROLL, $ES_READONLY))
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_SHOW)
	;_GUICtrlButton_SetImage($btnNext, "_Res\Finish.bmp")
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	GUICtrlSetState($btnNext, $GUI_ENABLE)

	$sState = "B4"
EndFunc   ;==>ToBkUp4

Func ToBkUp5()
	GUICtrlDelete($lBkUp4_CurrentFile)
	GUICtrlDelete($lBkUp4_Status)
	GUICtrlDelete($eReport)
	_GUICtrlListView_DeleteAllItems($lvBkUp2_BackupList)
	_GUICtrlButton_SetImage($btnNext, $g_sScriptDir & "\_Res\Next.bmp")
	BkUp2_SelectAll($lvBkUp2_BackupList)
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then 
		If GUICtrlRead($cbBkUp3_Compress) = $GUI_CHECKED Then
			_WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\" & $sCurProfile)
		Else
			_WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\EncryptedData")
		EndIf
	EndIf
	$sState = "B5"
	ToOriginal()
EndFunc   ;==>ToBkUp5

Func BkUp3_ShowPassword()
	$aCtrlPos = ControlGetPos($hGUI, "", $ipBkUp3_Pwd)
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_CHECKED Then
		GUICtrlSetState($ipBkUp3_PwdConfirm, $GUI_HIDE)
		GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_HIDE)
		$sTemp = GUICtrlRead($ipBkUp3_Pwd)
		GUICtrlDelete($ipBkUp3_Pwd)
		$ipBkUp3_Pwd = GUICtrlCreateInput($sTemp, $aCtrlPos[0], $aCtrlPos[1], $aCtrlPos[2], $aCtrlPos[3])
	Else
		$sTemp = GUICtrlRead($ipBkUp3_Pwd)
		GUICtrlDelete($ipBkUp3_Pwd)
		$ipBkUp3_Pwd = GUICtrlCreateInput($sTemp, $aCtrlPos[0], $aCtrlPos[1], $aCtrlPos[2], $aCtrlPos[3], 0x0020)
		GUICtrlSetState($ipBkUp3_PwdConfirm, $GUI_SHOW)
		GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_SHOW)
	EndIf
EndFunc   ;==>BkUp3_ShowPassword
#EndRegion Dealing with GUI elements (buttons, selection..)

Func BkUp2_OpenFileLocation()
	For $i = 0 To _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1
		If _GUICtrlListView_GetItemSelected($lvBkUp2_BackupList, $i) = True Then
			_WinAPI_ShellOpenFolderAndSelectItems(_ConvertDefaultFolderPath(_GUICtrlListView_GetItemText($lvBkUp2_BackupList, $i)))
		EndIf
	Next
EndFunc   ;==>BkUp2_OpenFileLocation

Func BkUp2_AddFiles()
	Local $aFilesOpenedFinal[] = [0, 0]
	$sFilesOpened = FileOpenDialog("Select files to backup", @DesktopDir, "All files (*.*)", 4)
	If Not $sFilesOpened Then Return
	$aFilesOpened = StringSplit(StringReplace($sFilesOpened, "\\", "\"), "|", 2)
	If UBound($aFilesOpened) > 1 Then
		If StringRight($aFilesOpened[0], 1) = "\" Then $aFilesOpened[0] = StringTrimRight($aFilesOpened[0], 1)
		ReDim $aFilesOpenedFinal[UBound($aFilesOpened) - 1]
		For $i = 1 To UBound($aFilesOpened) - 1
			$aFilesOpenedFinal[$i - 1] = $aFilesOpened[0] & "\" & $aFilesOpened[$i]
		Next
	Else
		$aFilesOpenedFinal = $aFilesOpened
	EndIf
	_AddFilesToLV($lvBkUp2_BackupList, $aFilesOpenedFinal)
EndFunc   ;==>BkUp2_AddFiles

Func BkUp2_AddFolder()
	$sFolderOpened = FileSelectFolder("Select a folder to backup", @DesktopDir)
	If $sFolderOpened Then
		$nIndex = _GUICtrlListView_AddItem($lvBkUp2_BackupList, $sFolderOpened, 1)
		_GUICtrlListView_AddSubItem($lvBkUp2_BackupList, $nIndex, _GetItemSizeString($sFolderOpened), $nSizeColumn)
		_GUICtrlListView_SetItemChecked($lvBkUp2_BackupList, $nIndex, True)
	EndIf
EndFunc   ;==>BkUp2_AddFolder

Func BkUp2_RemoveSelected()
	Local $count, $nItemSelected
	_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
	$nItemSelected = _GUICtrlListView_GetSelectedIndices($lvBkUp2_BackupList)
	If $nItemSelected <> "" Then; //If there's highlighted item, delete it instead of all checked items
		_GUICtrlListView_DeleteItemsSelected($lvBkUp2_BackupList)
	Else; 						  //Else delete all checked items
		For $i = 0 To _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1
			If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $count) = True Then
				_GUICtrlListView_DeleteItem($lvBkUp2_BackupList, $count)
				$count -= 1
			EndIf
			$count += 1
		Next
	EndIf
	_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
EndFunc   ;==>BkUp2_RemoveSelected

Func BkUp2_SelectAllCM() ;//Separate function for contextmenu since GUIOnEventSet() doesn't pass down parameters.
	BkUp2_SelectAll($lvBkUp2_BackupList, False, False)
EndFunc   ;==>BkUp2_SelectAllCM

Func BkUp2_SelectAll($hWnd, $bOverride = False, $bManualSelectState = True)
	;//Toggle Select-All for listview. Override: Force check state. Doesn't change ContextMenu text if $bOverride=True
	If $bOverride = False Then
		$g_bSelectAll = Not $g_bSelectAll
		$bSelectAllState = $g_bSelectAll
	Else
		$bSelectAllState = $bManualSelectState
	EndIf
	For $i = 0 To _GUICtrlListView_GetItemCount($hWnd)
		_GUICtrlListView_SetItemChecked($hWnd, $i, $bSelectAllState)
	Next
	If $bOverride = False Then
		If $g_bSelectAll = True Then
			GUICtrlSetData($cmBkUp2_SelectAll, "De-Select All")
		Else
			GUICtrlSetData($cmBkUp2_SelectAll, "Select All")
		EndIf
	EndIf
EndFunc   ;==>BkUp2_SelectAll

Func BkUp2_SelectList();Switch to a new list, load all items from respective list
	_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
	For $i = $g_nDefaultFoldersCount To _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1;//$g_nDefaultFoldersCount=End of default folders section
		_GUICtrlListView_DeleteItem($lvBkUp2_BackupList, $g_nDefaultFoldersCount)
	Next
	_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
	$sTemp = FileRead($g_sScriptDir & "\" & "ev_" & GUICtrlRead($comboBkUp2_Profile))
	$sTemp = BinaryToString(_Crypt_DecryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256))
	$aBkUpList = StringSplit($sTemp, "|", 2)
	_AddFilesToLV($lvBkUp2_BackupList, $aBkUpList, True)
EndFunc   ;==>BkUp2_SelectList

Func Restore2_Browse()
	$sTemp = FileOpenDialog("Select encrypted container file", $g_sScriptDir, "All files (*.*)")
	If Not $sTemp Then
		If MsgBox(4, $g_sProgramName, "No container file was selected, select a container folder instead?") = 6 Then $sTemp = FileSelectFolder("Select encrypted container folder", $g_sScriptDir)
	EndIf
	GUICtrlSetData($ipRestore2_ArchiveDir, $sTemp)
EndFunc   ;==>Restore2_Browse

Func _DefaultItemStates_Save()
	Local $sTemp
	For $i = 0 To $g_nDefaultFoldersCount - 1
		If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $i) = True Then
			$sTemp &= $i & ","
		EndIf
	Next
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "DEFAULT_FOLDERS_STATES", $sTemp)
EndFunc   ;==>_DefaultItemStates_Save

Func _DefaultItemStates_Load()
	$sTemp = IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "DEFAULT_FOLDERS_STATES", "")
	If $sTemp Then
		$aTemp = StringSplit($sTemp, ",", 2)
		For $i = 0 To UBound($aTemp) - 1
			If $aTemp[$i] Then _GUICtrlListView_SetItemChecked($lvBkUp2_BackupList, $aTemp[$i])
		Next
	EndIf
EndFunc   ;==>_DefaultItemStates_Load

Func _AddFilesToLV($hWnd, $aFilesList, $bFromFile = False);//$bFromFilet:set item's state & remove "::chkd" string if used in BkUp2()
	Local $sCurFile, $bCheckState = True
	If Not IsArray($aFilesList) Then Return
	For $i = 0 To UBound($aFilesList) - 1
		$sCurFile = $aFilesList[$i]
		If $sCurFile Then
			If $bFromFile = True Then;If called upon listview creation
				If StringRegExp($sCurFile, "(::chkd)") Then ;;
					$sCurFile = StringRegExpReplace($sCurFile, "(::chkd)", "")
					$bCheckState = True
				Else
					$bCheckState = False
				EndIf
			EndIf
			If FileGetAttrib($sCurFile) = "D" Then
				$nIndex = _GUICtrlListView_AddItem($hWnd, $sCurFile, 1)
				_GUICtrlListView_AddSubItem($hWnd, $nIndex, _GetItemSizeString($sCurFile), $nSizeColumn)
			Else
				$sFile = StringReplace($sCurFile, "\\", "\")
				$nIndex = _GUICtrlListView_AddItem($hWnd, $sFile)
				$sFileSize = _GetItemSizeString($sFile)
				_GUICtrlListView_AddSubItem($hWnd, $nIndex, $sFileSize, $nSizeColumn)
			EndIf
			_GUICtrlListView_SetItemChecked($hWnd, $nIndex, $bCheckState)
		EndIf
	Next
EndFunc   ;==>_AddFilesToLV

Func _AddDefaultFoldersToLV($hWnd)
	#cs
		//NOTE: Current default folders: MyDocuments,Pictures,Music,Videos, data from mainstream browsers
	#ce
	If FileExists(@UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default") Then
		;//Back up Chrome data
		If _ArraySearch($g_aDefaultItems, "Chrome History") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome History|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\History|\_Res\Chrome.bmp")
		If _ArraySearch($g_aDefaultItems, "Chrome Bookmarks") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome Bookmarks|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\Bookmarks|\_Res\Chrome.bmp")
		If _ArraySearch($g_aDefaultItems, "Chrome Passwords") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome History|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\Login Data|\_Res\Chrome.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Chromium\User Data\Default") Then
		;//Back up Chromium data
		If _ArraySearch($g_aDefaultItems, "Chromium History") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium History|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\History|\_Res\Chromium.bmp")
		If _ArraySearch($g_aDefaultItems, "Chromium Bookmarks") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium Bookmarks|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\Bookmarks|\_Res\Chromium.bmp")
		If _ArraySearch($g_aDefaultItems, "Chromium Passwords") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium Passwords|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\Login Data|\_Res\Chromium.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Mozilla\Firefox\Profiles") Then
		;//Back up Firefox data
		If _ArraySearch($g_aDefaultItems, "Firefox Data") = -1 Then _ArrayAdd($g_aDefaultItems, "Firefox Data|" & @UserProfileDir & "\AppData\Roaming\Mozilla\Firefox\Profiles|\_Res\Firefox.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable") Then
		;//Back up Opera data
		If _ArraySearch($g_aDefaultItems, "Opera Data") = -1 Then _ArrayAdd($g_aDefaultItems, "Opera Data|" & @UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable|\_Res\Opera.bmp")
	EndIf
	_GUICtrlListView_BeginUpdate($hWnd)
	For $i = 0 To UBound($g_aDefaultItems) - 1
		_GUIImageList_AddBitmap($hImage, $g_sScriptDir & $g_aDefaultItems[$i][2])
		_GUICtrlListView_AddItem($hWnd, $g_aDefaultItems[$i][0], $i + 2)
		If StringInStr(FileGetAttrib($g_aDefaultItems[$i][1]), "D") Then
			$nItemSize = _GetItemSizeString($g_aDefaultItems[$i][1])
		Else
			$nItemSize = _GetItemSizeString($g_aDefaultItems[$i][1])
		EndIf
		_GUICtrlListView_AddSubItem($hWnd, $i, $nItemSize, $nSizeColumn)
	Next
	_GUICtrlListView_SetImageList($hWnd, $hImage, 1)
	_GUICtrlListView_EndUpdate($hWnd)
	$g_nDefaultFoldersCount = UBound($g_aDefaultItems)
EndFunc   ;==>_AddDefaultFoldersToLV

Func _GetItemSizeString($sItemPath)
	Local $nItemSize
	;//Return something like "500Kb" or "23Mb"
	If Not FileExists($sItemPath) Then Return "N/A"
	If StringInStr(FileGetAttrib($sItemPath), "D") Then;//Item is a directory
		$nRawItemSize = DirGetSize($sItemPath)		
	Else;//Item is a file
		$nRawItemSize = FileGetSize($sItemPath)
	EndIf
	If $nRawItemSize / 1024 / 1024 < 1 Then;//Under 1Mb -> Return Kb
		$nItemSize = Round($nRawItemSize / 1024, 1) & "KB"
	Else
		$nItemSize = Round($nRawItemSize / 1024 / 1024, 1) & "MB"
	EndIf
	Return $nItemSize
EndFunc	

Func _AddShredderCM()
	If IsAdmin() Then
		RegWrite("HKCR\*\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\*\shell\Shred\", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")
		RegWrite("HKCR\Directory\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\Directory\shell\Shred", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")
		_Metro_MsgBox($g_sProgramName, "Right-click [Shred] context menu has been added to Windows. Files deleted with [Shred] option leave no trace and can't be recovered.")
	Else
		ShellExecute(@AutoItExe, "/add", "", "runas")
	EndIf
EndFunc   ;==>_AddShredderCM

Func _AboutCM()
	_Metro_MsgBox($g_sProgramName & " " & $g_sProgramVersion, "Gather your files in one place and encrypt them for easier and more secure backup." & @CRLF & @CRLF _
			 & "Copyright(C) 2015 T.H. evorlet@wmail.io" & @CRLF _
			 & "This software is open source and registered under GNU GPL." & @CRLF _
			 & "<https://github.com/evorlet/Ev-Secure-Backup>")
EndFunc   ;==>_AboutCM

Func _PurgeListsCM()
	Local $sTemp
	For $i = 1 To UBound($g_aProfiles) - 1
		$sTemp &= $g_aProfiles[$i] & @CRLF
	Next
	If MsgBox(4, $g_sProgramName, "Are you sure you want to delete all saved data lists?" & @CRLF & $sTemp) = 6 Then;$MB_YES=6
		For $i = 0 To UBound($g_aProfiles) - 1
			_FileShred($g_sScriptDir & "\ev_" & $g_aProfiles[$i])
		Next
		GUICtrlSetData($comboBkUp2_Profile, "")
	EndIf
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "LAST_USED_LIST", "")
	
EndFunc   ;==>_PurgeListsCM

Func _PurgeDataDirCM()
	If FileExists($g_sScriptDir & "\YourData") Then
		If MsgBox(4, $g_sProgramName, "Are you sure you want to shred your recovery folder?" & @CRLF & "Size: " & Round(DirGetSize($g_sScriptDir & "\YourData") / 1024 / 1024, 2) & " Mb") = 6 Then; $MB_YES=6
			TrayTip($g_sProgramName, "Purging..", 5, 1)
			_PurgeDir($g_sScriptDir & "\YourData")
			DirRemove($g_sScriptDir & "\YourData", 1);Remove everything
			MsgBox(64, $g_sProgramName, "Done. YourData folder has been purged from Earth and is now unrecoverable.")
		EndIf
	Else
		MsgBox(0, $g_sProgramName, $g_sScriptDir & "\YourData folder does not exist.")
	EndIf
EndFunc   ;==>_PurgeDataDirCM

Func _PurgeRecentsCM()
	Local $sLogPurged
	If MsgBox(4, $g_sProgramName, "This will clear all recently opened items/MRU/pinned items/jump lists in Windows." & @CRLF & @CRLF & "Proceed?") = 6 Then
		TrayTip($g_sProgramName, "Shredding files, this may take a while..", 4, 1)
		_PurgeDir(@AppDataDir & "\Microsoft\Windows\Recent")
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\INetCache\IE") ;Win10
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\Temporary Internet Files") ;Win7-8
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\History")
		Run("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255")
		_PurgeDir(@UserProfileDir & "\AppData\Media Cache")
		_PurgeRegCM()
	EndIf
	If MsgBox(4, $g_sProgramName, "Clear event logs (requires Admin)?") = 6 Then
		If IsAdmin() Then
			$hEventLog = _EventLog__Open("", "Application")
			_EventLog__Clear($hEventLog, "")
			_EventLog__Close($hEventLog)
			$hEventLog = _EventLog__Open("", "System")
			_EventLog__Clear($hEventLog, "")
			_EventLog__Close($hEventLog)
			$hEventLog = _EventLog__Open("", "Security")
			_EventLog__Clear($hEventLog, "")
			_EventLog__Close($hEventLog)
			RegWrite("HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management", "ClearPageFileAtShutdown", "REG_DWORD", 1)
		Else
			$sLogPurged = " except Event Logs (requires Admin)"
		EndIf
	EndIf
	MsgBox(64, $g_sProgramName, "Everything has been securely erased" & $sLogPurged & ". Please note that you might have left traces within your registry still.")
EndFunc   ;==>_PurgeRecentsCM

#Region Everything FileShredder

Func _PurgeRegCM()
	Local $iSys = StringReplace(StringRight(@OSArch, 2), '86', '')
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRULegacy")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Microsoft\Windows\CurrentVersion\Explorer\StreamMRU")
	_PurgeReg("HKEY_CURRENT_USER" & $iSys & "\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache")
EndFunc   ;==>_PurgeRegCM

Func _PurgeReg($sfRegKey)
	Local $sNextRegKey
	While 1
		$sNextRegKey = RegEnumVal($sfRegKey, 1)
		If @error Then ExitLoop
		RegWrite($sfRegKey, $sNextRegKey, "REG_DWORD", _StringRepeat("000000", 30))
		RegDelete($sfRegKey, $sNextRegKey)
	WEnd
	For $i = 1 To 4999
		$sNextRegKey = RegEnumKey($sfRegKey, $i)
		If @error Then ExitLoop
		_PurgeReg($sfRegKey & "\" & $sNextRegKey)
		RegDelete($sfRegKey)
	Next
EndFunc   ;==>_PurgeReg

Func _PurgeDir($sDataDir);Shred all files in a folder - Recursive
	$aFiles = _FileListToArray($sDataDir, '*', 1);List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			_FileShred($sDataDir & "\" & $aFiles[$a])
		Next
	EndIf
	$aFolders = _FileListToArray($sDataDir, '*', 2);List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			_PurgeDir($sDataDir & "\" & $aFolders[$b])
		Next
	EndIf
EndFunc   ;==>_PurgeDir

Func _FileShred($sFilePath)
	Local $aFilePath, $iSiz, $sChr = ""
	Local Static $sChrN = Chr(48)
	If StringRegExp(FileGetAttrib($sFilePath), "(R)") Then FileSetAttrib($sFilePath, "-R"); RegEx is faster than StringInStr()
	$aFilePath = StringRegExp($sFilePath, "^(.*\\)(.*)$", 3)
	If Not IsArray($aFilePath) Then Return
	$sChr = _StringRepeat($sChrN, 1024)
	If FileGetSize($sFilePath) <= 1024 Then
		$iSiz = 1
	Else
		$iSiz = Round(FileGetSize($sFilePath) / 1024)
	EndIf
	$iSiz = Int($iSiz)
	If @error Then Return @error
	For $a = 0 To 2 ;//Number of times to overwrite
		$hFileToShred = FileOpen($sFilePath, 18)
		For $i = 1 To $iSiz			
			FileWrite($hFileToShred, $sChr)
		Next
		FileClose($hFileToShred)
	Next
	FileRename($sFilePath, $aFilePath[0] & "0000000000000000000000000000000")
	FileRename($aFilePath[0] & "0000000000000000000000000000000", $aFilePath[0] & "0000000000000")
	FileRename($aFilePath[0] & "0000000000000", $aFilePath[0] & "00000")
	$sFilePath = $aFilePath[0] & "00000"
	FileDelete($sFilePath)
EndFunc   ;==>_FileShred
Func FileRename($FileName, $ReName)
	Local $SHFILEOPSTRUCT, $SourceStruct, $DestStruct
	Local Const $FO_RENAME = 0x0004
	Local Const $FOF_SILENT = 0x0004
	Local Const $FOF_NOCONFIRMATION = 0x0010
	Local Const $FOF_NOERRORUI = 0x0400
	Local Const $FOF_NOCONFIRMMKDIR = 0x0200
	Local Const $NULL = 0
	$tSourceStruct = _StringToStruct($FileName)
	$DestStruct = _StringToStruct($ReName)
	$SHFILEOPSTRUCT = DllStructCreate("hwnd hWnd;uint wFunc;ptr pFrom;ptr pTo;int fFlags;int fAnyOperationsAborted;ptr hNameMappings;ptr lpszProgressTitle")
	DllStructSetData($SHFILEOPSTRUCT, "hWnd", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "wFunc", $FO_RENAME)
	DllStructSetData($SHFILEOPSTRUCT, "pFrom", DllStructGetPtr($tSourceStruct))
	DllStructSetData($SHFILEOPSTRUCT, "pTo", DllStructGetPtr($DestStruct))
	DllStructSetData($SHFILEOPSTRUCT, "fFlags", BitOR($FOF_SILENT, $FOF_NOCONFIRMATION, $FOF_NOERRORUI, $FOF_NOCONFIRMMKDIR))
	DllStructSetData($SHFILEOPSTRUCT, "fAnyOperationsAborted", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "hNameMappings", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "lpszProgressTitle", $NULL)
	$acall = DllCall("shell32.dll", "int", "SHFileOperation", "ptr", DllStructGetPtr($SHFILEOPSTRUCT))
	If @error Then
		Return SetError(@error, @extended, 0)
	EndIf
	Return 1
EndFunc   ;==>FileRename
Func _StringToStruct($string)
	Local $iLen = StringLen($string)
	Local $tStruct = DllStructCreate("char[" & String($iLen + 2) & "]")
	DllStructSetData($tStruct, 1, $string)
	DllStructSetData($tStruct, 1, 0, $iLen + 1)
	DllStructSetData($tStruct, 1, 0, $iLen + 2)
	Return $tStruct
EndFunc   ;==>_StringToStruct
#EndRegion Everything FileShredder

Func _PathStringSplit($sPath)
	$aPath = StringRegExp($sPath, "^(.*\\)(.*)$", 3)
	If @error Then Return SetError(1);Not a valid path
	Return $aPath;[0]=Dir,[1]=File
EndFunc   ;==>_PathStringSplit

Func HideCompressing();Hide pop-up compressing window when archiving w/ ZIP
	If BitAND(WinGetState("Compressing"), 2) = 2 Then
		WinSetState("Compressing", "", @SW_HIDE)
	EndIf
EndFunc   ;==>HideCompressing

Func _DerivePwd($sPwdToDerive);//Make user pwd longer
	Local $sResult
	$sResult = StringTrimLeft(_Crypt_HashData($sPwdToDerive, $CALG_SHA1), 2)
	$sResult &= StringReverse($sResult)
	Return $sResult
EndFunc   ;==>_DerivePwd

Func SpecialEvents();//Handling default GUI events
	Select
		Case @GUI_CtrlId = $GUI_EVENT_CLOSE
			ExitS()
	EndSelect
EndFunc   ;==>SpecialEvents

Func ExitS()
	If FileExists($g_sScriptDir & "\_temp.zip") Then _FileShred($g_sScriptDir & "\_temp.zip");Clean up
	_Crypt_Shutdown()
	Exit
EndFunc   ;==>ExitS

;;//Loading animation, thanks to UEZ & original creators
Func PlayAnim()
	$hHBmp_BG = _GDIPlus_MultiColorLoader(300, 300, $g_LoadingText)
	$hB = GUICtrlSendMsg($cPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hHBmp_BG)
	If $hB Then _WinAPI_DeleteObject($hB)
	_WinAPI_DeleteObject($hHBmp_BG)
EndFunc   ;==>PlayAnim


Func _GDIPlus_MultiColorLoader($iW, $iH, $sText = "LOADING", $sFont = "Verdana", $bHBitmap = True)
	Local Const $hBitmap = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
	Local Const $hGfx = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx, 4 + (@OSBuild > 5999))
	_GDIPlus_GraphicsSetTextRenderingHint($hGfx, 3)
	_GDIPlus_GraphicsSetPixelOffsetMode($hGfx, $GDIP_PIXELOFFSETMODE_HIGHQUALITY)
	_GDIPlus_GraphicsClear($hGfx, 0xFFFFFFFF)

	Local $iRadius = ($iW > $iH) ? $iH * 0.6 : $iW * 0.6

	Local Const $hPath = _GDIPlus_PathCreate()
	_GDIPlus_PathAddEllipse($hPath, ($iW - ($iRadius + 24)) / 2, ($iH - ($iRadius + 24)) / 2, $iRadius + 24, $iRadius + 24)

	Local $hBrush = _GDIPlus_PathBrushCreateFromPath($hPath)
	_GDIPlus_PathBrushSetCenterColor($hBrush, 0xFFFFFFFF)
	_GDIPlus_PathBrushSetSurroundColor($hBrush, 0x08101010)
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

	Local Const $hBrush_Black = _GDIPlus_BrushCreateSolid(0xFFFFFFFF)
	_GDIPlus_GraphicsFillEllipse($hGfx, ($iW - ($iRadius + 10)) / 2, ($iH - ($iRadius + 10)) / 2, $iRadius + 10, $iRadius + 10, $hBrush_Black)

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
	_GDIPlus_GraphicsFillEllipse($hGfx_Gradient, 4, 4, $iRadius - 8, $iRadius - 8, $hBrush_Black)
	_GDIPlus_GraphicsDrawImageRect($hGfx, $hBitmap_Gradient, ($iW - $iRadius) / 2, ($iH - $iRadius) / 2, $iRadius, $iRadius)
	_GDIPlus_BrushDispose($hBrush_Gradient)
	_GDIPlus_BrushDispose($hBrush_Black)
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
EndFunc
Func _FileWriteAccessible($sFile)
	; Returns
	;            1 = Success, file is writeable and deletable
	;            0 = Failure
	; @error
	;            1 = Access Denied because of lacking access rights
	;             2 = File is set "Read Only" by attribute
	;            3 = File not found
	;            4 = Unknown Api Error, check @extended
	Local $iSuccess = 0, $iError_Extended = 0, $iError = 0, $hFile
	;$hFile = _WinAPI_CreateFileEx($sFile, $OPEN_EXISTING, $FILE_WRITE_DATA, BitOR($FILE_SHARE_DELETE, $FILE_SHARE_READ, $FILE_SHARE_WRITE), $FILE_FLAG_BACKUP_SEMANTICS)
	$hFile = _WinAPI_CreateFileEx($sFile, 3, 2, 7, 0x02000000)
	Switch _WinAPI_GetLastError()
		Case 0 ; ERROR_SUCCESS
			$iSuccess = 1
		Case 5 ; ERROR_ACCESS_DENIED
			If StringInStr(FileGetAttrib($sFile), "R", 2) Then
				$iError = 2
			Else
				$iError = 1
			EndIf
		Case 2 ; ERROR_FILE_NOT_FOUND
			$iError = 3
		Case Else
			$iError = 4
			$iError_Extended = _WinAPI_GetLastError()
	EndSwitch
	_WinAPI_CloseHandle($hFile)
	Return SetError($iError, $iError_Extended, $iSuccess)
EndFunc   ;==>_FileWriteAccessible

Func _Crypt_EncryptFolder($_sSourceFolder, $_sDestinationFolder, $_sKey, $_iAlgID)
	;//Recursively encrypt everything in a folder.
	Local $sDestFile
	If Not FileExists($_sDestinationFolder) Then DirCreate($_sDestinationFolder)
	$aFiles = _FileListToArray($_sSourceFolder, '*', 1);List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			$sDestFile = _Crypt_EncryptData($aFiles[$a], $_sKey, $_iAlgID)
			_Crypt_EncryptFile($_sSourceFolder & "\" & $aFiles[$a], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
			If @error Then 
				If @error > 530 Then 
					MsgBox(16, 'Error occurred', 'Unable to encrypt piece, possibly file in use.')
				Else
					MsgBox(16, 'Error occurred', 'Error during encryption. Code ' & @error & @CRLF & 'Your data might be lost, be advised!')
				EndIf	
			EndIf	
		Next
	EndIf
	$aFolders = _FileListToArray($_sSourceFolder, '*', 2);List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			$sDestFile = $aFolders[$b];_Crypt_EncryptData($aFolders[$b], $_sKey, $_iAlgID)
			_Crypt_EncryptFolder($_sSourceFolder & "\" & $aFolders[$b], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
		Next
	EndIf
EndFunc   ;==>_Crypt_EncryptFolder
Func _Crypt_DecryptFolder($_sSourceFolder, $_sDestinationFolder, $_sKey, $_iAlgID)
	Local $sDestFile
	If Not FileExists($_sDestinationFolder) Then DirCreate($_sDestinationFolder)
	$aFiles = _FileListToArray($_sSourceFolder, '*', 1);List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			$sDestFile = BinaryToString(_Crypt_DecryptData($aFiles[$a], $_sKey, $_iAlgID))
			_Crypt_DecryptFile($_sSourceFolder & "\" & $aFiles[$a], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
			If @error = 420 Then Return SetError(1)
		Next
	EndIf
	$aFolders = _FileListToArray($_sSourceFolder, '*', 2);List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			$sDestFile = $aFolders[$b];_Crypt_EncryptData($aFolders[$b], $_sKey, $_iAlgID)
			_Crypt_DecryptFolder($_sSourceFolder & "\" & $aFolders[$b], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
		Next
	EndIf
EndFunc   ;==>_Crypt_DecryptFolder
