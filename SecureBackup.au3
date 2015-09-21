#cs
	Ev-Secure Backup - Gathers your files in one place and encrypt them for easier and more secure backup.

	Copyright (C) 2015 T.H.
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
	- [GUI]Corrected "show password" and loading animation's position.
	- [List]Removed .txt requirement for lists, list names can't be empty, added option to purge all lists.
	- [Other]Added Purge Folders shell for FileShredder, option to Purge YourData restoration folder.
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
	//v1.4.4:
	- [List]Browser data states are now saved
	- [Other]List files are now encrypted
	//v1.4.4:
	- [GUI]Show password checkbox state is remembered, corrected git link in "About" section, redesigned the buttons
	- [Other]Added option to purge jump lists and event logs in Windows, Icon for FileShredder, FileShredder can now handle UAC-locked files
	- [Script]Replaced _FileInUse() with _FileWriteAccessible()
	TODO: (high to low priority)
	- Registry freezer
	- Option to put the files back where they originally were
	- Generate html file to assist after the restore process
	- Possibly a way to selectively backup browser data instead of saving everything (ignore cache and flashplayer data)
	- Customizable multi-layered encryption
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
#include <EventLog.au3>
#include "_Zip.au3"
;//Keywords for compilation
#pragma compile(ProductVersion, 1.4.4.0)
#pragma compile(FileVersion, 1.4.4.0)
#pragma compile(LegalCopyright, evorlet@wmail.io)
#pragma compile(ProductName, Ev-Secure Backup)
#pragma compile(FileDescription, Securely backup your data)

;//[Shred] cmd if called with parameter
If $CmdLine[0] >= 1 Then
	If StringRegExp($CmdLine[1], "\\") Then
		If StringRegExp($CmdLineRaw, "/shred") Then
			If Not StringRegExp(FileGetAttrib($CmdLine[1]), "D") Then
				If _FileWriteAccessible($CmdLine[1]) = 1 Then
					_FileShred($CmdLine[1])
				Else
					ShellExecute(@AutoItExe, $CmdLine[1] & " /shred", "", "runas")
				EndIf
			Else
				_PurgeDir($CmdLine[1])
				DirRemove($CmdLine[1], 1)
			EndIf
			Exit
		EndIf
	EndIf
EndIf

Opt("GUIOnEventMode", 1)
Opt("TrayAutoPause", 0)
Opt("TrayMenuMode", 3)
Opt('TrayOnEventMode', 1)

_GDIPlus_Startup()
Global Const $STM_SETIMAGE = 0x0172

;//Global vars declaration
;$g_aDefaultFolders: list of default folders to be added to the top when creating or loading listview ["Text to show", "DirPath", "IconPath"]
Global $g_aDefaultFolders[][] = [["Documents", @UserProfileDir & "\Documents", "\_Res\Doc.bmp"],["Pictures", @UserProfileDir & "\Pictures", "\_Res\Pic.bmp"], ["Music", @UserProfileDir & "\Music", "\_Res\Music.bmp"], ["Videos", @UserProfileDir & "\Videos", "\_Res\Video.bmp"]]
Global $g_nDefaultFoldersCount = UBound($g_aDefaultFolders); Important variable, to be used in various listview functions
Global $g_sProgramVersion = "1.4.4.0";//Current use: only in _AboutCM()
Global $g_sScriptDir = @ScriptDir, $g_aToBackupItems[0], $g_bSelectAll = False, $iPerc = 0, $g_iAnimInterval = 30, $g_aProfiles[0], $g_sProgramName = "Ev-Secure Backup"
If StringRight($g_sScriptDir, 1) = "\" Then $g_sScriptDir = StringTrimRight($g_sScriptDir, 1) ;@ScriptDir's properties may change on different OS versions

;//GUI elements declaration
Global $ipRestore2_ArchiveDir, $btnRestore2_Browse, $lRestore4_Status
Global $hBkUp2_ContextMenu, $cmBkUp2_SelectAll, $lBkUp4_CurrentFile, $lBkUp4_Status, $eReport, $btnOriginal_Backup, $btnOriginal_Restore
Global $nSizeColumn, $btnNext, $lBkUp3_Pwd, $lBkUp3_PwdConfirm, $ipBkUp3_Pwd, $ipBkUp3_PwdConfirm, $btnOriginal_Restore, $cbBkUp3_ShowPwd
Global $lvBkUp2_BackupList, $btnOriginal_Backup

;//GUI creation
$hGUI = GUICreate($g_sProgramName, 400, 500, -1, 100, BitOR(0x00020000, 0x00040000), $WS_EX_ACCEPTFILES)
$aGUIPos = WinGetPos($hGUI)

;//Create global GUI elements that will be re-used through the stages
$cPic = GUICtrlCreatePic("", 50, 0, $aGUIPos[2], $aGUIPos[2]);Loading Animation
GUICtrlSetResizing($cPic, 8 + 32 + 128 + 768)
GUICtrlSetState($cPic, $GUI_HIDE)
$btnNext = GUICtrlCreateButton("Next", 308, 435, 70, 30, $BS_BITMAP)
_GUICtrlButton_SetImage($btnNext, $g_sScriptDir & "\_Res\Next.bmp")
GUICtrlSetResizing($btnNext, 768 + 64);HCentered
$btnBack = GUICtrlCreateButton("Back", 18, 435, 70, 30, $BS_BITMAP)
_GUICtrlButton_SetImage($btnBack, $g_sScriptDir & "\_Res\Back.bmp")
GUICtrlSetResizing($btnBack, 768 + 64);HCentered
$btnOriginal_Backup = GUICtrlCreateButton("Backup", 140, 155, 120, 60, $BS_BITMAP)
_GUICtrlButton_SetImage($btnOriginal_Backup, $g_sScriptDir & "\_Res\Backup.bmp")
GUICtrlSetResizing($btnOriginal_Backup, 8 + 128 + 768);Centered

;//Create startup GUI elements (first step)
$btnOriginal_Restore = GUICtrlCreateButton("Restore", 140, 245, 120, 60, $BS_BITMAP)
_GUICtrlButton_SetImage($btnOriginal_Restore, $g_sScriptDir & "\_Res\Restore.bmp")
GUICtrlSetResizing($btnOriginal_Restore, 8 + 128 + 768);Centered
$lOriginal_Credit = GUICtrlCreateLabel("Copyright(C) 2015 T.H. evorlet@wmail.io", 195, 453)
GUICtrlSetResizing($lOriginal_Credit, 4 + 768);DockRight+ConstantSize

;//Create stage-2 Backup GUI elements
$lvBkUp2_BackupList = GUICtrlCreateListView("File", 5, 5, $aGUIPos[2] - 27, $aGUIPos[3] - 95)
_GUICtrlListView_SetExtendedListViewStyle($lvBkUp2_BackupList, BitOR($LVS_EX_FULLROWSELECT, $LVS_EX_CHECKBOXES))
$nSizeColumn = _GUICtrlListView_AddColumn($lvBkUp2_BackupList, "Size")
GUICtrlSetResizing($lvBkUp2_BackupList, 32 + 64 + 4 + 2);Centered+Poly
$hBkUp2_ContextMenu = GUICtrlCreateContextMenu($lvBkUp2_BackupList)
$cmBkUp2_OpenLocation = GUICtrlCreateMenuItem("Open file location", $hBkUp2_ContextMenu)
$cmBkUp2_AddBackupItem = GUICtrlCreateMenuItem("Add files..", $hBkUp2_ContextMenu)
$cmBkUp2_AddBackupFolder = GUICtrlCreateMenuItem("Add folder..", $hBkUp2_ContextMenu)
$cmBkUp2_RemoveBackupItem = GUICtrlCreateMenuItem("Remove from list", $hBkUp2_ContextMenu)
$cmBkUp2_SelectAll = GUICtrlCreateMenuItem("Select-All", $hBkUp2_ContextMenu)
GUICtrlSetOnEvent($cmBkUp2_OpenLocation, "BkUp2_OpenFileLocation")
GUICtrlSetOnEvent($cmBkUp2_AddBackupItem, "BkUp2_AddFiles")
GUICtrlSetOnEvent($cmBkUp2_AddBackupFolder, "BkUp2_AddFolder")
GUICtrlSetOnEvent($cmBkUp2_RemoveBackupItem, "BkUp2_RemoveSelected")
GUICtrlSetOnEvent($cmBkUp2_SelectAll, "BkUp2_SelectAllCM")

;//Listview creation
$sLastListUsed = IniRead("_Res\Settings.ini", "General", "LAST_USED_LIST", "MyNewList")
If Not FileExists("ev_" & $sLastListUsed) Then $sLastListUsed = "MyNewList"
$comboBkUp2_Profile = GUICtrlCreateCombo($sLastListUsed, 140, $aGUIPos[3] - 75, 120)
GUICtrlSetTip($comboBkUp2_Profile, "Select your list, new list will be created if list does not exist.")
$hListFileSearch = FileFindFirstFile("ev_*")
For $i = 0 To 50;Maximum 50 list files are registered.
	$sListFileFullname = FileFindNextFile($hListFileSearch)
	If @error Then ExitLoop
	$aListFileReg = StringRegExp($sListFileFullname, "ev_(.+)", 3)
	GUICtrlSetData($comboBkUp2_Profile, $aListFileReg[0])
	_ArrayAdd($g_aProfiles, $aListFileReg[0])
Next
GUICtrlSetResizing($comboBkUp2_Profile, 768 + 64 + 8);HCentered
GUICtrlSetOnEvent($comboBkUp2_Profile, "BkUp2_SelectList")

;//Create stage-3 Backup GUI elements
$lBkUp3_Pwd = GUICtrlCreateLabel("Pick your Password:", 40, 150, 200)
$ipBkUp3_Pwd = GUICtrlCreateInput("", 40, 170, $aGUIPos[2] - 100, 18, 0x0020)
$lBkUp3_PwdConfirm = GUICtrlCreateLabel("Repeat your Password:", 40, 200, 200)
$ipBkUp3_PwdConfirm = GUICtrlCreateInput("", 40, 220, $aGUIPos[2] - 100, 18, 0x0020)
$cbBkUp3_ShowPwd = GUICtrlCreateCheckbox("Show Password", 40, 250, 200)
GUICtrlSetResizing($cbBkUp3_ShowPwd, 1)
GUICtrlSetState($cbBkUp3_ShowPwd, IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", $GUI_UNCHECKED))

;//Create stage-4 Backup GUI elements
$cbBkUp4_ShowEncryptedFile = GUICtrlCreateCheckbox("Show result file", 160, $aGUIPos[3] - 77)
GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_CHECKED)

;//Create stage-2 Restore GUI elements(first in Restore)
$lRestore2_ArchiveDir = GUICtrlCreateLabel("Select container file", 40, $aGUIPos[3] - 333, 200)
$ipRestore2_ArchiveDir = GUICtrlCreateInput("", 40, $aGUIPos[3] - 313, $aGUIPos[2] - 125, 18)
GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_DROPACCEPTED)
$btnRestore2_Browse = GUICtrlCreateButton("...", $aGUIPos[2] - 82, $aGUIPos[3] - 314, 20, 20, $BS_BITMAP)
_GUICtrlButton_SetImage($btnRestore2_Browse, $g_sScriptDir & "\_Res\Browse.bmp")

;//Create stage-3 Restore GUI elements
$lRestore3_Pwd = GUICtrlCreateLabel("Enter the Password used during backup process", 40, $aGUIPos[3] - 333)
$ipRestore3_Pwd = GUICtrlCreateInput("", 40, $aGUIPos[3] - 313, $aGUIPos[2] - 103, 18)
GUICtrlSetOnEvent($cbBkUp3_ShowPwd, "BkUp3_ShowPassword")

;//Icons for BkUp2_ListView
$hImage = _GUIImageList_Create(16, 16)
_GUIImageList_AddBitmap($hImage, $g_sScriptDir & "\_Res\File.bmp")
_GUIImageList_AddBitmap($hImage, $g_sScriptDir & "\_Res\Folder.bmp")

_GUICtrlListView_SetImageList($lvBkUp2_BackupList, $hImage, 1)

GUISetOnEvent($GUI_EVENT_CLOSE, "SpecialEvents")
;#End of GUI creation

;//Tray stuff
$hTrayAddShred = TrayCreateItem("Add File-Shredder")
TrayItemSetOnEvent(-1, "_AddShredderCM")
$hTrayMenuPurge = TrayCreateMenu("Purge")
$hTrayPurgeDir = TrayCreateItem("YourData folder", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeDataDirCM")
$hTrayPurgeLists = TrayCreateItem("All data lists", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeListsCM")
$hTrayPurgeLists = TrayCreateItem("All Windows traces", $hTrayMenuPurge)
TrayItemSetOnEvent(-1, "_PurgeRecentsCM")
$hTrayAbout = TrayCreateItem("About")
TrayItemSetOnEvent(-1, "_AboutCM")
TrayCreateItem("")
$hTrayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitS")

;//Initialize
ToOriginal()
_WinAPI_SetFocus(ControlGetHandle($hGUI, "", $lOriginal_Credit)) ;//Avoid init button focus workaround
GUISetState(@SW_SHOWNOACTIVATE, $hGUI)

;//Timer for Loading Animation
DllCall("user32.dll", "int", "SetTimer", "hwnd", $hGUI, "int", 0, "int", $g_iAnimInterval, "int", 0)

While 1
	Sleep(2000)
WEnd

#Region Dealing with GUI elements (buttons, selection..)
Func HideAllControls($bHideNextBtn = True)
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	GUICtrlSetState($lBkUp3_Pwd, $GUI_HIDE)
	GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_HIDE)
	GUICtrlSetState($ipBkUp3_Pwd, $GUI_HIDE)
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
	GUISetBkColor(0xffffff, $hGUI)
	
	GUICtrlSetOnEvent($btnOriginal_Backup, "ToBkUp2")
	GUICtrlSetOnEvent($btnOriginal_Restore, "Restore2")
EndFunc   ;==>ToOriginal

Func Restore2()
	HideAllControls(False)
	GUICtrlSetState($lRestore2_ArchiveDir, $GUI_SHOW)
	GUICtrlSetState($ipRestore2_ArchiveDir, $GUI_SHOW)
	GUICtrlSetState($btnRestore2_Browse, $GUI_SHOW)
	GUICtrlSetOnEvent($btnRestore2_Browse, "Restore2_Browse")
	
	GUICtrlSetOnEvent($btnNext, "Restore3")
	GUICtrlSetOnEvent($btnBack, "ToOriginal")
EndFunc   ;==>Restore2

Func Restore3()
	If Not StringRegExp(GUICtrlRead($ipRestore2_ArchiveDir), "^(.*\\)(.*)") Then
		MsgBox(64, $g_sProgramName, "Please select a container file to restore from.")
		Return
	EndIf
	HideAllControls(False)
	GUICtrlSetState($lRestore3_Pwd, $GUI_SHOW)
	GUICtrlSetState($ipRestore3_Pwd, $GUI_SHOW)
	GUICtrlSetOnEvent($ipRestore3_Pwd, "Restore4")
	
	GUICtrlSetOnEvent($btnNext, "Restore4")
	GUICtrlSetOnEvent($btnBack, "Restore2")
EndFunc   ;==>Restore3

Func Restore4()
	;//Main step in restoration, retrieve files from encrypted container
	Local $sReport
	If Not GUICtrlRead($ipRestore3_Pwd) Then
		MsgBox(64, $g_sProgramName, "Please enter a Password.")
		Return
	EndIf
	
	DirCreate($g_sScriptDir & "\YourData")
	$sTempZip = $g_sScriptDir & "\_temp.zip"
	$sTempDir = $g_sScriptDir & "\YourData"
	$sPwd = GUICtrlRead($ipRestore3_Pwd)
	$sPwdHashed = _DerivePwd($sPwd)
	
	HideAllControls(False)
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim");//Show and play loading animation
	GUICtrlSetState($btnBack, $GUI_HIDE)
	GUICtrlSetState($btnNext, $GUI_DISABLE)
	$aGUIPos = WinGetPos($hGUI)
	
	;//Decrypt
	$sReport &= "Decrypting container.." & @CRLF
	$lRestore4_Status = GUICtrlCreateLabel("Decrypting container..", ($aGUIPos[2] / 2) - 145, $aGUIPos[3] - 213, 280, 30, BitOR(0x0200, 0x01))
	GUICtrlSetFont($lRestore4_Status, 11, 550, Default, "Segoe UI")
	GUICtrlSetResizing($lRestore4_Status, 8 + 32 + 128 + 768)
	If FileExists("_temp.zip") Then _FileShred($sTempZip)
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)
	_Crypt_DecryptFile(StringReplace(GUICtrlRead($ipRestore2_ArchiveDir), "\\", "\"), $g_sScriptDir & "\_temp.zip", $hKey, $CALG_USERKEY)
	$iError = @error
	_Crypt_DestroyKey($hKey)
	
	If Not $iError Then
		For $i = 0 To 30
			If FileExists("_temp.zip") Then ExitLoop
			Sleep(200)
		Next
		
		;//Extract data
		GUICtrlSetData($lRestore4_Status, "Extracting compressed data..")
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
	$sReport &= "Restoration finished." & @CRLF
	
	;//Remaining GUI stuff
	GUICtrlSetData($lRestore4_Status, "")
	$eReport = GUICtrlCreateEdit($sReport, 10, 10, $aGUIPos[2] - 38, 200, BitOR($WS_VSCROLL, $ES_READONLY));//This control is deleted in step 5
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_SHOW)
	GUICtrlSetState($btnNext, $GUI_ENABLE)
	_GUICtrlButton_SetImage($btnNext, "_Res\Finish.bmp")
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	
	GUICtrlSetOnEvent($btnNext, "Restore5")
EndFunc   ;==>Restore4

Func Restore5()
	GUICtrlDelete($eReport)
	_GUICtrlButton_SetImage($btnNext, $g_sScriptDir & "\_Res\Next.bmp")
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then _WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\YourData")
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
		_DefaultFoldersStates_Load()
		_GUICtrlListView_SetColumnWidth($lvBkUp2_BackupList, 0, $aGUIPos[2] - 105)
		_GUICtrlListView_SetColumnWidth($lvBkUp2_BackupList, $nSizeColumn, 70)
		_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
	EndIf
	
	GUICtrlSetOnEvent($btnNext, "ToBkUp3")
	GUICtrlSetOnEvent($btnBack, "ToOriginal")
EndFunc   ;==>ToBkUp2

Func ToBkUp3()
	Local $a, $sTemp, $aAccelKeys, $sCurProfile = GUICtrlRead($comboBkUp2_Profile), $aAllItems[0], $sRegExPattern
	ReDim $g_aToBackupItems[0]
	
	If Not $sCurProfile Then
		MsgBox(16, $g_sProgramName, "List name must not be empty")
		ControlFocus($hGUI, "", $comboBkUp2_Profile)
		Return
	EndIf
	
	;//Add new item to profile combo box if list doesn't exist
	_ArraySearch($g_aProfiles, $sCurProfile)
	If @error Then 
		GUICtrlSetData($comboBkUp2_Profile, $sCurProfile)
		_ArrayAdd($g_aProfiles, $sCurProFile)
	EndIf	
	
	;//Get ready to save to list file
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
		MsgBox(64, $g_sProgramName, "No files were selected for backup.")
		Return
	EndIf
	
	;//Generate [raw] string to save to list file, default folders are removed
	For $i = 0 To UBound($aAllItems) - 1
		$sTemp &= $aAllItems[$i] & "|"
	Next
	;//Remove default folders from list file
	For $i = 0 To UBound($g_aDefaultFolders) - 1
		$sRegExPattern &= $g_aDefaultFolders[$i][0] & "|"
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
	_DefaultFoldersStates_Save()
	
	;//GUI stuff
	HideAllControls(False)
	GUICtrlSetState($lBkUp3_Pwd, $GUI_SHOW)
	GUICtrlSetState($ipBkUp3_Pwd, $GUI_SHOW)
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_UNCHECKED Then
		GUICtrlSetState($ipBkUp3_PwdConfirm, $GUI_SHOW)
		GUICtrlSetState($lBkUp3_PwdConfirm, $GUI_SHOW)
	EndIf
	GUICtrlSetState($cbBkUp3_ShowPwd, $GUI_SHOW)
	GUICtrlSetOnEvent($ipBkUp3_Pwd, "ToBkUp4")
	
	GUICtrlSetOnEvent($btnNext, "ToBkUp4")
	GUICtrlSetOnEvent($btnBack, "ToBkUp2")
EndFunc   ;==>ToBkUp3

Func _ConvertDefaultFolderPath($sFolder)
	;//Replace default folders like "Documents" with actual dir path stored in [$i][1]
	For $i = 0 To $g_nDefaultFoldersCount - 1
		If $sFolder = $g_aDefaultFolders[$i][0] Then
			$sFolder = $g_aDefaultFolders[$i][1] 
			ExitLoop
		EndIf
	Next
	Return $sFolder
EndFunc	

Func ToBkUp4()
	;//Main step in backup, compress & store files in an encrypted container
	Local $sReport
	$sPwd = GUICtrlRead($ipBkUp3_Pwd)
	If Not $sPwd Then
		MsgBox(64, $g_sProgramName, "Please enter a Password.")
		Return
	EndIf
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_UNCHECKED And GUICtrlRead($ipBkUp3_Pwd) <> GUICtrlRead($ipBkUp3_PwdConfirm) Then
		MsgBox(64, $g_sProgramName, "Passwords didn't match.")
		Return
	EndIf
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", GUICtrlRead($cbBkUp3_ShowPwd))
	HideAllControls(True)
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim")
	GUICtrlSetState($btnNext, $GUI_SHOW)
	$sPwdHashed = _DerivePwd($sPwd)
	$sReport &= "Compressing your data.." & @CRLF
	$aCtrlPos = ControlGetPos($hGUI, "", $cPic)	
	$lBkUp4_Status = GUICtrlCreateLabel("Compressing your data..", ($aCtrlPos[2] / 2) - 145, $aCtrlPos[3] - 110, 280, 24, BitOR(0x0200, 0x01))
	$lBkUp4_CurrentFile = GUICtrlCreateLabel("", ($aCtrlPos[2] / 2) - 150, $aCtrlPos[3] - 80, 280, 20, BitOR(0x0200, 0x01))
	GUICtrlSetResizing($lBkUp4_Status, 8 + 32 + 128 + 768)
	GUICtrlSetResizing($lBkUp4_CurrentFile, 8 + 32 + 128 + 768);Centered
	GUICtrlSetFont($lBkUp4_Status, 11, 550, Default, "Segoe UI")
	GUICtrlSetState($btnNext, $GUI_DISABLE)
	$sTempZip = $g_sScriptDir & "\_temp.zip"
	_Zip_Create($sTempZip, 1)
	AdlibRegister("HideCompressing", 20)
	For $i = 0 To 20
		Sleep(200)
		If _FileWriteAccessible($sTempZip) = 1 Then ExitLoop
	Next
	For $i = 0 To UBound($g_aToBackupItems, 1) - 1
		If Mod($i, 8) = 0 Then Sleep(1500);Take a break every 8 items processed
		$sFileToCompress = _ConvertDefaultFolderPath($g_aToBackupItems[$i])
		GUICtrlSetData($lBkUp4_CurrentFile, $sFileToCompress)
		_Zip_AddItem($sTempZip, $sFileToCompress, "", 4 + 8 + 16 + 1024 + 4096)
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
			$sReport &= $sFileToCompress & " successfully compressed." & @CRLF
		EndIf
	Next
	AdlibUnRegister("HideCompressing")
	GUICtrlSetData($lBkUp4_CurrentFile, "")
	$sReport &= "Encrypting data.." & @CRLF
	GUICtrlSetData($lBkUp4_Status, "Encrypting your data..")
	If FileExists("EncryptedContainer") Then
		$sReport &= "EncryptedContainer already exists, overwriting.." & @CRLF
		_FileShred($g_sScriptDir & "\EncryptedContainer")
		For $i = 0 To 20
			Sleep(200)
			If _FileWriteAccessible($g_sScriptDir & "\EncryptedContainer") = 1 Then ExitLoop
		Next
	EndIf
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)
	_Crypt_EncryptFile($sTempZip, $g_sScriptDir & "\EncryptedContainer", $hKey, $CALG_USERKEY)
	$iError = @error
	_Crypt_DestroyKey($hKey)
	If $iError Then $sReport &= "Encryption error. Attempted key: " & $sPwdHashed & ". Algorithm: AES-256" & @CRLF
	GUICtrlSetData($lBkUp4_Status, "Shredding leftovers..")
	_FileShred($sTempZip)
	If $iError Then $sReport &= "Error shredding leftover." & @CRLF
	$aGUIPos = WinGetPos($hGUI)
	If Not $sReport Then $sReport = "No errors were encountered." & @CRLF
	$sReport &= "File saved to " & $g_sScriptDir & "\EncryptedContainer" & @CRLF
	GUICtrlSetData($lBkUp4_Status, "")
	$eReport = GUICtrlCreateEdit($sReport, 10, 10, $aGUIPos[2] - 38, 200, BitOR($WS_VSCROLL, $ES_READONLY))
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_SHOW)
	_GUICtrlButton_SetImage($btnNext, "_Res\Finish.bmp")
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	GUICtrlSetState($btnNext, $GUI_ENABLE)

	GUICtrlSetOnEvent($btnNext, "ToBkUp5")
EndFunc   ;==>ToBkUp4

Func ToBkUp5()
	GUICtrlDelete($lBkUp4_CurrentFile)
	GUICtrlDelete($lBkUp4_Status)
	GUICtrlDelete($eReport)
	_GUICtrlListView_DeleteAllItems($lvBkUp2_BackupList)
	_GUICtrlButton_SetImage($btnNext, $g_sScriptDir & "\_Res\Next.bmp")
	BkUp2_SelectAll($lvBkUp2_BackupList)
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then _WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\EncryptedContainer")
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
EndFunc	

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
		_GUICtrlListView_AddSubItem($lvBkUp2_BackupList, $nIndex, Round(DirGetSize($sFolderOpened) / 1024 / 1024, 1) & "MB", $nSizeColumn)
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
	$sTemp = FileOpenDialog("Select encrypted container", $g_sScriptDir, "All files (*.*)")
	GUICtrlSetData($ipRestore2_ArchiveDir, $sTemp)
EndFunc   ;==>Restore2_Browse

Func _DerivePwd($sPwdToDerive);//Make user pwd longer
	Local $sResult
	$sResult = StringTrimLeft(_Crypt_HashData($sPwdToDerive, $CALG_SHA1), 2) & StringTrimLeft(_Crypt_HashData(StringReverse($sPwdToDerive), $CALG_SHA1), 2) & StringTrimLeft(_Crypt_HashData($sPwdToDerive, $CALG_MD5), 2)
	$sResult &= StringReverse($sResult)
	Return $sResult
EndFunc   ;==>_DerivePwd

Func SpecialEvents();//Handling default GUI events
	Select
		Case @GUI_CtrlId = $GUI_EVENT_CLOSE
			ExitS()
	EndSelect
EndFunc   ;==>SpecialEvents

Func _DefaultFoldersStates_Save()
	Local $sTemp
	For $i = 0 To $g_nDefaultFoldersCount - 1
		If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $i) = True Then
			$sTemp &= $i & ","
		EndIf
	Next
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "DEFAULT_FOLDERS_STATES", $sTemp)
EndFunc   ;==>_DefaultFoldersStates_Save

Func _DefaultFoldersStates_Load()
	$sTemp = IniRead($g_sScriptDir & "\_Res\Settings.ini", "General", "DEFAULT_FOLDERS_STATES", "")
	If $sTemp Then
		$aTemp = StringSplit($sTemp, ",", 2)
		For $i = 0 To UBound($aTemp) - 1
			If $aTemp[$i] Then _GUICtrlListView_SetItemChecked($lvBkUp2_BackupList, $aTemp[$i])
		Next
	EndIf
EndFunc   ;==>_DefaultFoldersStates_Load

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
				_GUICtrlListView_AddSubItem($hWnd, $nIndex, Round(DirGetSize($sCurFile) / 1024 / 1024, 1) & "MB", $nSizeColumn)
			Else
				$sFile = StringReplace($sCurFile, "\\", "\")
				$nIndex = _GUICtrlListView_AddItem($hWnd, $sFile)
				$sFileSize = Round(FileGetSize($sFile) / 1024 / 1024, 1) & "MB"
				If $sFileSize = 0 Then $sFileSize = Round(FileGetSize($sFile) / 1024, 1) & "KB"
				_GUICtrlListView_AddSubItem($hWnd, $nIndex, $sFileSize, $nSizeColumn)
			EndIf
			_GUICtrlListView_SetItemChecked($hWnd, $nIndex, $bCheckState)
		EndIf
	Next
EndFunc   ;==>_AddFilesToLV

Func _AddDefaultFoldersToLV($hWnd)
	#cs
		Current default folders: MyDocuments,Pictures,Music,Videos
		//TODO: Add bookmarks & history from mainstream browsers
		Default Browser regkey: HKEY_CURRENT_USER\Software\Clients\StartMenuInternet, HKEY_CURRENT_USER\Software\Clients\Google\Chrome for GChrome
		+ Chromium & Chrome have the same backup dir (%APPDATA%\Local\*Google\Chrome|Chromium*\User Data\Default)
		+ Firefox: %APPDATA%\Mozilla\Firefox\Profiles\
	#ce
	If FileExists(@UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default") Then 
		;//Back up Chrome data
		_ArrayAdd($g_aDefaultFolders, "Chrome Data|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default|\_Res\Chrome.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Chromium\User Data\Default") Then 
		;//Back up Chromium data
		_ArrayAdd($g_aDefaultFolders, "Chromium Data|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default|\_Res\Chromium.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Mozilla\Firefox\Profiles") Then 
		;//Back up Firefox data
		_ArrayAdd($g_aDefaultFolders, "Firefox Data|" & @UserProfileDir & "\AppData\Roaming\Mozilla\Firefox\Profiles|\_Res\Firefox.bmp")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable") Then 
		;//Back up Opera data
		_ArrayAdd($g_aDefaultFolders, "Firefox Data|" & @UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable|\_Res\Opera.bmp")
	EndIf
	_GUICtrlListView_BeginUpdate($hWnd)
	For $i = 0 To UBound($g_aDefaultFolders) - 1
		_GUIImageList_AddBitmap($hImage, $g_sScriptDir & $g_aDefaultFolders[$i][2])
		_GUICtrlListView_AddItem($hWnd, $g_aDefaultFolders[$i][0], $i+2)
		_GUICtrlListView_AddSubItem($hWnd, $i, Round(DirGetSize($g_aDefaultFolders[$i][1]) / 1024 / 1024, 1) & "MB", $nSizeColumn)
	Next
	_GUICtrlListView_SetImageList($hWnd, $hImage, 1)
	_GUICtrlListView_EndUpdate($hWnd)
	$g_nDefaultFoldersCount = UBound($g_aDefaultFolders)
EndFunc   ;==>_AddDefaultFoldersToLV

Func _AddShredderCM()
	If IsAdmin() Then
		RegWrite("HKCR\*\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\*\shell\Shred\", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")		
		RegWrite("HKCR\Directory\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\Directory\shell\Shred", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")
		MsgBox(64, $g_sProgramName, "Right-click [Shred] context menu added to Windows. Files deleted with [Shred] option leave no trace and can't be recovered.")
	Else
		MsgBox(16, $g_sProgramName, "Administrative privileges required.")
	EndIf
EndFunc   ;==>_AddShredderCM

Func _AboutCM()
	MsgBox(64, $g_sProgramName & " " & $g_sProgramVersion, "Ev-Secure Backup gathers your files in one place and encrypt them for easier and more secure backup." & @CRLF & @CRLF _
			 & "Copyright(C) 2015 T.H. evorlet@wmail.io" & @CRLF _
			 & "This software is open source and registered under GNU GPL license." & @CRLF _
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
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General","LAST_USED_LIST", "")
	
EndFunc   ;==>_PurgeListsCM

Func _PurgeDataDirCM()
	If FileExists($g_sScriptDir & "\YourData") Then
		If MsgBox(4, $g_sProgramName, "Are you sure you want to shred your recovery folder?" & @CRLF & "Size: " &  Round(DirGetSize($g_sScriptDir & "\YourData") / 1024 / 1024, 2) & " Mb") = 6 Then; $MB_YES=6
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
	If MsgBox(4, $g_sProgramName, "This will clear all recently opened items/MRU/jump lists in Windows." & @CRLF & "Proceed?") = 6 Then
		_PurgeDir(@AppDataDir & "\Microsoft\Windows\Recent")
		If MsgBox(4, $g_sProgramName, "Clear event logs?") = 6 Then
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
				MsgBox(64, $g_sProgramName, "Unable to clear event logs. Administrative privileges required.")
			EndIf	
		EndIf
	EndIf
EndFunc	

#Region Everything FileShredder

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
	FileRename($sFilePath, $aFilePath[0] & "0000000000000000000000000000000")
	FileRename($aFilePath[0] & "0000000000000000000000000000000", $aFilePath[0] & "0000000000000")
	FileRename($aFilePath[0] & "0000000000000", $aFilePath[0] & "00000")
	$sFilePath = $aFilePath[0] & "00000"
	$hFileToShred = FileOpen($sFilePath, 18)
	If @error Then Return @error
	$sChr = _StringRepeat($sChrN, 1024)
	If FileGetSize($sFilePath) <= 1024 Then
		$iSiz = 1
	Else
		$iSiz = Round(FileGetSize($sFilePath) / 1024)
	EndIf
	$iSiz = Int($iSiz)
	For $a = 0 To 2
		For $i = 1 To $iSiz
			FileWrite($hFileToShred, $sChr)
		Next
	Next
	FileClose($hFileToShred)
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

Func ExitS()
	If FileExists($g_sScriptDir & "\_temp.zip") Then _FileShred($g_sScriptDir & "\_temp.zip");Clean up
	Exit
EndFunc   ;==>ExitS

;;//Loading animation, thanks to UEZ & original creators
Func PlayAnim()
	$hHBmp_BG = _GDIPlus_SpinningAndGlowing($iPerc, 300, 300)
	$hB = GUICtrlSendMsg($cPic, $STM_SETIMAGE, $IMAGE_BITMAP, $hHBmp_BG)
	If $hB Then _WinAPI_DeleteObject($hB)
	_WinAPI_DeleteObject($hHBmp_BG)
	$iPerc += 4
EndFunc   ;==>PlayAnim
Func _GDIPlus_SpinningAndGlowing($fProgress, $iW, $iH, $iColor = 0x00A2E8, $fSize = 80, $iCnt = 24, $fDM = 24, $fScale = 3, $iGlowCnt = 6)
	Local $hBmp = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
	Local $hGfx = _GDIPlus_ImageGetGraphicsContext($hBmp)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx, 2)
	_GDIPlus_GraphicsClear($hGfx, 0xFFFFFFFF)
	Local $iOff = $iCnt * Mod($fProgress, 100) / 100
	Local $fCX = $iW * 0.5
	Local $fCY = $iH * 0.5
	Local $hPath = _GDIPlus_PathCreate()
	_GDIPlus_PathAddEllipse($hPath, -$fDM * 0.5, -$fDM * 0.5, $fDM, $fDM)
	Local $hBrush = _GDIPlus_PathBrushCreateFromPath($hPath)
	_GDIPlus_PathBrushSetCenterColor($hBrush, $iColor)
	_GDIPlus_PathBrushSetSurroundColor($hBrush, 0)
	_GDIPlus_PathBrushSetGammaCorrection($hBrush, True)
	Local $aBlend[5][2] = [[4]]
	$aBlend[1][0] = 0
	$aBlend[1][1] = 0
	$aBlend[2][0] = BitOR(BitAND($iColor, 0x00FFFFFF), 0x1A000000)
	$aBlend[2][1] = 0.78
	$aBlend[3][0] = BitOR(BitAND($iColor, 0x00FFFFFF), 0xFF000000)
	$aBlend[3][1] = 0.88
	$aBlend[4][0] = 0xFFFFFFFF
	$aBlend[4][1] = 1
	_GDIPlus_PathBrushSetPresetBlend($hBrush, $aBlend)
	Local $fS
	Local Const $cPI = ATan(1) * 4
	For $i = 0 To $iCnt - 1
		$fS = Sin($cPI * Log(1.4 + Mod($iOff + $i, $iCnt) / $iGlowCnt) / Log(4))
		If $fS < 0 Then $fS = 0
		$fS = 1 + $fScale * $fS
		_GDIPlus_GraphicsResetTransform($hGfx)
		_GDIPlus_GraphicsScaleTransform($hGfx, $fS, $fS, True)
		_GDIPlus_GraphicsTranslateTransform($hGfx, -$fSize, 0, True)
		_GDIPlus_GraphicsScaleTransform($hGfx, 1.2, 1, False)
		_GDIPlus_GraphicsRotateTransform($hGfx, -360 / $iCnt * $i, True)
		_GDIPlus_GraphicsTranslateTransform($hGfx, $fCX, $fCY, True)
		_GDIPlus_GraphicsFillPath($hGfx, $hPath, $hBrush)
	Next
	_GDIPlus_BrushDispose($hBrush)
	_GDIPlus_PathDispose($hPath)
	Local $hHBITMAP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBmp)
	_GDIPlus_GraphicsDispose($hGfx)
	_GDIPlus_BitmapDispose($hBmp)
	Return $hHBITMAP
EndFunc   ;==>_GDIPlus_SpinningAndGlowing
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
