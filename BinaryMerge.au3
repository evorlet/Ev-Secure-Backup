#include-once
#include <Array.au3>
#include <WinAPIFiles.au3>
#include <WinAPIHObj.au3>
#include <File.au3>

Global Const $_1KB = 1024
Global Const $_48KB = $_1KB * 48
Global Const $_1MB = 1048576

Func _GetHeaderFromPackage($sContainerPath)
	$hContainerR = FileOpen($sContainerPath, 16)
	$sOldHeaderR = BinaryToString(FileRead($hContainerR, $_48KB))
	FileClose($hContainerR)
	$nUsedBytes = _GetUsedBytesInBufferCount($sOldHeaderR)
	$sOldHeader = StringLeft($sOldHeaderR, $nUsedBytes);//Trim unused bytes
	Return $sOldHeader
EndFunc

Func _ExtractDataFromHeader($sHeader)
	Local $aRtn[1][3]
	$aData = StringRegExp($sHeader, "(?U)\[\?(.+)\?\]", 3)
	For $i = 0 To UBound($aData) - 1
		ReDim $aRtn[$i+1][3]
		$aInfo = StringSplit($aData[$i], "|", 2)
		If @error Then ContinueLoop;//Probably corrupted file, proceed anyway
		$sFileName = $aInfo[0]
		$sFileSize = $aInfo[1]
		$sSubfolder = $aInfo[2]
		
		$aRtn[$i][0] = $sFileName
		$aRtn[$i][1] = $sFileSize
		$aRtn[$i][2] = $sSubfolder
	Next
	Return $aRtn
EndFunc	

Func _GetSubFolder($s_FolderPath)
	;//Get name of the folder relative to the path (E:\Lab\Folder ->"Folder")
	If StringRight($s_FolderPath, 1) = "\" Then $s_FolderPath = StringTrimRight($s_FolderPath, 1)
	$a = StringSplit($s_FolderPath, "\", 2)
	If UBound($a) > 1 Then
		Return $a[UBound($a) - 1]
	Else
		Return $s_FolderPath
	EndIf	
EndFunc

Func _BinaryMergeFolder($s_FolderPath, $sContainerPath, $bOverwrite = False, $sSubfolder = "")
	If Not StringRegExp(FileGetAttrib($s_FolderPath), "(D)") Then Return;//Not a folder
	If $sSubfolder = "" Then $sSubfolder = _GetSubFolder($s_FolderPath)
	$aFiles = _FileListToArray($s_FolderPath, "*", 1, True);//Return absolute path of files
	If IsArray($aFiles) Then
		$aFiles[0] = $aFiles[UBound($aFiles) - 1]
		_ArrayPop($aFiles);//replace index count in 1st element with data
		_BinaryMergeFiles($aFiles, $sContainerPath, $bOverwrite, $sSubfolder)
	EndIf
	$aFolders = _FileListToArray($s_FolderPath, "*", 2, True);//Return absolute path of folders
	If IsArray($aFolders) Then
		$aFolders[0] = $aFolders[UBound($aFolders) - 1]
		_ArrayPop($aFolders);//replace index count in 1st element with data
		For $i = 0 To UBound($aFolders) - 1
			_BinaryMergeFolder($aFolders[$i], $sContainerPath, $bOverwrite, $sSubfolder & "\" & _GetSubFolder($aFolders[$i]))
		Next
	EndIf	
EndFunc

Func _BinaryMergeFiles($a_FilesToMerge, $sContainerPath, $bOverwrite = False, $sSubfolder = "")
	;//Merge files into a container
	;//To do: folder hierachy, overwrite existing binary chunks/files
	Local $sHeader, $nBytesRef, $hTargetFile
	
	;//[?E:\_file1.txt,1045?][D:\hello.png,2459035?]
	$sOldHeader = _GetHeaderFromPackage($sContainerPath)
	$aOldHeaderData = _ExtractDataFromHeader($sOldHeader);//Check for duplicate files
	$sHeader = $sOldHeader;//Initialize using old header
	For $i = 0 To UBound($a_FilesToMerge) - 1
		$sCurFilePATH = $a_FilesToMerge[$i]
		$sCurFileSIZE = FileGetSize($sCurFilePATH)
		If Not $sCurFileSIZE Then ContinueLoop
		$sCurFileNAME = _GetFileNameFromPath($sCurFilePATH)
		For $j = 0 To UBound($aOldHeaderData, 1) - 1
			If $sCurFileNAME = $aOldHeaderData[$j][0] Then;//File already exists in container.
				If $bOverwrite = False Then
					$a_FilesToMerge[$i] = ""
					ContinueLoop(2);//Skip adding data about this file to header.
				ElseIf $bOverwrite = True Then
					If $aOldHeaderData[$j][1] <> $sCurFileSIZE Then;//Files content are different (sloppy check but should work regardless).
						;//Make a copy with incremental name
						$sCurFileNAME = "Duplicate_" & $sCurFileNAME
					Else;//Files are the same, no duplication needed.
						$a_FilesToMerge[$i] = ""
					EndIf
				EndIf
			EndIf
		Next
		$sHeader &= "[?" & $sCurFileNAME & "|";//[?E:\file1.txt,1045|?][?D:\hello.png,2459035|NewFolder?]
		$sHeader &= $sCurFileSIZE & "|"
		$sHeader &= $sSubfolder & "?]"
	Next
	$tHeader = DllStructCreate("byte["&$_48KB&"]")
	DllStructSetData($tHeader, 1, String($sHeader))
	
	;//Write header to the first 48kB of container - can contain info for up to approx 1400 files.
	$hContainerOW = _WinAPI_CreateFile($sContainerPath, 3, 4)
	_WinAPI_SetFilePointer($hContainerOW, 0)
	_WinAPI_WriteFile($hContainerOW, $tHeader, $_48KB, $nBytesRef)
	_WinAPI_CloseHandle($hContainerOW)
	
	$hContainer = FileOpen($sContainerPath, 17)
	For $i = 0 To UBound($a_FilesToMerge) - 1
		$sCurFilePATH = $a_FilesToMerge[$i]
		$sCurFileSIZE = FileGetSize($sCurFilePATH)
		If Not $sCurFileSIZE Then ContinueLoop;//Empty file or file doesn't exist, proceed to next file.
		$hTargetFile = FileOpen($sCurFilePATH, 16)
		If $sCurFileSIZE > $_1MB Then;//Read 1MB at a time to avoid overflow.
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
EndFunc

Func _BinarySplit($sContainerPath, $sDest)
	$sDest = _StripFilePath($sDest)
	If Not FileExists($sDest) Then DirCreate($sDest)
	$hContainer = FileOpen($sContainerPath, 16)
	$sCurFileSIZE = FileGetSize($sContainerPath)
	If Not $sCurFileSIZE Then Return 0
	$sHeader = _GetHeaderFromPackage($sContainerPath)
	$aFileInfo = _ExtractDataFromHeader($sHeader)
	FileSetPos($hContainer, $_48KB, 0);$_48KB= Header size
	For $i = 0 To UBound($aFileInfo, 1) - 1
		$sFileName = $aFileInfo[$i][0]
		$sFileSize = $aFileInfo[$i][1]
		$sSubfolder = $aFileInfo[$i][2]
		$sDestFinal = $sDest & "\" & $sSubfolder
		$sData = FileRead($hContainer, $sFileSize)
		$hFile = FileOpen($sDestFinal & "\" & $sFileName, 10);//$FO_OVERWRITE + $FO_CREATEPATH
		FileWrite($hFile, $sData)
		FileClose($hFile)
	Next
	FileClose($hContainer)
	Return 1
EndFunc

Func _GetFileNameFromPath($sString)
	$aRE = StringRegExp($sString, ".*\\(.+)", 3)
	If @error Then Return 0
	Return $aRE[0]
EndFunc

Func _StripFilePath($sString)
	Return StringReplace($sString, "\\", "\")
EndFunc	

Func _GetUsedBytesInBufferCount($sbString)
	;//Get the total of used bytes in the buffer
	If Not StringInStr($sbString, "[?") Then Return 0;//Buffer doesn't exist - is new container
	$a = StringToASCIIArray($sbString)
	For $i = 0 To UBound($a) - 1
		If $a[$i] = 0 Then Return $i
	Next
	Return UBound($a)
EndFunc
