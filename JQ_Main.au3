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

#include "..\GwAu3-main\API\_GwAu3.au3"

; --- Globals ---
Global $boolRun = False  ; set to True by the Run button in the GUI
Global $PlayingFor = "Kurzick"
Global $iTotalRuns = 0
Global $MyTotalZkeys = 0
Global $MID_Zkey = 28517

Global Const $JadeQuarryKurzickID = 296
Global Const $JadeQuarryLuxonID = 295
Global Const $JadeQuarryArenaID = 223

#include "JQ_GUI.au3"
#include "JQ_Movement.au3"
#include "JQ_Combat.au3"
#include "JQ_Quarry.au3"
#include "JQ_Economy.au3"

; ---------------------------------------------------------------------------
; Stubs required by AU3Check (GwAu3 optional hooks — never called in practice)
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

#Region - Main Logic

Func Main()
    JQ_GUI_Create()
    JQ_Log("[MAIN] Starting JQ bot...")

    Local $hWnd = WinGetHandle("Guild Wars")
    If Not $hWnd Then
        MsgBox(16, "Error", "Guild Wars is not running.")
        Exit
    EndIf
    JQ_Log("[MAIN] Guild Wars window found: handle=" & $hWnd)

    Local $l_a_PID = DllCall("user32.dll", "dword", "GetWindowThreadProcessId", "hwnd", $hWnd, "dword*", 0)
    Local $l_pid = $l_a_PID[2]
    JQ_Log("[MAIN] Guild Wars PID: " & $l_pid)
    If $l_pid = 0 Then
        MsgBox(16, "Error", "Failed to retrieve Guild Wars PID.")
        Exit
    EndIf

    JQ_Log("[MAIN] Initializing GwAu3...")
    Local $initResult = Core_Initialize($l_pid)
    JQ_Log("[MAIN] Core_Initialize result: " & $initResult)
    If Not $initResult Then
        MsgBox(16, "Error", "Failed to initialize GwAu3. Make sure Guild Wars is running.")
        Exit
    EndIf

    $g_bGwInitialized = True
    JQ_Log("[MAIN] JQ bot initialized successfully.")

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
                JQ_Log("[LOOP] Character not detected (MyID=0), waiting 3s...")
                Sleep(3000)
                If Agent_GetMyID() = 0 Then
                    JQ_Log("[LOOP] Still not detected, attempting reconnect.")
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
                    JQ_Log("[LOOP] Unknown map (MapID=" & $currentMap & "). Waiting...")
                    Sleep(5000)
            EndSelect
        Else
            Sleep(500)
        EndIf
    WEnd
EndFunc

Func ArenaLogic()
    JQ_Log("[ARENA] Entered combat zone, waiting for agents to initialize...")
    Sleep(3000)

    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    JQ_Log("[ARENA] MyID=" & $myID & "  pos=(" & Round($myX) & "," & Round($myY) & ")  MapType=" & Map_GetInstanceInfo("Type"))

    Local $RandomPortal = ($PlayingFor = "Kurzick") ? Random(0, 2, 1) : Random(3, 5, 1)
    JQ_Log("[ARENA] Side=" & $PlayingFor & "  Portal=" & $RandomPortal)
    GoPortal($RandomPortal)

    JQ_Log("[ARENA] Portal reached, starting combat loop.")

    While Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID And Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_EXPLORABLE And $boolRun
        Sleep(250)

        Local $myID = Agent_GetMyID()
        Local $isDead = Agent_GetAgentInfo($myID, "IsDead")

        If $isDead Then
            JQ_Log("[ARENA] Dead, waiting for resurrection...")
            Local $tRes = TimerInit()
            Do
                Sleep(500)
                $isDead = Agent_GetAgentInfo($myID, "IsDead")
            Until Not $isDead Or TimerDiff($tRes) > 30000 Or Map_GetCharacterInfo("MapID") <> $JadeQuarryArenaID

            If Not $isDead And Map_GetCharacterInfo("MapID") = $JadeQuarryArenaID Then
                JQ_Log("[ARENA] Resurrected, heading back to a portal.")
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
                    JQ_Log("[ARENA] Moving to nearest shrine " & $nearestIdx)
                    MoveToQuarry($nearestIdx)
                EndIf
            EndIf
        EndIf
    WEnd

    JQ_Log("[ARENA] Left arena.")
    GameOver()
EndFunc

Func OutpostLogic($mapId)
    $PlayingFor = ($mapId = $JadeQuarryKurzickID) ? "Kurzick" : "Luxon"
    JQ_Log("[OUTPOST] Side: " & $PlayingFor & "  (MapID=" & $mapId & ")")

    Sleep(3000)

    If Map_GetCharacterInfo("MapID") <> $mapId Then Return

    JQ_Log("[OUTPOST] Trading Imperial faction for Balthazar...")
    TradeImperialX()

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        JQ_Log("[OUTPOST] Match started during TradeImperialX, skipping trades.")
        Return
    EndIf

    JQ_Log("[OUTPOST] Buying Zkeys with Balthazar faction...")
    Local $iZkeyBefore = Item_GetItemInfoByModelID($MID_Zkey, "Quantity")
    TradeBalthazarX()
    Local $iZkeyAfter = Item_GetItemInfoByModelID($MID_Zkey, "Quantity")
    If $iZkeyAfter > $iZkeyBefore Then
        $MyTotalZkeys += ($iZkeyAfter - $iZkeyBefore)
        JQ_Log("[OUTPOST] " & ($iZkeyAfter - $iZkeyBefore) & " Zkey(s) obtained. Session total: " & $MyTotalZkeys)
    EndIf

    If Map_GetCharacterInfo("MapID") <> $mapId Then
        JQ_Log("[OUTPOST] Match started during TradeBalthazarX.")
        Return
    EndIf

    JQ_Log("[OUTPOST] Joining match queue...")
    Map_EnterChallenge(False)
    JQ_Log("[OUTPOST] In queue, waiting for match...")

    ; GW keeps the queue slot alive server-side — no need to re-send the packet.
    ; Sending EnterChallenge again while already queued causes a disconnect.
    While Map_GetCharacterInfo("MapID") = $mapId And $boolRun
        Sleep(2000)
    WEnd

    ; Paused while in queue: cancel the slot so the character doesn't enter
    ; a match uncontrolled while the bot is not running.
    If Map_GetCharacterInfo("MapID") = $mapId And Not $boolRun Then
        JQ_Log("[OUTPOST] Bot paused, cancelling queue slot.")
        Core_SendPacket(0x4, $GC_I_HEADER_PARTY_CANCEL_ENTER_CHALLENGE)
    EndIf

    JQ_Log("[OUTPOST] Left queue. MapID=" & Map_GetCharacterInfo("MapID"))
EndFunc

Func GameOver()
    $iTotalRuns += 1
    JQ_Log("[GAMEOVER] Match over. Total runs: " & $iTotalRuns)
    Sleep(5000)
EndFunc

#EndRegion
