Func ToBkUp2()
	Local $aBkUpList[] = [], $sTemp
	HideAllControls(False)
	GUICtrlSetState($lvBkUp2_BackupList, $GUI_SHOW)
	GUICtrlSetState($comboBkUp2_Profile, $GUI_SHOW)
	
	If _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) = 0 Then ;*If Listview is empty then create new list
		_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
		_AddDefaultFoldersToLV($lvBkUp2_BackupList)
		$sTemp = FileRead($g_sScriptDir & "\ev_" & GUICtrlRead($comboBkUp2_Profile))
		If $sTemp Then $sTemp = BinaryToString(_Crypt_DecryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256)) ;//Decrypt list file
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
		_Metro_MsgBox(0, $g_sProgramName, "List name must not be empty!")
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
			If $i >= $g_nDefaultFoldersCount Then $sBackupItem &= "::chkd" ; Mark if item is checked for future list saving, ignored if is default folder
		EndIf
		_ArrayAdd($aAllItems, $sBackupItem)
	Next
	; $aAllItems: all items - for list saving|$g_aToBackupItems: checked items only
	
	If UBound($g_aToBackupItems) = 0 Then ; No item checked
		_Metro_MsgBox(0, $g_sProgramName, "No files were selected for backup.")
		Return
	EndIf
	
	;//Generate [raw] string to save to list file, default folders are removed
	For $i = 0 To UBound($aAllItems) - 1
		$sTemp &= $aAllItems[$i] & "|"
	Next
	;//Remove default folders from list file
	For $i = 0 To UBound($g_aDefaultItems) - 1
		$sRegExPattern &= $g_aDefaultItems[$i][0] & "|"
	Next
	$sRegExPattern = StringTrimRight($sRegExPattern, 1) ; Remove last "|" delimiter so "|" symbols don't get erased during regex replace
	$sTemp = StringRegExpReplace($sTemp, "\x7C?(" & $sRegExPattern & ")\x7C", "")
	$sTemp = _Crypt_EncryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256) ;//Encrypt list file
	
	;//Save the name of current list for future program startup
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "LAST_USED_LIST", $sCurProfile)

	;//Save everything from list to file
	$hBkUpList = FileOpen($g_sScriptDir & "\ev_" & $sCurProfile, 2)
	FileWrite($hBkUpList, $sTemp)
	FileClose($hBkUpList)
	
	;//Remember default folders' states
	_DefaultItemStates_Save()
	
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

Func ToBkUp4()
	;//Main step in backup, compress & store files in an encrypted container
	Local $sReport, $nIndex
	$sPwd = GUICtrlRead($ipBkUp3_Pwd)
	If Not $sPwd Then
		_Metro_MsgBox(0, $g_sProgramName, "Please enter a Password.")
		Return
	EndIf
	If GUICtrlRead($cbBkUp3_ShowPwd) = $GUI_UNCHECKED And GUICtrlRead($ipBkUp3_Pwd) <> GUICtrlRead($ipBkUp3_PwdConfirm) Then
		_Metro_MsgBox(0, $g_sProgramName, "Passwords didn't match.")
		Return
	EndIf
	$hObjTimer = TimerInit()
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "SHOW_PASSWORD", GUICtrlRead($cbBkUp3_ShowPwd))
	IniWrite($g_sScriptDir & "\_Res\Settings.ini", "General", "COMPRESS_DATA", GUICtrlRead($cbBkUp3_Compress))
	HideAllControls(True)
	GUICtrlSetState($GUI_MINIMIZE_BUTTON, $GUI_HIDE) ;//To not overlap loading screen
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim")
	GUICtrlSetState($btnNext, $GUI_SHOW)
	$sPwdHashed = _ObfuscatePwd($sPwd)
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)
	$sPwd = "" ;//Overwrite variable in RAM for security reason.
	$sPwdHashed = "" ;//Not 100% positive this would always work.
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$lBkUp4_Status = 0 ;GUICtrlCreateLabel("", 50, $aCtrlPos[1] - 120, $aCtrlPos[0], 24, BitOR(0x0200, 0x01))
	$lBkUp4_CurrentFile = GUICtrlCreateLabel("", 50, $aCtrlPos[1] - 95, $aCtrlPos[0], 20, BitOR(0x0200, 0x01))
	GUICtrlSetColor(-1, $FontThemeColor)
	$sContainerName = $sCurProfile
	$g_LoadingText = "Preparing"
	If FileExists($sContainerName) Then
		$sReport &= "Container " & $sContainerName & " already exists, overwriting.." & @CRLF
		FileDelete($g_sScriptDir & "\" & $sContainerName)
	EndIf
	Opt("GUIOnEventMode", 1)
	GUICtrlSetOnEvent($GUI_CLOSE_BUTTON, "ExitS")
	If GUICtrlRead($cbBkUp3_Compress) = $GUI_CHECKED Then ;Use Zip encryption
		$g_LoadingText = "Compressing"
		$sReport &= "Compressing your data.." & @CRLF
		$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
		GUICtrlSetData($lBkUp4_Status, "")
		GUICtrlSetResizing($lBkUp4_Status, 8 + 32 + 128 + 768)
		GUICtrlSetResizing($lBkUp4_CurrentFile, 8 + 32 + 128 + 768) ;Centered
		GUICtrlSetFont($lBkUp4_Status, 11, 550, Default, "Segoe UI")
		GUICtrlSetState($btnNext, $GUI_DISABLE)
		$sTempZip = $g_sScriptDir & "\_temp.zip"
		_Zip_Create($sTempZip, 1)
		AdlibRegister("HideCompressing", 30) ;// Workaround to hide "Compressing" popup windows
		For $i = 0 To 20
			Sleep(200)
			If _FileWriteAccessible($sTempZip) = 1 Then ExitLoop
		Next
		For $i = 0 To UBound($g_aToBackupItems, 1) - 1 ;// Process all backup items read from listview
			If Mod($i, 8) = 0 Then Sleep(200) ;Take a break every 8 items processed
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
					_FileRename($sFileToCompress, $sNewFileName)
					For $a = 0 To 10
						Sleep(50)
						If FileExists($sNewFileName) Then ExitLoop
					Next
					_Zip_AddItem($sTempZip, $sNewFileName, "", 4 + 8 + 16 + 1024)
					_FileRename($sNewFileName, $sFileToCompress)
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
		_Crypt_EncryptFile($sTempZip, $g_sScriptDir & "\" & $sContainerName, $hKey, $CALG_USERKEY)
		GUICtrlSetState($GUI_MINIMIZE_BUTTON, $GUI_SHOW)
		If @error Then
			$sReport &= "Encryption error. Attempted key: " & $sPwdHashed & ". Algorithm: AES-256" & @CRLF
		Else
			GUICtrlSetData($lBkUp4_Status, "Shredding leftovers..")
			If _FileShred($sTempZip) = 1 Then $sReport &= "Error shredding " & @ScriptDir & "\_temp.zip file. Action advised!" & @CRLF
			$sReport &= "File saved to " & $g_sScriptDir & "\" & $sContainerName & @CRLF
		EndIf
	Else ;//No compression, only encrypt files/folders
		$g_LoadingText = "Merging"
		For $i = 0 To UBound($g_aToBackupItems) - 1
			$sFileToCompress = _ConvertDefaultFolderPath($g_aToBackupItems[$i])
			If StringRegExp(FileGetAttrib($sFileToCompress), "(D)") Then
				_BinaryMergeFolder($sFileToCompress, $g_sScriptDir & "\_temp", False)
			Else
				Local $a[] = [$sFileToCompress]
				_BinaryMergeFiles($a, $g_sScriptDir & "\_temp", False)
			EndIf
		Next
		$g_LoadingText = "Encrypting"
		_Crypt_EncryptFile($g_sScriptDir & "\_temp", $g_sScriptDir & "\" & $sContainerName, $hKey, $CALG_USERKEY)
		$g_LoadingText = "Cleaning"
		If _FileShred($g_sScriptDir & "\_temp") = 1 Then $sReport &= "Error shredding " & @ScriptDir & "\_temp file. Action advised!" & @CRLF
		$sReport &= "Encryption finished." & @CRLF & "Destination: " & $g_sScriptDir & "\" & $sContainerName & @CRLF
	EndIf
	_Crypt_DestroyKey($hKey)
	Opt("GUIOnEventMode", 0)
	GUICtrlSetData($lBkUp4_CurrentFile, "")
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$sReport &= "Operation took " & StringLeft(TimerDiff($hObjTimer) / 1000, 5) & " seconds."
	$eReport = GUICtrlCreateEdit($sReport, 15, 45, $aCtrlPos[0] + $aCtrlPos[2] - 10, 200, BitOR($WS_VSCROLL, $ES_READONLY))
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
	BkUp2_SelectAll($lvBkUp2_BackupList)
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then
		_WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\" & $sCurProfile)
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
	Local $count, $nItemSelected, $o
	_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
	$nItemSelected = _GUICtrlListView_GetSelectedIndices($lvBkUp2_BackupList)
	If $nItemSelected <> "" Then ; //If there's highlighted item, delete it instead of all checked items
		_GUICtrlListView_DeleteItemsSelected($lvBkUp2_BackupList)
	Else ; 						  //Else delete all checked items
		$_nItemCount = _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1
		For $i = 0 To $_nItemCount
			If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $i) = True Then $o += 1
		Next
		If $o = 0 Then
			_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
			Return
		EndIf
		If _Metro_MsgBox(4, $g_sProgramName, "Remove " & $o & " selected items from list?") = "Yes" Then
			For $i = 0 To $_nItemCount
				If _GUICtrlListView_GetItemChecked($lvBkUp2_BackupList, $count) = True Then
					_GUICtrlListView_DeleteItem($lvBkUp2_BackupList, $count)
					$count -= 1
				EndIf
				$count += 1
			Next
		EndIf
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
			;GUICtrlSetData($cmBkUp2_SelectAll, "De-Select All")
		Else
			;GUICtrlSetData($cmBkUp2_SelectAll, "Select All")
		EndIf
	EndIf
EndFunc   ;==>BkUp2_SelectAll

Func BkUp2_SelectList() ;Switch to a new list, load all items from respective list
	_GUICtrlListView_BeginUpdate($lvBkUp2_BackupList)
	For $i = $g_nDefaultFoldersCount To _GUICtrlListView_GetItemCount($lvBkUp2_BackupList) - 1 ;//$g_nDefaultFoldersCount=End of default folders section
		_GUICtrlListView_DeleteItem($lvBkUp2_BackupList, $g_nDefaultFoldersCount)
	Next
	_GUICtrlListView_EndUpdate($lvBkUp2_BackupList)
	$sTemp = FileRead($g_sScriptDir & "\" & "ev_" & GUICtrlRead($comboBkUp2_Profile))
	$sTemp = BinaryToString(_Crypt_DecryptData($sTemp, "!y^86s*z;s_-21", $CALG_AES_256))
	$aBkUpList = StringSplit($sTemp, "|", 2)
	_AddFilesToLV($lvBkUp2_BackupList, $aBkUpList, True)
EndFunc   ;==>BkUp2_SelectList

Func _DefaultItemStates_Save()
	;//Remember default folders' states
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

Func _AddDefaultFoldersToLV($hWnd)
	#cs
		//NOTE: Current default folders: MyDocuments,Pictures,Music,Videos, data from mainstream browsers
	#ce
	If FileExists(@UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default") Then
		;//Back up Chrome data
		If _ArraySearch($g_aDefaultItems, "Chrome History") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome History|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\History|\_Res\Chrome.ico")
		If _ArraySearch($g_aDefaultItems, "Chrome Bookmarks") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome Bookmarks|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\Bookmarks|\_Res\Chrome.ico")
		If _ArraySearch($g_aDefaultItems, "Chrome Passwords") = -1 Then _ArrayAdd($g_aDefaultItems, "Chrome Passwords|" & @UserProfileDir & "\AppData\Local\Google\Chrome\User Data\Default\Login Data|\_Res\Chrome.ico")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Chromium\User Data\Default") Then
		;//Back up Chromium data
		If _ArraySearch($g_aDefaultItems, "Chromium History") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium History|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\History|\_Res\Chromium.ico")
		If _ArraySearch($g_aDefaultItems, "Chromium Bookmarks") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium Bookmarks|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\Bookmarks|\_Res\Chromium.ico")
		If _ArraySearch($g_aDefaultItems, "Chromium Passwords") = -1 Then _ArrayAdd($g_aDefaultItems, "Chromium Passwords|" & @UserProfileDir & "\AppData\Local\Chromium\User Data\Default\Login Data|\_Res\Chromium.ico")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Mozilla\Firefox\Profiles") Then
		;//Back up Firefox data
		If _ArraySearch($g_aDefaultItems, "Firefox Data") = -1 Then _ArrayAdd($g_aDefaultItems, "Firefox Data|" & @UserProfileDir & "\AppData\Roaming\Mozilla\Firefox\Profiles|\_Res\Firefox.ico")
	EndIf
	If FileExists(@UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable") Then
		;//Back up Opera data
		If _ArraySearch($g_aDefaultItems, "Opera Data") = -1 Then _ArrayAdd($g_aDefaultItems, "Opera Data|" & @UserProfileDir & "\AppData\Local\Roaming\Opera Software\Opera Stable|\_Res\Opera.bmp")
	EndIf
	_GUICtrlListView_BeginUpdate($hWnd)
	_GUIImageList_AddIcon($hImage, $g_sScriptDir & "\_Res\File.ico")
	_GUIImageList_AddIcon($hImage, $g_sScriptDir & "\_Res\Folder.ico")
	For $i = 0 To UBound($g_aDefaultItems) - 1
		_GUIImageList_AddIcon($hImage, $g_sScriptDir & $g_aDefaultItems[$i][2])
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


Func _ConvertDefaultFolderPath($sFolder)
	;//Replace default folders like "Documents" with actual dir path like "C:\Users\Sam\Documents", dir path is stored in $g_aDefaultItems[$i][1]
	For $i = 0 To $g_nDefaultFoldersCount - 1
		If $sFolder = $g_aDefaultItems[$i][0] Then
			$sFolder = $g_aDefaultItems[$i][1]
			ExitLoop
		EndIf
	Next
	Return $sFolder
EndFunc   ;==>_ConvertDefaultFolderPath

Func HideCompressing() ;Hide pop-up compressing window when archiving w/ ZIP
	If BitAND(WinGetState("Compressing"), 2) = 2 Then
		WinSetState("Compressing", "", @SW_HIDE)
		Sleep(1000)
	EndIf
EndFunc   ;==>HideCompressing

Func _ObfuscatePwd($sPwdToDerive) ;//Make user pwd longer
	Local $sResult
	$sResult = StringTrimLeft(_Crypt_HashData($sPwdToDerive, $CALG_SHA1), 2)
	$sResult &= StringReverse($sResult)
	Return $sResult
EndFunc   ;==>_ObfuscatePwd
