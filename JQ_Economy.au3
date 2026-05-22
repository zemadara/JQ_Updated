#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

Func _Trade_FindNearestNPC($targetX, $targetY, $maxDist = 600)
    Local $bestId = 0, $bestDist = $maxDist
    Local $maxAgents = Agent_GetMaxAgents()

    For $i = 1 To $maxAgents
        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        If $allegiance <> $GC_I_ALLEGIANCE_NPC Then ContinueLoop

        Local $isDead = Agent_GetAgentInfo($i, "IsDead")
        If $isDead Then ContinueLoop

        Local $nX = Agent_GetAgentInfo($i, "X")
        Local $nY = Agent_GetAgentInfo($i, "Y")
        Local $dist = ComputeDistance($nX, $nY, $targetX, $targetY)

        Local $mid = Agent_GetAgentInfo($i, "ModelID")
        JQ_Log("[TRADE] NPC " & $i & "  ModelID=" & $mid & "  dist=" & Round($dist) & "  pos=(" & Round($nX) & "," & Round($nY) & ")")

        If $dist < $bestDist Then
            $bestDist = $dist
            $bestId = $i
        EndIf
    Next

    Return $bestId
EndFunc

Func TradeImperialX()
    JQ_Log("[TRADE] Starting TradeImperialX...")
    Local $currentMap = Map_GetCharacterInfo("MapID")
    JQ_Log("[TRADE] MapID=" & $currentMap)

    Local $npcX, $npcY
    If $currentMap = 296 Then
        $npcX = -3298
        $npcY = -7560
    ElseIf $currentMap = 295 Then
        $npcX = 2472
        $npcY = 11757
    Else
        JQ_Log("[TRADE] Unknown MapID, aborting TradeImperialX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Moving to faction officer (" & $npcX & "," & $npcY & ")")
    JQ_MoveTo($npcX, $npcY, 400, 20000)

    Local $npcId = _Trade_FindNearestNPC($npcX, $npcY, 600)
    JQ_Log("[TRADE] Faction officer ID=" & $npcId)

    If $npcId = 0 Then
        JQ_Log("[TRADE] No NPC found near officer coords.")
        Return False
    EndIf

    JQ_Log("[TRADE] Interacting with officer ID=" & $npcId)
    Agent_GoNPC($npcId)

    Local $tWalkImp = TimerInit()
    Do
        Sleep(300)
        Local $myXImp = Agent_GetAgentInfo(-2, "X")
        Local $myYImp = Agent_GetAgentInfo(-2, "Y")
        Local $nXImp  = Agent_GetAgentInfo($npcId, "X")
        Local $nYImp  = Agent_GetAgentInfo($npcId, "Y")
        Local $dImp   = ComputeDistance($myXImp, $myYImp, $nXImp, $nYImp)
        JQ_Log("[TRADE] Approaching officer... dist=" & Round($dImp))
    Until $dImp < 250 Or TimerDiff($tWalkImp) > 20000 Or Map_GetCharacterInfo("MapID") <> $currentMap

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        JQ_Log("[TRADE] Map changed during officer approach, aborting TradeImperialX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Dialog 0x97 (trade Imperial -> Balthazar)")
    Game_Dialog(0x97)
    Sleep(1500)

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        JQ_Log("[TRADE] Map changed after 0x97, aborting TradeImperialX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Dialog 0xA3 (confirm trade all)")
    Game_Dialog(0xA3)
    Sleep(2000)

    JQ_Log("[TRADE] TradeImperialX done.")
    Return True
EndFunc

; Finds and interacts with the competitive mission entry (registrar NPC or portal gadget).
; Excludes the two known trade NPCs. Scan logs reveal the exact MID/GadgetID for hardcoding later.
Func JQ_JoinQueue($mapId)
    JQ_Log("[QUEUE] Scanning outpost for competitive entry agent...")

    Local $officerX, $officerY, $tolkanoX, $tolkanoY
    If $mapId = 296 Then
        $officerX = -3298 : $officerY = -7560
        $tolkanoX  = -2643 : $tolkanoY  = -6842
    Else
        $officerX = 2472 : $officerY = 11757
        $tolkanoX  = 3585 : $tolkanoY  = 13641
    EndIf

    JQ_ScanArea(15000)

    ; Find nearest NPC or gadget that is NOT one of the known trade NPCs.
    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    Local $bestId = 0, $bestDist = 15000

    For $i = 1 To Agent_GetMaxAgents()
        If $i = $myID Then ContinueLoop
        If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        Local $aType = Agent_GetAgentInfo($i, "Type")
        If $allegiance <> $GC_I_ALLEGIANCE_NPC And $aType <> $GC_I_AGENT_TYPE_GADGET Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        If ComputeDistance($aX, $aY, $officerX, $officerY) < 500 Then ContinueLoop
        If ComputeDistance($aX, $aY, $tolkanoX, $tolkanoY) < 500 Then ContinueLoop
        Local $d = ComputeDistance($myX, $myY, $aX, $aY)
        If $d < $bestDist Then
            $bestDist = $d
            $bestId = $i
        EndIf
    Next

    If $bestId = 0 Then
        JQ_Log("[QUEUE] No registrar/portal found. Waiting for map change passively.")
        Return
    EndIf

    Local $rX = Agent_GetAgentInfo($bestId, "X")
    Local $rY = Agent_GetAgentInfo($bestId, "Y")
    JQ_Log("[QUEUE] Candidate: #" & $bestId & "  MID=" & Agent_GetAgentInfo($bestId, "ModelID") & "  GadgetID=" & Agent_GetAgentInfo($bestId, "GadgetID") & "  pos=(" & Round($rX) & "," & Round($rY) & ")")
    JQ_MoveTo($rX, $rY, 300, 20000)
    JQ_Interact($bestId)
    JQ_Log("[QUEUE] Interaction sent.")
EndFunc

Func TradeBalthazarX()
    JQ_Log("[TRADE] Starting TradeBalthazarX...")
    Local $currentMap = Map_GetCharacterInfo("MapID")
    JQ_Log("[TRADE] MapID=" & $currentMap)

    Local $tolkanoX, $tolkanoY
    If $currentMap = 296 Then
        $tolkanoX = -2643
        $tolkanoY = -6842
    ElseIf $currentMap = 295 Then
        $tolkanoX = 3585
        $tolkanoY = 13641
    Else
        JQ_Log("[TRADE] Unknown MapID, aborting TradeBalthazarX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Moving to Tolkano (" & $tolkanoX & "," & $tolkanoY & ")")
    JQ_MoveTo($tolkanoX, $tolkanoY, 400, 20000)

    Local $tolkanoId = _Trade_FindNearestNPC($tolkanoX, $tolkanoY, 1500)
    JQ_Log("[TRADE] Tolkano ID=" & $tolkanoId)

    If $tolkanoId = 0 Then
        JQ_Log("[TRADE] Tolkano not found.")
        Return False
    EndIf

    JQ_Log("[TRADE] Interacting with Tolkano ID=" & $tolkanoId)
    Agent_GoNPC($tolkanoId)

    Local $tWalkTol = TimerInit()
    Do
        Sleep(300)
        Local $myXTol = Agent_GetAgentInfo(-2, "X")
        Local $myYTol = Agent_GetAgentInfo(-2, "Y")
        Local $nXTol  = Agent_GetAgentInfo($tolkanoId, "X")
        Local $nYTol  = Agent_GetAgentInfo($tolkanoId, "Y")
        Local $dTol   = ComputeDistance($myXTol, $myYTol, $nXTol, $nYTol)
        JQ_Log("[TRADE] Approaching Tolkano... dist=" & Round($dTol))
    Until $dTol < 250 Or TimerDiff($tWalkTol) > 20000 Or Map_GetCharacterInfo("MapID") <> $currentMap

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        JQ_Log("[TRADE] Map changed during Tolkano approach, aborting TradeBalthazarX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Dialog 0x87 (buy Zkey)")
    Game_Dialog(0x87)
    Sleep(1500)

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        JQ_Log("[TRADE] Map changed after 0x87, aborting TradeBalthazarX.")
        Return False
    EndIf

    JQ_Log("[TRADE] Dialog 0x88 (confirm purchase)")
    Game_Dialog(0x88)
    Sleep(2000)

    JQ_Log("[TRADE] TradeBalthazarX done.")
    Return True
EndFunc
