' Genere pour la schtask Vibe-Feeder (lane Mistral Vibe po-2025, durable) -- NE PAS EDITER A LA MAIN.
' Tache       : Vibe-Feeder (heure, durable #3202)
' Principe    : Run(cmd, 0, True) passe SW_HIDE -> pas de flash conhost.
' MaxParallel : 2 (cran budget 02/10 -- console 7 EUR vs cible 8,2/j ; la duree d'un grain
'               ~26 min rend la cadence seule inefficace, le levier est le parallellisme).
'               Retomber a 1 si la console depasse la cible de > 15 % (regime octobre).
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("powershell.exe -ExecutionPolicy Bypass -File ""D:\dev\roo-extensions\scripts\scheduling\vibe-feeder.ps1"" -PostVisibility -MaxParallel 2", 0, True)
WScript.Quit rc
