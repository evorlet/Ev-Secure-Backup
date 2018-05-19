#include-once
#include <Array.au3>
#include <WinAPIFiles.au3>
#include <WinAPIHObj.au3>
#include <File.au3>

Global Const $_1KB = 1024
Global Const $_128B = 128
Global Const $_48KB = $_1KB * 48
Global Const $_1MB = 1048576
;//Header size's len = 1kB


Func _FileReadBackwards($__sPath, $__nChars)
	$__hFile = FileOpen($__sPath, 16)
	FileSetPos($__hFile, -$__nChars, 2)
	$sRtn = FileRead($__hFile, $__nChars)
	FileClose($__hFile)
	Return $sRtn
EndFunc


Func _DisplayPackageInfo($sContainerPath)
	$sHeader = _GetHeaderFromPackage($sContainerPath)
	$aInfo = _ExtractDataFromHeader($sHeader)
	_ArrayDisplay($aInfo, "Package info", "", 64, "")
EndFunc   ;==>_DisplayPackageInfo

Func _GetHeaderSize($sContainerPath)
	$sSzHeader = BinaryToString(_FileReadBackwards($sContainerPath, $_128B))
	;$sSzHeader = "[!?evHeaderSz=10583950284!?][?...?]"
	$oRE = StringRegExp($sSzHeader, "\[\!\?evHeaderSz=(\d+)\!\?\]", 3)
	If Not @error Then
		Return Int($oRE[0])
	Else
		Return 0
	EndIf
EndFunc

Func _GetHeaderFromPackage($sContainerPath)
	Local $sOldHeader
	$nHeaderSz = _GetHeaderSize($sContainerPath)
	If $nHeaderSz > 0 Then
		$sOldHeader = BinaryToString(_FileReadBackwards($sContainerPath, $nHeaderSz))
		$sOldHeader = StringReplace($sOldHeader, "[!?evHeaderSz=" & $nHeaderSz & "!?]", "")
	EndIf
	Return $sOldHeader
EndFunc   ;==>_GetHeaderFromPackage

Func _ExtractDataFromHeader($sHeader)
	Local $aRtn[1][3], $nIndex = 0
	$aData = StringRegExp($sHeader, "(?U)\[\?(.+)\?\]", 3)
	If Not UBound($aData) Then Return
	For $i = 0 To UBound($aData) - 1
		$aInfo = StringSplit($aData[$i], "|", 2)
		If @error Then ContinueLoop ;//Probably corrupted file, proceed anyway
		$sSubfolder = $aInfo[0]
		For $o = 1 To UBound($aInfo) - 1
			ReDim $aRtn[$nIndex + 1][3]
			$a = StringSplit($aInfo[$o], ":", 2)
			$sFileName = $a[0]
			$sFileSize = $a[1]
			$aRtn[$nIndex][0] = $sFileName
			$aRtn[$nIndex][1] = $sFileSize
			$aRtn[$nIndex][2] = $sSubfolder
			$nIndex += 1
		Next
	Next
	Return $aRtn
EndFunc   ;==>_ExtractDataFromHeader


Func _GetSubFolder($s_FolderPath)
	;//Get name of the folder relative to the path (E:\Lab\Folder ->"Folder")
	If StringRight($s_FolderPath, 1) = "\" Then $s_FolderPath = StringTrimRight($s_FolderPath, 1)
	$a = StringSplit($s_FolderPath, "\", 2)
	If UBound($a) > 1 Then
		Return $a[UBound($a) - 1]
	Else
		Return $s_FolderPath
	EndIf
EndFunc   ;==>_GetSubFolder

Func _BinaryMergeFolder($s_FolderPath, $sContainerPath, $bCheckDuplicate = True, $sSubfolder = "")
	If Not StringRegExp(FileGetAttrib($s_FolderPath), "(D)") Then Return ;//Not a folder
	If $sSubfolder = "" Then $sSubfolder = _GetSubFolder($s_FolderPath)
	$aFiles = _FileListToArray($s_FolderPath, "*", 1, True) ;//Return absolute path of files
	If IsArray($aFiles) Then
		$aFiles[0] = $aFiles[UBound($aFiles) - 1]
		_ArrayPop($aFiles) ;//replace index count in 1st element with data
		_BinaryMergeFiles($aFiles, $sContainerPath, $bCheckDuplicate, $sSubfolder)
	EndIf
	$aFolders = _FileListToArray($s_FolderPath, "*", 2, True) ;//Return absolute path of folders
	If IsArray($aFolders) Then
		$aFolders[0] = $aFolders[UBound($aFolders) - 1]
		_ArrayPop($aFolders) ;//replace index count in 1st element with data
		For $i = 0 To UBound($aFolders) - 1
			_BinaryMergeFolder($aFolders[$i], $sContainerPath, $bCheckDuplicate, $sSubfolder & "\" & _GetSubFolder($aFolders[$i]))
		Next
	EndIf
EndFunc   ;==>_BinaryMergeFolder

Func _TrimOldHeader($sContainerPath)
	$nOldHeaderSz = _GetHeaderSize($sContainerPath)
	If Not $nOldHeaderSz Then Return
	$sFileSize = FileGetSize($sContainerPath)
	$hContainer = FileOpen($sContainerPath, 1 + 16)
	FileSetPos($hContainer, - $nOldHeaderSz, $FILE_END)
	FileSetEnd($hContainer)
	FileClose($hContainer)
EndFunc

Func _BinaryMergeFiles($a_FilesToMerge, $sContainerPath, $bCheckDuplicate = False, $sSubfolder = "")
	$sOldHeader = _GetHeaderFromPackage($sContainerPath)
	_TrimOldHeader($sContainerPath)
	$hContainer = FileOpen($sContainerPath, 17)
	For $i = 0 To UBound($a_FilesToMerge) - 1
		$sCurFilePATH = $a_FilesToMerge[$i]
		$sCurFileSIZE = FileGetSize($sCurFilePATH)
		If Not $sCurFileSIZE Then ContinueLoop ;//Empty file or file doesn't exist, proceed to next file.
		$hTargetFile = FileOpen($sCurFilePATH, 16)
		If $sCurFileSIZE > $_1MB Then ;//Read 1MB at a time to avoid overflow.
			$nBytesRead = 0
			While $nBytesRead < $sCurFileSIZE
				$sTargetData = FileRead($hTargetFile, $_1MB)
				FileWrite($hContainer, $sTargetData)
				$nBytesRead += $_1MB
			WEnd
		Else
			$sTargetData = FileRead($hTargetFile, $sCurFileSIZE)
			FileWrite($hContainer, $sTargetData)
		EndIf
	Next
	FileClose($hTargetFile)
	FileClose($hContainer)
	_WriteHeader($a_FilesToMerge, $sContainerPath, False, $sSubfolder, $sOldHeader)
EndFunc   ;==>_BinaryMergeFiles

Func _WriteHeader(ByRef $a_FilesToMerge, $sContainerPath, $bCheckDuplicate = False, $sSubfolder = "", $sOldHeader = "")
	;//Remove old header, append new header at end of container
	Local $sHeader, $nBytesRef, $hTargetFile
	;//[?E:\_file1.txt,1045?][D:\hello.png,2459035?]
	$aOldHeaderData = _ExtractDataFromHeader($sOldHeader) ;//Check for duplicate files
	$sHeader = "[?" & $sSubfolder
	For $i = 0 To UBound($a_FilesToMerge) - 1
		$sCurFilePATH = $a_FilesToMerge[$i]
		$sCurFileSIZE = FileGetSize($sCurFilePATH)
		If Not $sCurFileSIZE Then ContinueLoop
		$sCurFileNAME = _GetFileNameFromPath($sCurFilePATH)
		If $bCheckDuplicate = True Then
			If __BinaryCheckDuplicate($aOldHeaderData, $sCurFilePATH) Then;//Duplicate file
				$a_FilesToMerge[$i] = "" ;//Remove this file from merger list.
				ContinueLoop (1) ;//Skip adding data about this file to header.
			EndIf
		EndIf
		$sHeader &= "|"
		$sHeader &= $sCurFileNAME & ":" ;//[?file1.txt,1045|?][?hello.png,2459035|NewFolder?]
		$sHeader &= $sCurFileSIZE
	Next
	$sHeader &= "?]"
	$sHeader = StringRegExpReplace($sHeader, "\[\?\?\]", "", 1)
	$nNewHeaderSz = StringLen($sOldHeader & $sHeader)
	$nTotalNewHeaderSz = $nNewHeaderSz + StringLen("[!?evHeaderSz=" & $nNewHeaderSz & "!?]")  ;//With headsize len included
	If Not $sOldHeader Then  ;//Create first header
		$sHeader = "[!?evHeaderSz=" & $nTotalNewHeaderSz & "!?]" & $sHeader
	Else	;//Append more header info
		$sHeader = "[!?evHeaderSz=" & $nTotalNewHeaderSz & "!?]" & $sOldHeader & $sHeader
		_SetNewHeaderSz($sHeader, $nTotalNewHeaderSz)
	EndIf

	$hContainerAP = FileOpen($sContainerPath, 1 + 16)
	FileWrite($hContainerAP, $sHeader)
	FileClose($hContainerAP)
EndFunc	


Func _SetNewHeaderSz(ByRef $sOldHeader, $nNewHeaderSz)
	$sOldHeader = StringRegExpReplace($sOldHeader, "\[\!\?evHeaderSz=(\d+)\!\?\]", "[!?evHeaderSz=" & $nNewHeaderSz &"!?]", 1)
EndFunc

Func __BinaryCheckDuplicate($aOldHeaderData, $sFilePath)
	For $j = 0 To UBound($aOldHeaderData, 1) - 1
		$s_Tmp = $aOldHeaderData[$j][2] & "\" & $aOldHeaderData[$j][0]
		If StringRight($sFilePath, StringLen($s_Tmp)) = $s_Tmp Then
			Return True
		Else
			Return False
		EndIf	
	Next
EndFunc
	
Func _BinarySplit($sContainerPath, $sDest)
	$sDest = _StripFilePath($sDest)
	If Not FileExists($sDest) Then DirCreate($sDest)
	$hContainer = FileOpen($sContainerPath, 16)
	$sCurFileSIZE = FileGetSize($sContainerPath)
	If Not $sCurFileSIZE Then Return 0
	$sHeader = _GetHeaderFromPackage($sContainerPath)
	$aFileInfo = _ExtractDataFromHeader($sHeader)
	For $i = 0 To UBound($aFileInfo, 1) - 1
		$sFileName = $aFileInfo[$i][0]
		$sFileSize = $aFileInfo[$i][1]
		$sSubfolder = $aFileInfo[$i][2]
		$sDestFinal = $sDest & "\" & $sSubfolder
		$sData = FileRead($hContainer, $sFileSize)
		$hFile = FileOpen($sDestFinal & "\" & $sFileName, 10) ;//$FO_OVERWRITE + $FO_CREATEPATH
		FileWrite($hFile, $sData)
		FileClose($hFile)
	Next
	FileClose($hContainer)
	Return 1
EndFunc   ;==>_BinarySplit

Func _GetFileNameFromPath($sString)
	$aRE = StringRegExp($sString, ".*\\(.+)", 3)
	If @error Then Return 0
	Return $aRE[0]
EndFunc   ;==>_GetFileNameFromPath

Func _StripFilePath($sString)
	Return StringReplace($sString, "\\", "\")
EndFunc   ;==>_StripFilePath

Func _GetUsedBytesInBufferCount($sbString)
	;//Get the total of used bytes in the buffer
	If Not StringInStr($sbString, "[?") Then Return 0 ;//Buffer doesn't exist - is new container
	$a = StringToASCIIArray($sbString)
	For $i = 0 To UBound($a) - 1
		If $a[$i] = 0 Then Return $i;//NULL doesn't exist as an Autoit string variant so this is fine
	Next
	Return UBound($a)
EndFunc   ;==>_GetUsedBytesInBufferCount
