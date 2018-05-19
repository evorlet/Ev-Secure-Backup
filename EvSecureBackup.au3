#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=..\Icons\1442169766_MB__LOCK.ico
#AutoIt3Wrapper_Outfile=..\..\Soft\Ev-SBackup\Ev-SBackup.exe
#AutoIt3Wrapper_Run_Tidy=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

;//Keywords for compilation
#pragma compile(ProductVersion, 1.9.4)
#pragma compile(FileVersion, 1.9.4)
#pragma compile(UPX, False)
#pragma compile(LegalCopyright, sandwichdoge@gmail.com)
#pragma compile(ProductName, Ev-Secure Backup)
#pragma compile(FileDescription, Securely backup your data)

#include-once
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
#include "BinaryMerge.au3"
#include "EvS_lib\Init.au3"
#include "EvS_lib\Cmd.au3"
#include "EvS_lib\FolderEncryption_Legacy.au3"
#include "EvS_lib\FileShred.au3"
#include "EvS_lib\FileOps.au3" ;//rename & check if accessible
#include "EvS_lib\UI\Main_UI.au3"
#include "EvS_lib\UI\BackUp_UI.au3"
#include "EvS_lib\UI\Restore_UI.au3"
#include "EvS_lib\TrayAndContextMenu.au3"

;Opt("MustDeclareVars", 1)

;_GDIPlus_Startup()
_Crypt_Startup()

;$g_aDefaultItems: list of default folders to be added to the top when creating or loading listview ["Text to show", "DirPath", "IconPath"]
If StringRight($g_sScriptDir, 1) = "\" Then $g_sScriptDir = StringTrimRight($g_sScriptDir, 1) ;@ScriptDir's properties may change on different OS versions
Global $g_aDefaultItems[][] = [["Documents", @UserProfileDir & "\Documents", "\_Res\Doc.ico"], ["Pictures", @UserProfileDir & "\Pictures", "\_Res\Pic.ico"], ["Music", @UserProfileDir & "\Music", "\_Res\Music.ico"], ["Videos", @UserProfileDir & "\Videos", "\_Res\Video.ico"]]
Global $g_nDefaultFoldersCount = UBound($g_aDefaultItems) ; Important variable, to be used in various listview functions
Global $g_sProgramVersion = "1.9.4"
Global $g_aToBackupItems[0], $g_aProfiles[0], $sState

;//Initialize
ToOriginal() ;//Set UI to original state
GUISetState(@SW_SHOW)

;//Timer for Loading Animation
While 1
	_Interface()
WEnd


Func _AddFilesToLV($hWnd, $aFilesList, $bFromFile = False) ;//$bFromFilet:set item's state & remove "::chkd" from ev_ file. if True = func is called internally
	Local $aLVItems[0]
	Local $sCurFile, $bCheckState = True
	If Not IsArray($aFilesList) Then Return
	For $i = 0 To _GUICtrlListView_GetItemCount($hWnd) - 1
		$sBackupItem = _GUICtrlListView_GetItemText($hWnd, $i)
		_ArrayAdd($aLVItems, $sBackupItem)
	Next
	For $i = 0 To UBound($aFilesList) - 1
		$sCurFile = $aFilesList[$i]
		;//Check duplication, duplicated items will not be added.
		For $j = $g_nDefaultFoldersCount To UBound($aLVItems) - 1
			If $sCurFile = $aLVItems[$j] Then
				_GUICtrlListView_SetItemSelected($hWnd, $j)
				ContinueLoop (2)
			EndIf
		Next
		
		If $sCurFile Then
			If $bFromFile = True Then ;If called upon listview creation
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

Func _GetItemSizeString($sItemPath)
	Local $nItemSize
	;//Convert from bytes, return something like "500KB" or "23MB"
	If Not FileExists($sItemPath) Then Return "N/A"
	If StringInStr(FileGetAttrib($sItemPath), "D") Then ;//Item is a directory
		$nRawItemSize = DirGetSize($sItemPath)
	Else ;//Item is a file
		$nRawItemSize = FileGetSize($sItemPath)
	EndIf
	If $nRawItemSize / 1024 / 1024 < 1 Then ;//Under 1Mb -> Return Kb
		$nItemSize = Round($nRawItemSize / 1024, 1) & "KB"
	ElseIf $nRawItemSize / 1024 / 1024 / 1024 < 1 Then
		$nItemSize = Round($nRawItemSize / 1024 / 1024, 1) & "MB"
	Else
		$nItemSize = Round($nRawItemSize / 1024 / 1024 / 1024, 1) & "GB"
	EndIf
	Return $nItemSize
EndFunc   ;==>_GetItemSizeString

Func ExitS()
	If FileExists($g_sScriptDir & "\_temp.zip") Then _FileShred($g_sScriptDir & "\_temp.zip") ;Clean up
	_Crypt_Shutdown()
	_GDIPlus_Shutdown()
	Exit
EndFunc   ;==>ExitS
