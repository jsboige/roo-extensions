' Genere pour la schtask Vibe-Feeder (lane Mistral Vibe po-2025, durable) -- NE PAS EDITER A LA MAIN.
' Tache       : Vibe-Feeder (heure, durable #3202)
' Principe    : Run(cmd, 0, True) passe SW_HIDE -> pas de flash conhost.
' MaxParallel : 1 (retombee executee 21/10 -- user : >100 EUR/j consommes le 20/10 avec //2,
'               ~60 EUR restants pour 10 j ; le cran //2 du 02/10 (#4024) avait pour condition
'               de repli "console > cible +15 %" -- remplie depuis le matin du 20/10, jamais
'               appliquee. Regime courant : mono + trigger PT12H (07:00/19:00) = ~2 runs/j.
'               Re-monter le parallelisme exige un mandat user explicite.)
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("powershell.exe -ExecutionPolicy Bypass -File ""D:\dev\roo-extensions\scripts\scheduling\vibe-feeder.ps1"" -PostVisibility -MaxParallel 1", 0, True)
WScript.Quit rc
