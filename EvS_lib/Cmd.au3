;//[Shred] cmd if called with parameter
If $CmdLine[0] >= 1 Then
	If StringRegExp($CmdLineRaw, "/shred") Then
		If StringRegExp($CmdLine[1], "\\") Then
			FileSetAttrib($CmdLine[1], "-RS")
			If Not StringRegExp(FileGetAttrib($CmdLine[1]), "D") Then
				If _FileWriteAccessible($CmdLine[1]) = 1 Then
					If MsgBox(64 + 4, "EvShred", "Shred data?" & @CRLF & @CRLF & "WARNING: Shredded data will be lost forever!") = 6 Then
						_FileShred($CmdLine[1])
					EndIf
				ElseIf Not IsAdmin() Then
					ShellExecute(@AutoItExe, '"' & $CmdLine[1] & '"' & ' "' & "/shred" & '"', "", "runas")
				ElseIf IsAdmin() And _FileWriteAccessible($CmdLine[1]) = 0 Then
					If MsgBox(64 + 4, "EvShred", "Looks like " & $CmdLine[1] & " is undeletable (possibly in use or protected)." & @CRLF & @CRLF & "Delete file on next system reboot?") = 6 Then
						_DeleteOnReboot($CmdLine[1])
					EndIf
				EndIf
			Else
				If MsgBox(64 + 4, "EvShred", "Shred data?" & @CRLF & @CRLF & "WARNING: Shredded data will be lost forever!") = 6 Then
					_PurgeDir($CmdLine[1])
					DirRemove($CmdLine[1], 1)
				EndIf
			EndIf
		EndIf
	ElseIf $CmdLineRaw = "/add" Then
		_AddShredderCM()
	EndIf
	Exit
EndIf
