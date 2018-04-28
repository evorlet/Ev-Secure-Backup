Func _Crypt_EncryptFolder($_sSourceFolder, $_sDestinationFolder, $_sKey, $_iAlgID)
	;//Recursively encrypt everything in a folder.
	Local $sDestFile
	If Not FileExists($_sDestinationFolder) Then DirCreate($_sDestinationFolder)
	$aFiles = _FileListToArray($_sSourceFolder, '*', 1) ;List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			$sDestFile = _Crypt_EncryptData($aFiles[$a], $_sKey, $_iAlgID)
			_Crypt_EncryptFile($_sSourceFolder & "\" & $aFiles[$a], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
			If @error Then
				If @error > 530 Then
					_Metro_MsgBox(0, 'Error occurred', 'Unable to encrypt piece, possibly file in use.')
				Else
					_Metro_MsgBox(0, 'Error occurred', 'Error during encryption. Code ' & @error & @CRLF & 'Your data might be lost, be advised!')
				EndIf
			EndIf
		Next
	EndIf
	$aFolders = _FileListToArray($_sSourceFolder, '*', 2) ;List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			$sDestFile = $aFolders[$b] ;_Crypt_EncryptData($aFolders[$b], $_sKey, $_iAlgID)
			_Crypt_EncryptFolder($_sSourceFolder & "\" & $aFolders[$b], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
		Next
	EndIf
EndFunc   ;==>_Crypt_EncryptFolder

Func _Crypt_DecryptFolder($_sSourceFolder, $_sDestinationFolder, $_sKey, $_iAlgID)
	;//Deprecated as of v190
	Local $sDestFile
	If Not FileExists($_sDestinationFolder) Then DirCreate($_sDestinationFolder)
	$aFiles = _FileListToArray($_sSourceFolder, '*', 1) ;List all files in dir
	If IsArray($aFiles) Then
		For $a = 1 To $aFiles[0]
			$sDestFile = BinaryToString(_Crypt_DecryptData($aFiles[$a], $_sKey, $_iAlgID))
			_Crypt_DecryptFile($_sSourceFolder & "\" & $aFiles[$a], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
			If @error = 420 Then Return SetError(1)
		Next
	EndIf
	$aFolders = _FileListToArray($_sSourceFolder, '*', 2) ;List all folders in dir
	If IsArray($aFolders) Then
		For $b = 1 To $aFolders[0]
			$sDestFile = $aFolders[$b] ;_Crypt_EncryptData($aFolders[$b], $_sKey, $_iAlgID)
			_Crypt_DecryptFolder($_sSourceFolder & "\" & $aFolders[$b], $_sDestinationFolder & "\" & $sDestFile, $_sKey, $_iAlgID)
		Next
	EndIf
EndFunc   ;==>_Crypt_DecryptFolder
