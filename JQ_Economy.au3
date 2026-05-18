#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

; ModelIDs à renseigner après observation en jeu (voir logs [TRADE] ModelID=...)
; Décommentez et ajustez une fois identifiés
;~ Global Const $MID_ImperialOfficer_Kurzick = XXXX
;~ Global Const $MID_ImperialOfficer_Luxon   = XXXX
;~ Global Const $MID_Tolkano                 = XXXX

; =================================================================================================
; Fonction:  _Trade_FindNearestNPC($targetX, $targetY, $maxDist)
; Retourne l'ID de l'agent NPC le plus proche de ($targetX, $targetY) dans un rayon $maxDist.
; =================================================================================================
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
        ConsoleWrite("[TRADE] NPC " & $i & "  ModelID=" & $mid & "  dist=" & Round($dist) & "  pos=(" & Round($nX) & "," & Round($nY) & ")" & @CRLF)

        If $dist < $bestDist Then
            $bestDist = $dist
            $bestId = $i
        EndIf
    Next

    Return $bestId
EndFunc

; =================================================================================================
; Fonction:  TradeImperialX()
; Description: Échange la faction Impériale contre Balthazar auprès de l'officier de faction.
; =================================================================================================
Func TradeImperialX()
    ConsoleWrite("[TRADE] Début TradeImperialX..." & @CRLF)
    Local $currentMap = Map_GetCharacterInfo("MapID")
    ConsoleWrite("[TRADE] MapID=" & $currentMap & @CRLF)

    Local $npcX, $npcY
    If $currentMap = 296 Then
        $npcX = -3298
        $npcY = -7560
    ElseIf $currentMap = 295 Then
        $npcX = 2472
        $npcY = 11757
    Else
        ConsoleWrite("[TRADE] MapID inconnu, abandon TradeImperialX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Déplacement vers officier faction (" & $npcX & "," & $npcY & ")" & @CRLF)
    Move($npcX, $npcY, 30)
    Sleep(3000)

    Local $npcId = _Trade_FindNearestNPC($npcX, $npcY, 600)
    ConsoleWrite("[TRADE] Officier faction ID=" & $npcId & @CRLF)

    If $npcId = 0 Then
        ConsoleWrite("[TRADE] Aucun PNJ trouvé à portée des coords officier." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Interaction officier ID=" & $npcId & @CRLF)
    Agent_GoNPC($npcId)

    Local $tWalkImp = TimerInit()
    Do
        Sleep(300)
        Local $myXImp = Agent_GetAgentInfo(-2, "X")
        Local $myYImp = Agent_GetAgentInfo(-2, "Y")
        Local $nXImp  = Agent_GetAgentInfo($npcId, "X")
        Local $nYImp  = Agent_GetAgentInfo($npcId, "Y")
        Local $dImp   = ComputeDistance($myXImp, $myYImp, $nXImp, $nYImp)
        ConsoleWrite("[TRADE] Approche officier... dist=" & Round($dImp) & "  perso=(" & Round($myXImp) & "," & Round($myYImp) & ")  npc=(" & Round($nXImp) & "," & Round($nYImp) & ")" & @CRLF)
    Until $dImp < 250 Or TimerDiff($tWalkImp) > 20000 Or Map_GetCharacterInfo("MapID") <> $currentMap

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        ConsoleWrite("[TRADE] Carte changée pendant approche officier, abandon TradeImperialX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Dialog 0x97 (échange Impérial->Balthazar)" & @CRLF)
    Game_Dialog(0x97)
    Sleep(1500)

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        ConsoleWrite("[TRADE] Carte changée après 0x97, abandon TradeImperialX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Dialog 0xA3 (confirmation tout échanger)" & @CRLF)
    Game_Dialog(0xA3)
    Sleep(2000)

    ConsoleWrite("[TRADE] TradeImperialX terminé." & @CRLF)
    Return True
EndFunc

; =================================================================================================
; Fonction:  TradeBalthazarX()
; Description: Achète des Zkeys auprès de Tolkano avec la faction Balthazar.
; =================================================================================================
Func TradeBalthazarX()
    ConsoleWrite("[TRADE] Début TradeBalthazarX..." & @CRLF)
    Local $currentMap = Map_GetCharacterInfo("MapID")
    ConsoleWrite("[TRADE] MapID=" & $currentMap & @CRLF)

    Local $tolkanoX, $tolkanoY
    If $currentMap = 296 Then
        $tolkanoX = -2643
        $tolkanoY = -6842
    ElseIf $currentMap = 295 Then
        $tolkanoX = 3585
        $tolkanoY = 13641
    Else
        ConsoleWrite("[TRADE] MapID inconnu, abandon TradeBalthazarX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Déplacement vers Tolkano (" & $tolkanoX & "," & $tolkanoY & ")" & @CRLF)
    Move($tolkanoX, $tolkanoY, 30)
    Sleep(3000)

    Local $tolkanoId = _Trade_FindNearestNPC($tolkanoX, $tolkanoY, 1500)
    ConsoleWrite("[TRADE] Tolkano ID=" & $tolkanoId & @CRLF)

    If $tolkanoId = 0 Then
        ConsoleWrite("[TRADE] Tolkano introuvable à portée." & @CRLF)
        Return False
    EndIf

    ; Un seul achat par appel — OutpostLogic doit boucler si nécessaire
    ConsoleWrite("[TRADE] Interaction Tolkano ID=" & $tolkanoId & @CRLF)
    Agent_GoNPC($tolkanoId)

    Local $tWalkTol = TimerInit()
    Do
        Sleep(300)
        Local $myXTol = Agent_GetAgentInfo(-2, "X")
        Local $myYTol = Agent_GetAgentInfo(-2, "Y")
        Local $nXTol  = Agent_GetAgentInfo($tolkanoId, "X")
        Local $nYTol  = Agent_GetAgentInfo($tolkanoId, "Y")
        Local $dTol   = ComputeDistance($myXTol, $myYTol, $nXTol, $nYTol)
        ConsoleWrite("[TRADE] Approche Tolkano... dist=" & Round($dTol) & "  perso=(" & Round($myXTol) & "," & Round($myYTol) & ")  npc=(" & Round($nXTol) & "," & Round($nYTol) & ")" & @CRLF)
    Until $dTol < 250 Or TimerDiff($tWalkTol) > 20000 Or Map_GetCharacterInfo("MapID") <> $currentMap

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        ConsoleWrite("[TRADE] Carte changée pendant approche Tolkano, abandon TradeBalthazarX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Dialog 0x87 (acheter Zkey)" & @CRLF)
    Game_Dialog(0x87)
    Sleep(1500)

    If Map_GetCharacterInfo("MapID") <> $currentMap Then
        ConsoleWrite("[TRADE] Carte changée après 0x87, abandon TradeBalthazarX." & @CRLF)
        Return False
    EndIf

    ConsoleWrite("[TRADE] Dialog 0x88 (confirmer achat)" & @CRLF)
    Game_Dialog(0x88)
    Sleep(2000)

    ConsoleWrite("[TRADE] TradeBalthazarX terminé." & @CRLF)
    Return True
EndFunc
