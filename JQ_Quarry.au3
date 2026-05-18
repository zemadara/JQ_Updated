#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

#Region - Model IDs
Global Const $LuxonLongbowMID = 3081
Global Const $LuxonStormCallerMID = 3079
Global Const $LuxonWizardMID = 3077
Global Const $LuxonBaseDefenderMID = 3083
Global Const $GreenTurtleMID = 3575

Global Const $KurzickFarShotMID = 3080
Global Const $KurzickThunderMID = 3078
Global Const $KurzickIllusionistMID = 3076
Global Const $KurzickBaseDefenderMID = 3082
Global Const $PurpleCarrierJuggernautMID = 3357
#EndRegion

Func JQ_GetPriorityTarget()
    Local $myID = Agent_GetMyID()
    Local $myX = Agent_GetAgentInfo($myID, "X")
    Local $myY = Agent_GetAgentInfo($myID, "Y")
    Local $maxAgents = Agent_GetMaxAgents()

    ConsoleWrite("[TARGET] Recherche cible prioritaire. MaxAgents=" & $maxAgents & "  Faction=" & $PlayingFor & @CRLF)

    Local $bestTarget = 0
    Local $bestScore = 0
    Local $dist, $modelId, $score
    Local $scannedEnemies = 0

    For $i = 1 To $maxAgents
        Local $agentPtr = Agent_GetAgentPtr($i)
        If $agentPtr = 0 Then ContinueLoop

        Local $allegiance = Agent_GetAgentInfo($i, "Allegiance")
        If $allegiance <> $GC_I_ALLEGIANCE_ENEMY Then ContinueLoop

        Local $isDead = Agent_GetAgentInfo($i, "IsDead")
        If $isDead Then ContinueLoop

        If $i = $myID Then ContinueLoop

        Local $tX = Agent_GetAgentInfo($i, "X")
        Local $tY = Agent_GetAgentInfo($i, "Y")
        $dist = ComputeDistance($myX, $myY, $tX, $tY)
        If $dist > 1500 Then ContinueLoop

        $modelId = Agent_GetAgentInfo($i, "ModelID")
        $score = 0

        If ($PlayingFor = "Kurzick" And $modelId = $GreenTurtleMID) Or _
           ($PlayingFor = "Luxon" And $modelId = $PurpleCarrierJuggernautMID) Then
            $score = 1000
            ConsoleWrite("[TARGET] Agent " & $i & " est la cible prioritaire (carrier/turtle), ModelID=" & $modelId & @CRLF)
        EndIf

        If JQ_IsEnemyGuard($modelId) Then
            $score = 500
            ConsoleWrite("[TARGET] Agent " & $i & " est un garde ennemi, ModelID=" & $modelId & @CRLF)
        EndIf

        $score += (1500 - $dist) / 10
        $scannedEnemies += 1

        ConsoleWrite("[TARGET] Agent " & $i & "  ModelID=" & $modelId & "  Dist=" & Round($dist) & "  Score=" & Round($score) & @CRLF)

        If $score > $bestScore Then
            $bestScore = $score
            $bestTarget = $i
        EndIf
    Next

    ConsoleWrite("[TARGET] Scan terminé. Ennemis trouvés=" & $scannedEnemies & "  Meilleure cible=" & $bestTarget & "  Score=" & Round($bestScore) & @CRLF)
    Return $bestTarget
EndFunc

Func JQ_IsEnemyGuard($modelId)
    If $PlayingFor = "Kurzick" Then
        Switch $modelId
            Case $LuxonLongbowMID, $LuxonStormCallerMID, $LuxonWizardMID
                Return True
            Case Else
                Return False
        EndSwitch
    Else
        Switch $modelId
            Case $KurzickFarShotMID, $KurzickThunderMID, $KurzickIllusionistMID
                Return True
            Case Else
                Return False
        EndSwitch
    EndIf
EndFunc
