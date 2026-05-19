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

Func ComputeDistance($x1, $y1, $x2, $y2)
    Return Sqrt(($x1 - $x2) ^ 2 + ($y1 - $y2) ^ 2)
EndFunc

; Déplace vers ($fX, $fY) avec détection de blocage basée sur les vecteurs de déplacement.
; Reproduit le pattern AddOns_MoveTo de Encounter ReBuilt :
;   - Un seul Map_Move initial, puis relance si MoveX=0 et MoveY=0 pendant plusieurs ticks.
;   - Au 10e tick bloqué : envoi de /stuck dans le chat GW.
;   - Au 20e tick bloqué : abandon avec False.
;   - $iTimeout (ms) pour éviter une boucle infinie en cas de géométrie bloquante.
Func JQ_MoveTo($fX, $fY, $iArrivalDist = 200, $iTimeout = 30000)
    Local $myID = Agent_GetMyID()
    If $myID = 0 Then Return False

    Local $tTimer = TimerInit()
    Local $iStuck = 0
    Local $bInitialMove = True

    Do
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_LOADING Then Return False
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_OUTPOST Then Return False
        If Agent_GetAgentInfo($myID, "IsDead") Then Return False
        If TimerDiff($tTimer) > $iTimeout Then Return False

        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $dist = ComputeDistance($myX, $myY, $fX, $fY)

        If $dist < $iArrivalDist Then ExitLoop

        If $bInitialMove Then
            $bInitialMove = False
            Map_Move($fX, $fY)
        EndIf

        Local $mvX = Agent_GetAgentInfo($myID, "MoveX")
        Local $mvY = Agent_GetAgentInfo($myID, "MoveY")

        If $mvX = 0 And $mvY = 0 Then
            $iStuck += 1
            If $iStuck = 10 Then Chat_SendChat("stuck", "/")
            If $iStuck >= 20 Then Return False
            Map_Move($fX, $fY)
        Else
            $iStuck = 0
        EndIf

        Sleep(100)
    Until False

    Return True
EndFunc

; Navigue vers le portail $iPortal et attend l'activation du téléport.
Func GoPortal($iPortal)
    Local $pX = $aPortals[$iPortal][0]
    Local $pY = $aPortals[$iPortal][1]
    JQ_Log("[PORTAL] Navigation vers portail #" & $iPortal & "  cible=(" & $pX & "," & $pY & ")")

    Local $myID = Agent_GetMyID()

    ; Boucle : avancer vers le portail jusqu'à ce que le téléport se déclenche
    ; (map type bascule en OUTPOST ou distance au point de téléport < 400).
    Local $tMax = TimerInit()
    Do
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_LOADING Then Return
        If Map_GetInstanceInfo("Type") = $GC_I_MAP_TYPE_OUTPOST Then Return
        If TimerDiff($tMax) > 120000 Then Return

        Local $myX = Agent_GetAgentInfo($myID, "X")
        Local $myY = Agent_GetAgentInfo($myID, "Y")
        Local $distTeleport = ComputeDistance($myX, $myY, $aTeleports[$iPortal][0], $aTeleports[$iPortal][1])
        JQ_Log("[PORTAL] Dist téléport=" & Round($distTeleport) & "  pos=(" & Round($myX) & "," & Round($myY) & ")")

        If $distTeleport < 400 Then ExitLoop

        JQ_MoveTo($pX, $pY, 350, 12000)

    Until False

    JQ_Log("[PORTAL] Portail atteint.")
EndFunc

; Vérifie quelle carrière est à portée et non encore cappée.
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

; Se déplace vers la carrière $QuarryNumber.
Func MoveToQuarry($QuarryNumber)
    Local $lDestX = $aShrines[$QuarryNumber][0]
    Local $lDestY = $aShrines[$QuarryNumber][1]
    JQ_Log("[QUARRY] Déplacement vers carrière " & $QuarryNumber & " -> (" & Round($lDestX) & "," & Round($lDestY) & ")")
    JQ_MoveTo($lDestX, $lDestY, 300, 20000)
EndFunc
