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
		_Metro_MsgBox(0, $g_sProgramName, "Please select a container file/folder to restore from.")
		Return
	EndIf
	If Not FileExists($sContainerPath) Then
		_Metro_MsgBox(0, $g_sProgramName, "Target container does not exist.")
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
	Local $sReport, $nBytes
	If Not GUICtrlRead($ipRestore3_Pwd) Then
		_Metro_MsgBox(0, $g_sProgramName, "Please enter the Password you used for encryption.")
		Return
	EndIf
	
	DirCreate($g_sScriptDir & "\YourData")
	$sTempZip = $g_sScriptDir & "\_temp.zip"
	$sTempDir = $g_sScriptDir & "\YourData"
	$sPwd = GUICtrlRead($ipRestore3_Pwd)
	$sPwdHashed = _ObfuscatePwd($sPwd)
	$hKey = _Crypt_DeriveKey($sPwdHashed, $CALG_AES_256)
	$sPwd = "" ;//Overwrite variable in RAM for security reason.
	$sPwdHashed = "" ;//Not 100% positive this would always work.
	
	HideAllControls(False)
	GUICtrlSetState($cPic, $GUI_SHOW)
	GUIRegisterMsg($WM_TIMER, "PlayAnim") ;//Show and play loading animation
	GUICtrlSetState($btnBack, $GUI_HIDE)
	GUICtrlSetState($btnNext, $GUI_DISABLE)
	
	$sContainerPath = GUICtrlRead($ipRestore2_ArchiveDir)
	Opt("GUIOnEventMode", 1)
	GUICtrlSetOnEvent($GUI_CLOSE_BUTTON, "ExitS")
	;//Decrypt
	$aGUIPos = WinGetPos($hGUI)
	$lRestore4_Status = GUICtrlCreateLabel("", ($aGUIPos[2] / 2) - 120, $aGUIPos[3] - 233, 280, 30, BitOR(0x0200, 0x01))
	GUICtrlSetFont($lRestore4_Status, 11, 550, Default, "Segoe UI")
	GUICtrlSetResizing($lRestore4_Status, 8 + 32 + 128 + 768)
	$sReport &= "Decrypting container.." & @CRLF
	$g_LoadingText = "Decrypting"
	If StringRegExp(FileGetAttrib($sContainerPath), "D") Then ;//Container is folder, therefore wasn't compressed. - Pre v190 legacy
		_Crypt_DecryptFolder($sContainerPath, $g_sScriptDir & "\YourData", $hKey, $CALG_USERKEY)
	Else
		If FileExists($sTempZip) Then _FileShred($sTempZip)
		_Crypt_DecryptFile($sContainerPath, $sTempZip, $hKey, $CALG_USERKEY)
		If Not @error Then
		If _FileReadBackwards($sTempZip, 2) = "?]" Then ;//Custom method
			_BinarySplit($sTempZip, $g_sScriptDir & "\YourData")
		Else ;//zip library method
			$iError = @error
			If $iError Then
				$sTemp = $iError
				$sReport &= "Error decrypting container - " & StringReplace($sTemp, "420", "Invalid password.") & @CRLF
			Else
				For $i = 0 To 30
					If FileExists($sTempZip) Then ExitLoop
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
			EndIf
		EndIf
		$g_LoadingText = "Cleaning"
		If _FileShred($sTempZip) = 1 Then $sReport &= "Error shredding _temp.zip file leftover!" & @CRLF
		Else
			$sReport &= "Error occurred during decryption, possibly wrong password. Code: " & @error & @CRLF
		EndIf
	EndIf
	$sReport &= "Restoration finished." & @CRLF & "Destination: " & $g_sScriptDir & "\YourData"
	_Crypt_DestroyKey($hKey)
	;//Remaining GUI stuff
	Opt("GUIOnEventMode", 0)
	GUICtrlSetData($lRestore4_Status, "")
	$aCtrlPos = ControlGetPos($hGUI, "", $btnNext)
	$eReport = GUICtrlCreateEdit($sReport, 15, 45, $aCtrlPos[0] + $aCtrlPos[2] - 10, 200, BitOR($WS_VSCROLL, $ES_READONLY)) ;//This control is deleted in step 5
	GUICtrlSetState($cbBkUp4_ShowEncryptedFile, $GUI_SHOW)
	GUICtrlSetState($btnNext, $GUI_ENABLE)
	GUICtrlSetState($cPic, $GUI_HIDE)
	GUIRegisterMsg($WM_TIMER, "")
	
	$sState = "R4"
EndFunc   ;==>Restore4

Func Restore5()
	GUICtrlDelete($eReport)
	If GUICtrlRead($cbBkUp4_ShowEncryptedFile) = $GUI_CHECKED Then _WinAPI_ShellOpenFolderAndSelectItems($g_sScriptDir & "\YourData")
	$sState = "R5"
	ToOriginal()
EndFunc   ;==>Restore5

Func Restore2_Browse()
	$sTemp = FileOpenDialog("Select encrypted container file", $g_sScriptDir, "All files (*.*)")
	GUICtrlSetData($ipRestore2_ArchiveDir, $sTemp)
EndFunc   ;==>Restore2_Browse
