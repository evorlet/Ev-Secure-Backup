;//Tray creation
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
TrayCreateItem("")
$hTrayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent(-1, "ExitS")


Func _AddShredderCM()
	;//Add "Shred" option to Windows context menus.
	If IsAdmin() Then
		RegWrite("HKCR\*\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\*\shell\Shred\", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")
		RegWrite("HKCR\Directory\shell\Shred\command", "", "REG_SZ", StringReplace(@ScriptFullPath, "\", "\\") & ' "%1" "/shred"')
		RegWrite("HKCR\Directory\shell\Shred", "Icon", "REG_EXPAND_SZ", $g_sScriptDir & "\_Res\1442169766_MB__LOCK.ico")
		_Metro_MsgBox(0, $g_sProgramName, "Right-click [Shred] context menu has been added to Windows. Files deleted with [Shred] option leave no trace and can't be recovered.")
	Else
		ShellExecute(@AutoItExe, "/add", "", "runas")
	EndIf
EndFunc   ;==>_AddShredderCM

Func _AboutCM()
	_Metro_MsgBox(0, $g_sProgramName & " " & $g_sProgramVersion, "Gather your files in one place and encrypt them for easier and more secure backup." & @CRLF & @CRLF _
			 & "2015 T.H. sandwichdoge@gmail.com" & @CRLF _
			 & "This software is open source and registered under GNU GPL." & @CRLF _
			 & "<https://github.com/sandwichdoge/Ev-Secure-Backup>")
EndFunc   ;==>_AboutCM

Func _PurgeListsCM()
	Local $sTemp
	For $i = 1 To UBound($g_aProfiles) - 1
		$sTemp &= $g_aProfiles[$i] & @CRLF
	Next
	If _Metro_MsgBox(4, $g_sProgramName, "Are you sure you want to delete all saved data lists?" & @CRLF & $sTemp) = "Yes" Then ;$MB_YES=6
		For $i = 0 To UBound($g_aProfiles) - 1
			_FileShred($g_sScriptDir & "\ev_" & $g_aProfiles[$i])
		Next
		GUICtrlSetData($comboBkUp2_Profile, "")
	EndIf
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "LAST_USED_LIST", "")
	
EndFunc   ;==>_PurgeListsCM

Func _PurgeDataDirCM()
	If FileExists($g_sScriptDir & "\YourData") Then
		If _Metro_MsgBox(4, $g_sProgramName, "Are you sure you want to shred your recovery folder?" & @CRLF & "Size: " & Round(DirGetSize($g_sScriptDir & "\YourData") / 1024 / 1024, 2) & " Mb") = "Yes" Then ; $MB_YES=6
			TrayTip($g_sProgramName, "Purging..", 5, 1)
			_PurgeDir($g_sScriptDir & "\YourData")
			DirRemove($g_sScriptDir & "\YourData", 1) ;Remove everything
			_Metro_MsgBox(0, $g_sProgramName, "Done. YourData folder has been purged from Earth and is now unrecoverable.")
		EndIf
	Else
		_Metro_MsgBox(0, $g_sProgramName, $g_sScriptDir & "\YourData folder does not exist.")
	EndIf
EndFunc   ;==>_PurgeDataDirCM

Func _PurgeRecentsCM()
	Local $sLogPurged
	If _Metro_MsgBox(4, $g_sProgramName, "This will clear all recently opened items/MRU/pinned items/jump lists in Windows." & @CRLF & @CRLF & "Proceed?") = "Yes" Then
		TrayTip($g_sProgramName, "Shredding files, this may take a while..", 4, 1)
		_PurgeDir(@AppDataDir & "\Microsoft\Windows\Recent")
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\INetCache\IE") ;Win10
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\Temporary Internet Files") ;Win7-8
		_PurgeDir(@UserProfileDir & "\AppData\Local\Microsoft\Windows\History")
		Run("RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255")
		_PurgeDir(@UserProfileDir & "\AppData\Media Cache")
		_PurgeRegCM()
	EndIf
	If _Metro_MsgBox(4, $g_sProgramName, "Clear event logs (requires Admin)?") = "Yes" Then
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
	_Metro_MsgBox(0, $g_sProgramName, "Everything has been securely erased" & $sLogPurged & ". Please note that you might have left traces within your registry still.")
EndFunc   ;==>_PurgeRecentsCM


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
