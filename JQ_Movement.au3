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
#EndRegion

Func ComputeDistance($x1, $y1, $x2, $y2)
    Return Sqrt(($x1 - $x2) ^ 2 + ($y1 - $y2) ^ 2)
EndFunc

; Logs all non-enemy agents within $maxDist. Used to identify portal/registrar IDs.
Func JQ_ScanArea($maxDist = 3000)
    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    JQ_Log("[SCAN] pos=(" & Round($myX) & "," & Round($myY) & ")  radius=" & $maxDist)
    For $i = 1 To Agent_GetMaxAgents()
        If $i = $myID Then ContinueLoop
        If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        If $allegiance = $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        Local $dist = ComputeDistance($myX, $myY, $aX, $aY)
        If $dist > $maxDist Then ContinueLoop
        Local $aType = Agent_GetAgentInfo($i, "Type")
        Local $modelId = Agent_GetAgentInfo($i, "ModelID")
        Local $gadgetId = Agent_GetAgentInfo($i, "GadgetID")
        JQ_Log("[SCAN] #" & $i & "  Type=0x" & Hex($aType) & "  Allg=" & $allegiance & "  MID=" & $modelId & "  GadgetID=" & $gadgetId & "  pos=(" & Round($aX) & "," & Round($aY) & ")  dist=" & Round($dist))
    Next
EndFunc

; Returns nearest NPC (allegiance 6) or gadget agent within $maxDist of ($fRefX, $fRefY).
Func JQ_FindNearestInteractable($fRefX, $fRefY, $maxDist = 800)
    Local $nearId = 0, $nearDist = $maxDist
    For $i = 1 To Agent_GetMaxAgents()
        If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        Local $aType = Agent_GetAgentInfo($i, "Type")
        If $allegiance <> $GC_I_ALLEGIANCE_NPC And $aType <> $GC_I_AGENT_TYPE_GADGET Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        Local $d = ComputeDistance($fRefX, $fRefY, $aX, $aY)
        If $d < $nearDist Then
            $nearDist = $d
            $nearId = $i
        EndIf
    Next
    Return $nearId
EndFunc

; Interacts with an NPC or gadget agent (GoNPC or GoSignpost depending on type).
Func JQ_Interact($agentId)
    If $agentId <= 0 Then Return False
    Local $aType = Agent_GetAgentInfo($agentId, "Type")
    JQ_Log("[INTERACT] #" & $agentId & "  Type=0x" & Hex($aType) & "  MID=" & Agent_GetAgentInfo($agentId, "ModelID") & "  GadgetID=" & Agent_GetAgentInfo($agentId, "GadgetID"))
    If $aType = $GC_I_AGENT_TYPE_GADGET Then
        Return Agent_GoSignpost($agentId)
    Else
        Return Agent_GoNPC($agentId)
    EndIf
EndFunc

; Moves to ($fX, $fY) using velocity-based stuck detection.
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
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_LOADING Then
            JQ_Log("[MOVETO] Aborting - map loading.")
            Return False
        EndIf
        If Agent_GetAgentInfo($myID, "HP") <= 0 Then
            JQ_Log("[MOVETO] Aborting - HP=0.")
            Return False
        EndIf
        If TimerDiff($tTimer) > $iTimeout Then
            JQ_Log("[MOVETO] Timeout for (" & Round($fX) & "," & Round($fY) & ")")
            Return False
        EndIf

        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $dist = ComputeDistance($myX, $myY, $fX, $fY)

        If $dist < $iArrivalDist Then
            JQ_Log("[MOVETO] Arrived (dist=" & Round($dist) & " < " & $iArrivalDist & ")")
            ExitLoop
        EndIf

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

; Moves to arena portal $iPortal and waits for the automatic teleport.
Func GoPortal($iPortal)
    Local $pX = $aPortals[$iPortal][0]
    Local $pY = $aPortals[$iPortal][1]
    JQ_Log("[PORTAL] Moving to portal #" & $iPortal & "  target=(" & $pX & "," & $pY & ")")

    JQ_MoveTo($pX, $pY, 500, 25000)

    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    JQ_Log("[PORTAL] At portal area  pos=(" & Round($myX) & "," & Round($myY) & ")  Waiting for teleport...")

    ; Wait up to 10s — teleport is detected as a position jump > 1000 units.
    Local $tWait = TimerInit()
    While TimerDiff($tWait) < 10000
        Sleep(250)
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_LOADING Then Return
        If Map_GetCharacterInfo("MapID") <> $JadeQuarryArenaID Then Return
        Local $newX = Agent_GetAgentInfo($myID, "X")
        Local $newY = Agent_GetAgentInfo($myID, "Y")
        If ComputeDistance($myX, $myY, $newX, $newY) > 1000 Then
            JQ_Log("[PORTAL] Teleported to (" & Round($newX) & "," & Round($newY) & ")")
            Return
        EndIf
    WEnd
    JQ_Log("[PORTAL] No teleport after 10s, continuing.")
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
