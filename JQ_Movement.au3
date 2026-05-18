#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

#Region - Variables de Mouvement
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

; Encode un float en sa représentation DWORD IEEE 754 (nécessaire pour Core_SendPacket).
Func _FloatToDword($fVal)
    Local $tF = DllStructCreate("float")
    DllStructSetData($tF, 1, $fVal)
    Return DllStructGetData(DllStructCreate("dword", DllStructGetPtr($tF)), 1)
EndFunc

; Envoie un paquet réseau de déplacement direct vers des coordonnées (header 0x003E).
; Même mécanisme que Agent_GoNPC — aucun agent requis à proximité.
Func Map_SendMoveCoord($fX, $fY)
    ConsoleWrite("[MOVECOORD] Paquet 0x003E vers (" & Round($fX) & "," & Round($fY) & ")" & @CRLF)
    Return Core_SendPacket(0xC, $GC_I_HEADER_PLAYER_MOVE_COORD, _FloatToDword($fX), _FloatToDword($fY))
EndFunc

; Déplace vers des coordonnées via l'agent non-ennemi le plus proche des coords cibles.
; Fallback Map_MoveLayer si aucun agent dans le rayon.
; Map_SendMoveCoord (paquet 0x003E) n'est PAS appelé ici — à tester séparément.
Func _GoToCoords($targetX, $targetY, $searchRadius = 3000)
    Local $myID = Agent_GetMyID()
    Local $curX = Agent_GetAgentInfo($myID, "X")
    Local $curY = Agent_GetAgentInfo($myID, "Y")
    ConsoleWrite("[GOTO] Perso=(" & Round($curX) & "," & Round($curY) & ")  Cible=(" & Round($targetX) & "," & Round($targetY) & ")  distCible=" & Round(ComputeDistance($curX, $curY, $targetX, $targetY)) & @CRLF)
    Local $bestId = 0, $bestDist = $searchRadius
    Local $maxAgents = Agent_GetMaxAgents()

    For $i = 1 To $maxAgents
        If $i = $myID Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        If $aX = 0 And $aY = 0 Then ContinueLoop
        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        If $allegiance = $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop
        Local $dist = ComputeDistance($aX, $aY, $targetX, $targetY)
        If $dist < $bestDist Then
            $bestDist = $dist
            $bestId = $i
        EndIf
    Next

    If $bestId > 0 Then
        Local $alleg = Agent_GetAgentInfo($bestId, "Allegiance")
        Local $aX2 = Agent_GetAgentInfo($bestId, "X")
        Local $aY2 = Agent_GetAgentInfo($bestId, "Y")
        ConsoleWrite("[GOTO] Agent cible: ID=" & $bestId & "  alleg=" & $alleg & "  dist=" & Round($bestDist) & "  pos=(" & Round($aX2) & "," & Round($aY2) & ")" & @CRLF)
        Select
            Case $alleg = $GC_I_ALLEGIANCE_NPC
                Agent_GoNPC($bestId)
            Case $alleg = $GC_I_ALLEGIANCE_ALLY
                Agent_GoPlayer($bestId)
            Case $alleg = 0
                ; Gadget/objet neutre (ex: portail JQ) — INTERACT_LIVING force le pathfinding
                Agent_GoNPC($bestId)
            Case Else
                Agent_GoSignpost($bestId)
        EndSelect

        Sleep(400)
        Local $isMoving = Agent_GetAgentInfo($myID, "IsMoving")
        Local $newX = Agent_GetAgentInfo($myID, "X")
        Local $newY = Agent_GetAgentInfo($myID, "Y")
        ConsoleWrite("[GOTO] Après nav: IsMoving=" & $isMoving & "  pos=(" & Round($newX) & "," & Round($newY) & ")" & @CRLF)
        Return True
    EndIf

    ConsoleWrite("[GOTO] Aucun agent dans rayon " & $searchRadius & ", fallback Map_MoveLayer" & @CRLF)
    Map_MoveLayer($targetX, $targetY, Agent_GetAgentInfo(-2, "Plane"))
    Return False
EndFunc

Func Move($x, $y, $random = 50)
    Local $destX = $x + Random(-$random, $random, 1)
    Local $destY = $y + Random(-$random, $random, 1)
    Local $curX = Agent_GetAgentInfo(-2, "X")
    Local $curY = Agent_GetAgentInfo(-2, "Y")
    ConsoleWrite("[MOVE] PosActuelle=(" & Round($curX) & "," & Round($curY) & ")  Cible=(" & Round($destX) & "," & Round($destY) & ")  base=(" & $x & "," & $y & ")" & @CRLF)
    _GoToCoords($destX, $destY)
EndFunc

Func ComputeDistance($x1, $y1, $x2, $y2)
    Return Sqrt(($x1 - $x2) ^ 2 + ($y1 - $y2) ^ 2)
EndFunc

; Cherche le gadget portail (allegiance=0) le plus proche des coords cibles.
Func _FindPortalGadget($pX, $pY, $maxDist = 3000)
    Local $bestId = 0, $bestDist = $maxDist
    For $i = 1 To Agent_GetMaxAgents()
        If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
        If Agent_GetAgentInfo($i, "Allegiance") <> 0 Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        If $aX = 0 And $aY = 0 Then ContinueLoop
        Local $dist = ComputeDistance($aX, $aY, $pX, $pY)
        ConsoleWrite("[PORTAL] Gadget " & $i & "  dist=" & Round($dist) & "  pos=(" & Round($aX) & "," & Round($aY) & ")" & @CRLF)
        If $dist < $bestDist Then
            $bestDist = $dist
            $bestId = $i
        EndIf
    Next
    Return $bestId
EndFunc

Func GoPortal($iPortal)
    Local $pX = $aPortals[$iPortal][0]
    Local $pY = $aPortals[$iPortal][1]
    ConsoleWrite("[PORTAL] Navigation vers portail #" & $iPortal & "  cible=(" & $pX & "," & $pY & ")" & @CRLF)
    ConsoleWrite("[PORTAL] Spawn=(" & Round(Agent_GetAgentInfo(-2, "X")) & "," & Round(Agent_GetAgentInfo(-2, "Y")) & ")" & @CRLF)

    Local $tEscape = TimerInit()
    Local $distance = 1000
    Local $lastX = Agent_GetAgentInfo(-2, "X")
    Local $lastY = Agent_GetAgentInfo(-2, "Y")

    ; Première tentative
    Local $gadgetId = _FindPortalGadget($pX, $pY)
    If $gadgetId > 0 Then
        ConsoleWrite("[PORTAL] GoNPC gadget ID=" & $gadgetId & @CRLF)
        Agent_GoNPC($gadgetId)
    Else
        ConsoleWrite("[PORTAL] Aucun gadget, Move fallback." & @CRLF)
        Move($pX, $pY, 30)
    EndIf

    Do
        Sleep(500)

        Local $myID = Agent_GetMyID()
        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $isDead = Agent_GetAgentInfo($myID, "IsDead")
        Local $mapType = Map_GetInstanceInfo("Type")

        $distance = ComputeDistance($myX, $myY, $aTeleports[$iPortal][0], $aTeleports[$iPortal][1])
        ConsoleWrite("[PORTAL] Pos=(" & Round($myX) & "," & Round($myY) & ")  DistTeleport=" & Round($distance) & "  " & Round(TimerDiff($tEscape) / 1000) & "s" & @CRLF)

        If $isDead Then ExitLoop
        If $mapType = $GC_I_MAP_TYPE_OUTPOST Then ExitLoop

        ; Relance si la position n'a pas changé depuis 8s
        Local $moved = Abs($myX - $lastX) > 10 Or Abs($myY - $lastY) > 10
        If Not $moved And TimerDiff($tEscape) > 8000 Then
            ConsoleWrite("[PORTAL] Position inchangée, relance navigation." & @CRLF)
            $gadgetId = _FindPortalGadget($pX, $pY)
            If $gadgetId > 0 Then
                Agent_GoNPC($gadgetId)
            Else
                Move($pX, $pY, 5)
            EndIf
            $tEscape = TimerInit()
        EndIf

        $lastX = $myX
        $lastY = $myY

    Until $distance < 400

    ConsoleWrite("[PORTAL] Portail atteint (dist=" & Round($distance) & ")." & @CRLF)
    Return 1
EndFunc

Func CheckQuarry()
    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    ConsoleWrite("[QUARRY] Check carrières. Pos=(" & Round($myX) & "," & Round($myY) & ")  Purple=" & $PurpleCapped & "  Yellow=" & $YellowCapped & "  Green=" & $GreenCapped & @CRLF)

    Local $MyDistance
    For $iShrine = 0 To 2
        If $iShrine = 0 And $PurpleCapped Then ContinueLoop
        If $iShrine = 1 And $YellowCapped Then ContinueLoop
        If $iShrine = 2 And $GreenCapped Then ContinueLoop

        $MyDistance = ComputeDistance($myX, $myY, $aShrines[$iShrine][0], $aShrines[$iShrine][1])
        ConsoleWrite("[QUARRY] Shrine " & $iShrine & " distance=" & Round($MyDistance) & @CRLF)

        If $MyDistance < 4500 And $MyDistance > 1000 Then
            If $iShrine + 1 = $SHRINE_PurpleQuarry Then $PurpleCapped = True
            If $iShrine + 1 = $SHRINE_YellowQuarry Then $YellowCapped = True
            If $iShrine + 1 = $SHRINE_GreenQuarry Then $GreenCapped = True
            ConsoleWrite("[QUARRY] -> Carrière " & $iShrine & " accessible (dist=" & Round($MyDistance) & "), marquée cappée." & @CRLF)
            Return $iShrine
        EndIf
    Next

    ConsoleWrite("[QUARRY] Aucune carrière accessible, retour 50." & @CRLF)
    Return 50
EndFunc

Func MoveToQuarry($QuarryNumber)
    Local $lDestX = $aShrines[$QuarryNumber][0]
    Local $lDestY = $aShrines[$QuarryNumber][1]
    ConsoleWrite("[QUARRY] Déplacement vers carrière " & $QuarryNumber & " -> (" & $lDestX & "," & $lDestY & ")" & @CRLF)

    Local $bestId = 0, $bestDist = 999999
    Local $maxAgents = Agent_GetMaxAgents()

    For $i = 1 To $maxAgents
        If Agent_GetAgentPtr($i) = 0 Then ContinueLoop
        Local $aAlleg = Agent_GetAgentInfo($i, "Allegiance")
        If $aAlleg = $GC_I_ALLEGIANCE_ALLY Then ContinueLoop
        If Agent_GetAgentInfo($i, "IsDead") Then ContinueLoop
        Local $aX = Agent_GetAgentInfo($i, "X")
        Local $aY = Agent_GetAgentInfo($i, "Y")
        If $aX = 0 And $aY = 0 Then ContinueLoop
        Local $dist = ComputeDistance($aX, $aY, $lDestX, $lDestY)
        ConsoleWrite("[QUARRY] Agent " & $i & "  alleg=" & $aAlleg & "  dist=" & Round($dist) & "  pos=(" & Round($aX) & "," & Round($aY) & ")" & @CRLF)
        If $dist < $bestDist Then
            $bestDist = $dist
            $bestId = $i
        EndIf
    Next

    If $bestId > 0 Then
        ConsoleWrite("[QUARRY] -> Agent_GoNPC sur ID=" & $bestId & "  alleg=" & Agent_GetAgentInfo($bestId, "Allegiance") & "  distShrine=" & Round($bestDist) & @CRLF)
        Agent_GoNPC($bestId)
    Else
        ConsoleWrite("[QUARRY] Aucun agent trouvé, mouvement impossible." & @CRLF)
    EndIf
EndFunc
