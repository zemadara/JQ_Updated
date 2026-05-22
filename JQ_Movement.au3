#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

#Region - Movement globals
Global $CapThisQuarry
Global $PurpleCapped = False
Global $YellowCapped = False
Global $GreenCapped = False
Global $LastPortal = 10

Enum $SHRINE_PurpleQuarry = 1, $SHRINE_YellowQuarry, $SHRINE_GreenQuarry
Dim $aShrines[3][2] = [ [1579.7390, -2295.26], [-3034.230, 6240.510], [5249.4785, 1231.989] ]

Dim $aPortals[6][2] = [ [-4894, -1619], [-3680, -1760], [-3244, -2430], _
                        [5206, 6622], [4611, 6885], [4119, 8289] ]

Dim $aTeleports[6][2] = [ [-3290, 2400], [-295, 1125], [-650, -720], _
                          [3806, 3731], [1777, 3312], [667, 6432] ]
#EndRegion

Func ComputeDistance($x1, $y1, $x2, $y2)
    Return Sqrt(($x1 - $x2) ^ 2 + ($y1 - $y2) ^ 2)
EndFunc

; Moves to ($fX, $fY) using velocity-based stuck detection, mirroring
; the AddOns_MoveTo pattern from Encounter ReBuilt:
;   - Single initial Map_Move, re-issued whenever MoveX=0 and MoveY=0.
;   - At 10 stuck ticks: sends /stuck in GW chat.
;   - At 20 stuck ticks: aborts and returns False.
;   - $iTimeout (ms) prevents infinite loops on impassable geometry.
Func JQ_MoveTo($fX, $fY, $iArrivalDist = 200, $iTimeout = 30000)
    Local $myID = Agent_GetMyID()
    If $myID = 0 Then
        JQ_Log("[MOVETO] MyID=0, aborting.")
        Return False
    EndIf

    Local $tTimer = TimerInit()
    Local $iStuck = 0
    Local $bInitialMove = True

    Do
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_LOADING Then Return False
        If Agent_GetAgentInfo($myID, "IsDead") Then Return False
        If TimerDiff($tTimer) > $iTimeout Then
            JQ_Log("[MOVETO] Timeout reached for target=(" & Round($fX) & "," & Round($fY) & ")")
            Return False
        EndIf

        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $dist = ComputeDistance($myX, $myY, $fX, $fY)

        If $dist < $iArrivalDist Then ExitLoop

        If $bInitialMove Then
            $bInitialMove = False
            JQ_Log("[MOVETO] Map_Move -> (" & Round($fX) & "," & Round($fY) & ")  pos=(" & Round($myX) & "," & Round($myY) & ")  dist=" & Round($dist))
            Map_Move($fX, $fY)
            Sleep(250)
            ContinueLoop
        EndIf

        Local $mvX = Agent_GetAgentInfo($myID, "MoveX")
        Local $mvY = Agent_GetAgentInfo($myID, "MoveY")

        If $mvX = 0 And $mvY = 0 Then
            $iStuck += 1
            JQ_Log("[MOVETO] Stuck=" & $iStuck & "  pos=(" & Round($myX) & "," & Round($myY) & ")  dist=" & Round($dist))
            If $iStuck = 10 Then Chat_SendChat("stuck", "/")
            If $iStuck >= 40 Then Return False
            Map_Move($fX, $fY)
        Else
            $iStuck = 0
        EndIf

        Sleep(250)
    Until False

    Return True
EndFunc

; Navigates to portal $iPortal and waits for the teleport to trigger.
Func GoPortal($iPortal)
    Local $pX = $aPortals[$iPortal][0]
    Local $pY = $aPortals[$iPortal][1]
    JQ_Log("[PORTAL] Moving to portal #" & $iPortal & "  target=(" & $pX & "," & $pY & ")")

    Local $myID = Agent_GetMyID()
    Local $tMax = TimerInit()

    Do
        Local $mapType = Map_GetInstanceInfo("Type")
        If $mapType = $GC_I_MAP_TYPE_LOADING Then
            JQ_Log("[PORTAL] Map loading, aborting.")
            Return
        EndIf
        If $mapType = $GC_I_MAP_TYPE_OUTPOST Then
            JQ_Log("[PORTAL] Back in outpost, aborting.")
            Return
        EndIf
        If TimerDiff($tMax) > 120000 Then
            JQ_Log("[PORTAL] Timeout 120s, aborting.")
            Return
        EndIf

        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $distPortal   = ComputeDistance($myX, $myY, $pX, $pY)
        Local $distTeleport = ComputeDistance($myX, $myY, $aTeleports[$iPortal][0], $aTeleports[$iPortal][1])
        JQ_Log("[PORTAL] MapType=" & $mapType & "  pos=(" & Round($myX) & "," & Round($myY) & ")  distDoor=" & Round($distPortal) & "  distTeleport=" & Round($distTeleport))

        If $distTeleport < 400 Then
            JQ_Log("[PORTAL] Teleport destination reached (dist=" & Round($distTeleport) & "), exiting.")
            ExitLoop
        EndIf

        JQ_MoveTo($pX, $pY, 350, 12000)

    Until False

    JQ_Log("[PORTAL] Portal reached.")
EndFunc

; Returns the index of the nearest reachable uncapped quarry, or 50 if none.
Func CheckQuarry()
    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")

    For $iShrine = 0 To 2
        If $iShrine = 0 And $PurpleCapped Then ContinueLoop
        If $iShrine = 1 And $YellowCapped Then ContinueLoop
        If $iShrine = 2 And $GreenCapped Then ContinueLoop

        Local $dist = ComputeDistance($myX, $myY, $aShrines[$iShrine][0], $aShrines[$iShrine][1])
        If $dist < 4500 And $dist > 1000 Then
            If $iShrine + 1 = $SHRINE_PurpleQuarry Then $PurpleCapped = True
            If $iShrine + 1 = $SHRINE_YellowQuarry Then $YellowCapped = True
            If $iShrine + 1 = $SHRINE_GreenQuarry Then $GreenCapped = True
            Return $iShrine
        EndIf
    Next

    Return 50
EndFunc

; Moves toward quarry shrine $QuarryNumber.
Func MoveToQuarry($QuarryNumber)
    Local $lDestX = $aShrines[$QuarryNumber][0]
    Local $lDestY = $aShrines[$QuarryNumber][1]
    JQ_Log("[QUARRY] Moving to quarry " & $QuarryNumber & " -> (" & Round($lDestX) & "," & Round($lDestY) & ")")
    JQ_MoveTo($lDestX, $lDestY, 300, 20000)
EndFunc
