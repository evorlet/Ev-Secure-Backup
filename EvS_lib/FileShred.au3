Func _FileShred($sFilePath)
	Local $aFilePath, $iSiz, $sChr = ""
	Local Static $sChrN = 0
	If StringRegExp(FileGetAttrib($sFilePath), "R") Then FileSetAttrib($sFilePath, "-R") ; RegEx is faster than StringInStr()
	$aFilePath = StringRegExp($sFilePath, "^(.*\\)(.*)$", 3)
	If Not IsArray($aFilePath) Then Return
	If FileGetSize($sFilePath) <= 1024 Then
		$iSiz = 1
	Else
		$iSiz = Round(FileGetSize($sFilePath) / 1024)
	EndIf
	$iSiz = Int($iSiz)
	If @error Then Return 1
	
	;//Number of passes
	;1st pass - write 0s
	$sChr = _StringRepeat($sChrN, 1024) ;//To prevent variable overflow and to optimize HDD speed
	$hFileToShred = FileOpen($sFilePath, 18)
	For $i = 1 To $iSiz
		FileWrite($hFileToShred, $sChr)
	Next
	
	;2nd pass - write random data
	FileSetPos($hFileToShred, 0, 0)
	$sChr2 = _RandomData(1024)
	For $i = 1 To $iSiz
		If FileWrite($hFileToShred, $sChr2) = 0 Then Return 1
	Next
	FileClose($hFileToShred)
	
	_FileRename($sFilePath, $aFilePath[0] & "0000000000000000000000000000000")
	$sFilePath = $aFilePath[0] & "0000000000000000000000000000000"
	For $i = 0 To 2
		FileSetTime($sFilePath, "20000101", $i) ;//Change file's created/accessed/modified time to y2k.
	Next
	FileDelete($sFilePath)
	Return 0
EndFunc   ;==>_FileShred


Func _PurgeDir($sDataDir) ;Shred all files in a folder - Recursive
	$aFiles = _FileListToArray($sDataDir, '*', 1) ;List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			_FileShred($sDataDir & "\" & $aFiles[$a])
		Next
	EndIf
	$aFolders = _FileListToArray($sDataDir, '*', 2) ;List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			_PurgeDir($sDataDir & "\" & $aFolders[$b])
		Next
	EndIf
EndFunc   ;==>_PurgeDir

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


Func _ShredOnReboot($sFilename)
	;//Issue: Can't shred on reboot if target file is on a different drive than script dir.
	Local $__s, $sReplacementFile = @ScriptDir & "\000"
	$_MOVEFILE_DELAY_UNTIL_REBOOT = 4
	$_MOVEFILE_REPLACE_EXISTING = 1
	$nRawItemSize = FileGetSize($sFilename)
	$hReplacementFile = FileOpen($sReplacementFile, 18)
	$__s = _StringRepeat(0, $nRawItemSize)
	FileWrite($hReplacementFile, $__s)
	FileClose($hReplacementFile)
	$a_dllrtn = DllCall("kernel32.dll", "int", "MoveFileEx", 'str', $sReplacementFile, 'str', $sFilename, 'dword', $_MOVEFILE_DELAY_UNTIL_REBOOT + $_MOVEFILE_REPLACE_EXISTING)
	If $a_dllrtn[0] = 0 Then FileDelete($sReplacementFile)
	Return $a_dllrtn[0]
EndFunc   ;==>_ShredOnReboot

Func _DeleteOnReboot($sFilename)
	$_MOVEFILE_DELAY_UNTIL_REBOOT = 4
	$a_dllrtn = DllCall("kernel32.dll", "int", "MoveFileEx", "str", $sFilename, "ptr", 0, "dword", $_MOVEFILE_DELAY_UNTIL_REBOOT)
	Return $a_dllrtn[0]
EndFunc   ;==>_DeleteOnReboot

Func _RandomData($nStringSize) ;//in bytes
	Local $sResult
	For $i = 1 To $nStringSize
		$sResult &= Chr(Random(0, 254, 1))
	Next
	Return $sResult
EndFunc   ;==>_RandomData
