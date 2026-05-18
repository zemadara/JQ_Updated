#RequireAdmin
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=n
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include-once
#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

; --- LIAISON AVEC LA LIBRAIRIE GWAU3 ---
; Inclusion du fichier maître de l'API
#include "..\GwAu3-main\API\_GwAu3.au3"

; --- Variables Globales (déclarées AVANT les modules qui les utilisent) ---
Global $boolRun = True
Global $PlayingFor = "Kurzick"
Global $iTotalRuns = 0
Global $MyTotalZkeys = 0
Global $MID_Zkey = 28517

; Identifiants des cartes Jade Quarry
Global Const $JadeQuarryKurzickID = 296
Global Const $JadeQuarryLuxonID = 295
Global Const $JadeQuarryArenaID = 223

; --- INCLUSION DES MODULES JQ ---
#include "JQ_Movement.au3"
#include "JQ_Combat.au3"
#include "JQ_Quarry.au3"
#include "JQ_Economy.au3"

; --- CONFIGURATION DU MENU TRAY ---
Opt("TrayMenuMode", 3)
Opt("TrayAutoPause", 0)
Opt("TrayOnEventMode", 1)

Global $StartProgram = TrayCreateItem("Arrêter après le match")
TrayItemSetOnEvent(-1, "TrayHandler")
TrayCreateItem("")
Global $tExit = TrayCreateItem("Quitter")
TrayItemSetOnEvent(-1, "TrayHandler")

; ---------------------------------------------------------------------------
; Stubs requis par AU3Check (GwAu3 optional hooks - jamais appelés en pratique)
; ---------------------------------------------------------------------------
Func StartBot()
EndFunc

Func _Exit()
    Exit
EndFunc

Func Out($sMsg)
    ConsoleWrite("[GwAu3] " & $sMsg & @CRLF)
EndFunc

Func Extend_Write()
EndFunc

Func Extend_AssemblerWriteDetour()
EndFunc

Main()

#Region - Logique Principale

Func Main()
    ConsoleWrite("[MAIN] Démarrage du bot JQ..." & @CRLF)

    Local $hWnd = WinGetHandle("Guild Wars")
    If Not $hWnd Then
        MsgBox(16, "Erreur", "Guild Wars n'est pas lancé.")
        Exit
    EndIf
    ConsoleWrite("[MAIN] Fenêtre Guild Wars trouvée : handle=" & $hWnd & @CRLF)

    ; Récupération du PID depuis le handle de fenêtre pour l'attacher correctement
    Local $l_a_PID = DllCall("user32.dll", "dword", "GetWindowThreadProcessId", "hwnd", $hWnd, "dword*", 0)
    Local $l_pid = $l_a_PID[2]
    ConsoleWrite("[MAIN] PID Guild Wars : " & $l_pid & @CRLF)
    If $l_pid = 0 Then
        MsgBox(16, "Erreur", "Impossible de récupérer le PID de Guild Wars.")
        Exit
    EndIf

    ; Initialisation de l'API via le PID (on passe un entier, pas une chaîne)
    ConsoleWrite("[MAIN] Appel Core_Initialize avec PID=" & $l_pid & "..." & @CRLF)
    Local $initResult = Core_Initialize($l_pid)
    ConsoleWrite("[MAIN] Résultat Core_Initialize : " & $initResult & @CRLF)
    If Not $initResult Then
        MsgBox(16, "Erreur", "Impossible d'initialiser GwAu3. Vérifier que GW tourne bien.")
        Exit
    EndIf

    ConsoleWrite("[MAIN] Bot JQ initialisé avec succès !" & @CRLF)
    ConsoleWrite("[MAIN] Hook MainStart    = " & Memory_GetValue('MainStart') & @CRLF)
    ConsoleWrite("[MAIN] CommandMove       = " & Memory_GetValue('CommandMove') & @CRLF)
    ConsoleWrite("[MAIN] QueueBase         = " & Memory_GetValue('QueueBase') & @CRLF)
    ConsoleWrite("[MAIN] Move (GW fn)      = " & Memory_GetValue('Move') & @CRLF)
    ConsoleWrite("[MAIN] ChangeTarget      = " & Memory_GetValue('ChangeTarget') & @CRLF)
    ConsoleWrite("[MAIN] UseSkill          = " & Memory_GetValue('UseSkill') & @CRLF)

    While 1
        Sleep(100)
        If $boolRun Then
            Local $instanceType = Map_GetInstanceInfo("Type")
            Local $currentMap = Map_GetCharacterInfo("MapID")

            ; Pendant le chargement, on attend sans rien faire
            If $instanceType = $GC_I_MAP_TYPE_LOADING Then
                ConsoleWrite("[LOOP] Map en cours de chargement, attente..." & @CRLF)
                Sleep(1000)
                ContinueLoop
            EndIf

            Local $myID = Agent_GetMyID()
            ConsoleWrite("[LOOP] MyID=" & $myID & "  MapID=" & $currentMap & "  InstanceType=" & $instanceType & @CRLF)

            ; MyID=0 hors chargement = vrai problème (déco ou perso non init)
            If $myID = 0 Then
                ConsoleWrite("[LOOP] Personnage non détecté (MyID=0), attente 3s..." & @CRLF)
                Sleep(3000)
                ; Deuxième vérification avant de tenter reconnexion
                If Agent_GetMyID() = 0 Then
                    ConsoleWrite("[LOOP] Toujours non détecté, tentative reconnexion." & @CRLF)
                    ControlSend($hWnd, "", "", "{Enter}")
                    Sleep(7000)
                EndIf
                ContinueLoop
            EndIf

            Select
                Case $currentMap = $JadeQuarryArenaID And $instanceType = $GC_I_MAP_TYPE_EXPLORABLE
                    ConsoleWrite("[LOOP] -> ArenaLogic" & @CRLF)
                    ArenaLogic()
                Case $currentMap = $JadeQuarryKurzickID Or $currentMap = $JadeQuarryLuxonID
                    ConsoleWrite("[LOOP] -> OutpostLogic (map=" & $currentMap & ")" & @CRLF)
                    OutpostLogic($currentMap)
                Case Else
                    ConsoleWrite("[LOOP] Carte inconnue (MapID=" & $currentMap & "). En attente..." & @CRLF)
                    Sleep(5000)
            EndSelect
        Else
            Sleep(500)
        EndIf
    WEnd
EndFunc

Func ArenaLogic()
    ConsoleWrite("[ARENA] Entrée en zone de combat." & @CRLF)

    ; Diagnostic HandleCase : confirme quel chemin GW prend dans le hook
    Local $l_bp = Memory_Read(Memory_GetValue('BasePointer'))
    If $l_bp <> 0 Then
        Local $l_bp1 = Memory_Read($l_bp)
        If $l_bp1 <> 0 Then
            Local $l_bp2 = Memory_Read($l_bp1 + 0x18)
            If $l_bp2 <> 0 Then
                Local $l_bp3 = Memory_Read($l_bp2 + 0x44)
                If $l_bp3 <> 0 Then
                    Local $l_pidx = Memory_Read($l_bp3 + 0x198)
                    Local $l_pidx2 = Memory_Read($l_bp3 + 0x19C)
                    ConsoleWrite("[ARENA] HandleCheck: PlayerIndex[+0x198]=" & $l_pidx & "  [+0x19C]=" & Hex($l_pidx2, 8) & @CRLF)
                    If $l_pidx > 0 Then
                        Local $l_env = Memory_Read(Memory_GetValue('Environment') + $l_pidx * 0x7C + 0x10)
                        ConsoleWrite("[ARENA] HandleCheck: EnvFlags=0x" & Hex($l_env, 8) & "  bit0x40001=" & (BitAND($l_env, 0x40001) <> 0 ? "SET -> HandleCase (commandes IGNORÉES)" : "CLEAR -> RegularFlow (commandes OK)") & @CRLF)
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf

    Local $RandomPortal = ($PlayingFor = "Kurzick") ? Random(0, 2, 1) : Random(3, 5, 1)
    ConsoleWrite("[ARENA] Faction=" & $PlayingFor & "  Portail choisi=" & $RandomPortal & @CRLF)
    GoPortal($RandomPortal)

    ConsoleWrite("[ARENA] Portail atteint, début de la boucle de combat." & @CRLF)

    While Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID And Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_EXPLORABLE And $boolRun
        Sleep(250)

        Local $myID = Agent_GetMyID()
        Local $isDead = Agent_GetAgentInfo($myID, "IsDead")
        Local $myHP = Agent_GetAgentInfo($myID, "HP")
        ConsoleWrite("[ARENA] MyID=" & $myID & "  HP=" & Round($myHP, 2) & "  IsDead=" & $isDead & @CRLF)

        If $isDead Then
            ConsoleWrite("[ARENA] Personnage mort, attente de résurrection..." & @CRLF)

            Local $tRes = TimerInit()
            Do
                Sleep(500)
                $isDead = Agent_GetAgentInfo($myID, "IsDead")
                ConsoleWrite("[ARENA] Attente résurrection... " & Round(TimerDiff($tRes) / 1000) & "s" & @CRLF)
            Until Not $isDead Or TimerDiff($tRes) > 30000 Or Map_GetCharacterInfo("MapID") <> $JadeQuarryArenaID

            If Not $isDead And Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID Then
                ConsoleWrite("[ARENA] Ressuscité, retour vers un portail." & @CRLF)
                $RandomPortal = ($PlayingFor = "Kurzick") ? Random(0, 2, 1) : Random(3, 5, 1)
                GoPortal($RandomPortal)
            EndIf
            ContinueLoop
        EndIf

        Local $target = JQ_GetPriorityTarget()
        ConsoleWrite("[ARENA] Cible prioritaire : " & $target & @CRLF)

        If $target > 0 Then
            Local $myX = Agent_GetAgentInfo($myID, "X")
            Local $myY = Agent_GetAgentInfo($myID, "Y")
            Local $tX = Agent_GetAgentInfo($target, "X")
            Local $tY = Agent_GetAgentInfo($target, "Y")
            Local $dist = ComputeDistance($myX, $myY, $tX, $tY)
            ConsoleWrite("[ARENA] Cible " & $target & " dist=" & Round($dist) & "  pos=(" & Round($tX) & "," & Round($tY) & ")" & @CRLF)

            If $dist > 1000 Then
                ConsoleWrite("[ARENA] Déplacement vers cible" & @CRLF)
                Move($tX, $tY, 30)
            Else
                ConsoleWrite("[ARENA] À portée, ciblage + cast" & @CRLF)
                Agent_ChangeTarget($target)
                SmartCast()
            EndIf
        Else
            Local $quarry = CheckQuarry()
            ConsoleWrite("[ARENA] Pas de cible. CheckQuarry=" & $quarry & @CRLF)
            If $quarry < 3 Then
                MoveToQuarry($quarry)
            Else
                ; Aucune carrière à portée : se diriger vers la plus proche non cappée
                Local $myX2 = Agent_GetAgentInfo($myID, "X")
                Local $myY2 = Agent_GetAgentInfo($myID, "Y")
                Local $nearestDist = 999999, $nearestIdx = -1
                For $si = 0 To 2
                    If $si = 0 And $PurpleCapped Then ContinueLoop
                    If $si = 1 And $YellowCapped Then ContinueLoop
                    If $si = 2 And $GreenCapped Then ContinueLoop
                    Local $sDist = ComputeDistance($myX2, $myY2, $aShrines[$si][0], $aShrines[$si][1])
                    ConsoleWrite("[ARENA] Shrine " & $si & " dist=" & Round($sDist) & @CRLF)
                    If $sDist < $nearestDist Then
                        $nearestDist = $sDist
                        $nearestIdx = $si
                    EndIf
                Next
                If $nearestIdx >= 0 Then
                    ConsoleWrite("[ARENA] Repli vers shrine " & $nearestIdx & " (dist=" & Round($nearestDist) & ")" & @CRLF)
                    MoveToQuarry($nearestIdx)
                EndIf
            EndIf
        EndIf
    WEnd

    ConsoleWrite("[ARENA] Sortie de l'arène détectée." & @CRLF)
    GameOver()
EndFunc

Func OutpostLogic($mapId)
    $PlayingFor = ($mapId = $JadeQuarryKurzickID) ? "Kurzick" : "Luxon"
    ConsoleWrite("[OUTPOST] Mode Ville : " & $PlayingFor & "  (MapID=" & $mapId & ")" & @CRLF)

    Sleep(3000)

    If Map_GetCharacterInfo("MapID") <> $mapId Then Return

    ; Échange de faction avant de relancer un match
    ConsoleWrite("[OUTPOST] Échange faction Impériale -> Balthazar..." & @CRLF)
    TradeImperialX()

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        ConsoleWrite("[OUTPOST] Match démarré pendant TradeImperialX, abandon échanges." & @CRLF)
        Return
    EndIf

    ConsoleWrite("[OUTPOST] Achat de Zkeys avec la faction Balthazar..." & @CRLF)
    TradeBalthazarX()

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        ConsoleWrite("[OUTPOST] Match démarré pendant TradeBalthazarX." & @CRLF)
        Return
    EndIf

    ; Rejoindre la file d'attente du match
    ConsoleWrite("[OUTPOST] Inscription en file d'attente (Map_EnterChallenge)..." & @CRLF)
    Map_EnterChallenge(False)
    ConsoleWrite("[OUTPOST] En file d'attente. Attente du match..." & @CRLF)

    Local $tRequeue = TimerInit()
    While Map_GetCharacterInfo("MapID") = $mapId And $boolRun
        Sleep(2000)
        If TimerDiff($tRequeue) > 60000 Then
            ConsoleWrite("[OUTPOST] Réinscription en file (60s sans match)..." & @CRLF)
            Map_EnterChallenge(False)
            $tRequeue = TimerInit()
        EndIf
    WEnd

    ConsoleWrite("[OUTPOST] Sortie file d'attente. MapID=" & Map_GetCharacterInfo("MapID") & @CRLF)
EndFunc

Func GameOver()
    $iTotalRuns += 1
    ConsoleWrite("[GAMEOVER] Match fini. Total parties : " & $iTotalRuns & @CRLF)
    Sleep(5000)
EndFunc

Func TrayHandler()
    Switch (@TRAY_ID)
        Case $StartProgram
            $boolRun = Not $boolRun
            TrayItemSetText($StartProgram, $boolRun ? "Arrêter après le match" : "Relancer le bot JQ")
        Case $tExit
            Exit
    EndSwitch
EndFunc
