#RequireAdmin
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=n
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include-once
#include <Date.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

; --- LIAISON AVEC LA LIBRAIRIE GWAU3 ---
#include "..\GwAu3-main\API\_GwAu3.au3"

; --- Variables Globales (déclarées AVANT les modules qui les utilisent) ---
Global $boolRun = False  ; mis à True par le bouton Run dans la GUI
Global $PlayingFor = "Kurzick"
Global $iTotalRuns = 0
Global $MyTotalZkeys = 0
Global $MID_Zkey = 28517

; Identifiants des cartes Jade Quarry
Global Const $JadeQuarryKurzickID = 296
Global Const $JadeQuarryLuxonID = 295
Global Const $JadeQuarryArenaID = 223

; --- INCLUSION DES MODULES JQ ---
#include "JQ_GUI.au3"
#include "JQ_Movement.au3"
#include "JQ_Combat.au3"
#include "JQ_Quarry.au3"
#include "JQ_Economy.au3"

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
    JQ_GUI_Create()
    JQ_Log("[MAIN] Démarrage du bot JQ...")

    Local $hWnd = WinGetHandle("Guild Wars")
    If Not $hWnd Then
        MsgBox(16, "Erreur", "Guild Wars n'est pas lancé.")
        Exit
    EndIf
    JQ_Log("[MAIN] Fenêtre Guild Wars trouvée : handle=" & $hWnd)

    Local $l_a_PID = DllCall("user32.dll", "dword", "GetWindowThreadProcessId", "hwnd", $hWnd, "dword*", 0)
    Local $l_pid = $l_a_PID[2]
    JQ_Log("[MAIN] PID Guild Wars : " & $l_pid)
    If $l_pid = 0 Then
        MsgBox(16, "Erreur", "Impossible de récupérer le PID de Guild Wars.")
        Exit
    EndIf

    JQ_Log("[MAIN] Initialisation GwAu3...")
    Local $initResult = Core_Initialize($l_pid)
    JQ_Log("[MAIN] Résultat Core_Initialize : " & $initResult)
    If Not $initResult Then
        MsgBox(16, "Erreur", "Impossible d'initialiser GwAu3. Vérifier que GW tourne bien.")
        Exit
    EndIf

    $g_bGwInitialized = True
    JQ_Log("[MAIN] Bot JQ initialisé avec succès !")

    While 1
        Sleep(100)
        If $boolRun Then
            Local $instanceType = Map_GetInstanceInfo("Type")
            Local $currentMap = Map_GetCharacterInfo("MapID")

            If $instanceType = $GC_I_MAP_TYPE_LOADING Then
                Sleep(1000)
                ContinueLoop
            EndIf

            Local $myID = Agent_GetMyID()

            If $myID = 0 Then
                JQ_Log("[LOOP] Personnage non détecté (MyID=0), attente 3s...")
                Sleep(3000)
                If Agent_GetMyID() = 0 Then
                    JQ_Log("[LOOP] Toujours non détecté, tentative reconnexion.")
                    ControlSend($hWnd, "", "", "{Enter}")
                    Sleep(7000)
                EndIf
                ContinueLoop
            EndIf

            Select
                Case $currentMap = $JadeQuarryArenaID And $instanceType = $GC_I_MAP_TYPE_EXPLORABLE
                    JQ_Log("[LOOP] -> ArenaLogic")
                    ArenaLogic()
                Case $currentMap = $JadeQuarryKurzickID Or $currentMap = $JadeQuarryLuxonID
                    JQ_Log("[LOOP] -> OutpostLogic (map=" & $currentMap & ")")
                    OutpostLogic($currentMap)
                Case Else
                    JQ_Log("[LOOP] Carte inconnue (MapID=" & $currentMap & "). En attente...")
                    Sleep(5000)
            EndSelect
        Else
            Sleep(500)
        EndIf
    WEnd
EndFunc

Func ArenaLogic()
    JQ_Log("[ARENA] Entrée en zone de combat.")

    Local $RandomPortal = ($PlayingFor = "Kurzick") ? Random(0, 2, 1) : Random(3, 5, 1)
    JQ_Log("[ARENA] Faction=" & $PlayingFor & "  Portail choisi=" & $RandomPortal)
    GoPortal($RandomPortal)

    JQ_Log("[ARENA] Portail atteint, début de la boucle de combat.")

    While Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID And Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_EXPLORABLE And $boolRun
        Sleep(250)

        Local $myID = Agent_GetMyID()
        Local $isDead = Agent_GetAgentInfo($myID, "IsDead")

        If $isDead Then
            JQ_Log("[ARENA] Personnage mort, attente de résurrection...")
            Local $tRes = TimerInit()
            Do
                Sleep(500)
                $isDead = Agent_GetAgentInfo($myID, "IsDead")
            Until Not $isDead Or TimerDiff($tRes) > 30000 Or Map_GetCharacterInfo("MapID") <> $JadeQuarryArenaID

            If Not $isDead And Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID Then
                JQ_Log("[ARENA] Ressuscité, retour vers un portail.")
                $RandomPortal = ($PlayingFor = "Kurzick") ? Random(0, 2, 1) : Random(3, 5, 1)
                GoPortal($RandomPortal)
            EndIf
            ContinueLoop
        EndIf

        Local $target = JQ_GetPriorityTarget()

        If $target > 0 Then
            Local $myX = Agent_GetAgentInfo($myID, "X")
            Local $myY = Agent_GetAgentInfo($myID, "Y")
            Local $tX = Agent_GetAgentInfo($target, "X")
            Local $tY = Agent_GetAgentInfo($target, "Y")
            Local $dist = ComputeDistance($myX, $myY, $tX, $tY)

            If $dist > 1000 Then
                JQ_MoveTo($tX, $tY, 600, 8000)
            Else
                Agent_ChangeTarget($target)
                SmartCast()
            EndIf
        Else
            Local $quarry = CheckQuarry()
            If $quarry < 3 Then
                MoveToQuarry($quarry)
            Else
                Local $myX2 = Agent_GetAgentInfo($myID, "X")
                Local $myY2 = Agent_GetAgentInfo($myID, "Y")
                Local $nearestDist = 999999, $nearestIdx = -1
                For $si = 0 To 2
                    If $si = 0 And $PurpleCapped Then ContinueLoop
                    If $si = 1 And $YellowCapped Then ContinueLoop
                    If $si = 2 And $GreenCapped Then ContinueLoop
                    Local $sDist = ComputeDistance($myX2, $myY2, $aShrines[$si][0], $aShrines[$si][1])
                    If $sDist < $nearestDist Then
                        $nearestDist = $sDist
                        $nearestIdx = $si
                    EndIf
                Next
                If $nearestIdx >= 0 Then
                    JQ_Log("[ARENA] Repli vers shrine " & $nearestIdx)
                    MoveToQuarry($nearestIdx)
                EndIf
            EndIf
        EndIf
    WEnd

    JQ_Log("[ARENA] Sortie de l'arène détectée.")
    GameOver()
EndFunc

Func OutpostLogic($mapId)
    $PlayingFor = ($mapId = $JadeQuarryKurzickID) ? "Kurzick" : "Luxon"
    JQ_Log("[OUTPOST] Mode Ville : " & $PlayingFor & "  (MapID=" & $mapId & ")")

    Sleep(3000)

    If Map_GetCharacterInfo("MapID") <> $mapId Then Return

    JQ_Log("[OUTPOST] Échange faction Impériale -> Balthazar...")
    TradeImperialX()

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        JQ_Log("[OUTPOST] Match démarré pendant TradeImperialX, abandon échanges.")
        Return
    EndIf

    JQ_Log("[OUTPOST] Achat de Zkeys avec la faction Balthazar...")
    Local $iZkeyBefore = Item_GetItemInfoByModelID($MID_Zkey, "Quantity")
    TradeBalthazarX()
    Local $iZkeyAfter = Item_GetItemInfoByModelID($MID_Zkey, "Quantity")
    If $iZkeyAfter > $iZkeyBefore Then
        $MyTotalZkeys += ($iZkeyAfter - $iZkeyBefore)
        JQ_Log("[OUTPOST] " & ($iZkeyAfter - $iZkeyBefore) & " Zkey(s) obtenus. Total session : " & $MyTotalZkeys)
    EndIf

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        JQ_Log("[OUTPOST] Match démarré pendant TradeBalthazarX.")
        Return
    EndIf

    JQ_Log("[OUTPOST] Inscription en file d'attente...")
    Map_EnterChallenge(False)
    JQ_Log("[OUTPOST] En file d'attente. Attente du match...")

    Local $tRequeue = TimerInit()
    While Map_GetCharacterInfo("MapID") = $mapId And $boolRun
        Sleep(2000)
        If TimerDiff($tRequeue) > 60000 Then
            JQ_Log("[OUTPOST] Réinscription en file (60s sans match)...")
            Map_EnterChallenge(False)
            $tRequeue = TimerInit()
        EndIf
    WEnd

    JQ_Log("[OUTPOST] Sortie file d'attente. MapID=" & Map_GetCharacterInfo("MapID"))
EndFunc

Func GameOver()
    $iTotalRuns += 1
    JQ_Log("[GAMEOVER] Match fini. Total parties : " & $iTotalRuns)
    Sleep(5000)
EndFunc

#EndRegion
