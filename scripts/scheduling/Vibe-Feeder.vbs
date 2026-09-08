' Genere pour la schtask Vibe-Feeder (lane Mistral Vibe po-2025, durable) -- NE PAS EDITER A LA MAIN.
' Tache       : Vibe-Feeder (heure, durable #3202)
' Principe    : Run(cmd, 0, True) passe SW_HIDE -> pas de flash conhost.
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("powershell.exe -ExecutionPolicy Bypass -File ""D:\dev\roo-extensions\scripts\scheduling\vibe-feeder.ps1""", 0, True)
WScript.Quit rc
