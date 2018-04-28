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

Func _FileRename($FileName, $ReName)
	Local $SHFILEOPSTRUCT, $SourceStruct, $DestStruct
	Local Const $FO_RENAME = 0x0004
	Local Const $FOF_SILENT = 0x0004
	Local Const $FOF_NOCONFIRMATION = 0x0010
	Local Const $FOF_NOERRORUI = 0x0400
	Local Const $FOF_NOCONFIRMMKDIR = 0x0200
	Local Const $NULL = 0
	$tSourceStruct = __StringToStruct($FileName)
	$DestStruct = __StringToStruct($ReName)
	$SHFILEOPSTRUCT = DllStructCreate("hwnd hWnd;uint wFunc;ptr pFrom;ptr pTo;int fFlags;int fAnyOperationsAborted;ptr hNameMappings;ptr lpszProgressTitle")
	DllStructSetData($SHFILEOPSTRUCT, "hWnd", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "wFunc", $FO_RENAME)
	DllStructSetData($SHFILEOPSTRUCT, "pFrom", DllStructGetPtr($tSourceStruct))
	DllStructSetData($SHFILEOPSTRUCT, "pTo", DllStructGetPtr($DestStruct))
	DllStructSetData($SHFILEOPSTRUCT, "fFlags", BitOR($FOF_SILENT, $FOF_NOCONFIRMATION, $FOF_NOERRORUI, $FOF_NOCONFIRMMKDIR))
	DllStructSetData($SHFILEOPSTRUCT, "fAnyOperationsAborted", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "hNameMappings", $NULL)
	DllStructSetData($SHFILEOPSTRUCT, "lpszProgressTitle", $NULL)
	$aCall = DllCall("shell32.dll", "int", "SHFileOperation", "ptr", DllStructGetPtr($SHFILEOPSTRUCT))
	If @error Then
		Return SetError(@error, @extended, 0)
	EndIf
	Return 1
EndFunc   ;==>_FileRename

Func __StringToStruct($string)
	Local $iLen = StringLen($string)
	Local $tStruct = DllStructCreate("char[" & String($iLen + 2) & "]")
	DllStructSetData($tStruct, 1, $string)
	DllStructSetData($tStruct, 1, 0, $iLen + 1)
	DllStructSetData($tStruct, 1, 0, $iLen + 2)
	Return $tStruct
EndFunc   ;==>__StringToStruct
