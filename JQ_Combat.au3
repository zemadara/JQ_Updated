#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

Global $Skill_FAILED = 0

Func SmartCast()
    Local $myID = Agent_GetMyID()
    Local $isDead = Agent_GetAgentInfo($myID, "IsDead")
    Local $castingSkill = Agent_GetAgentInfo($myID, "Skill")
    ConsoleWrite("[SMARTCAST] MyID=" & $myID & "  IsDead=" & $isDead & "  CastingSkill=" & $castingSkill & @CRLF)

    If $isDead Then
        ConsoleWrite("[SMARTCAST] Personnage mort, annulation." & @CRLF)
        Return False
    EndIf

    ; Récupère la cible actuelle via la fonction correcte de l'API
    Local $target = Agent_GetCurrentTarget()
    ConsoleWrite("[SMARTCAST] Cible courante (Agent_GetCurrentTarget) : " & $target & @CRLF)

    For $i = 1 To 8
        If $Skill_FAILED = $i Then
            ConsoleWrite("[SMARTCAST] Slot " & $i & " marqué FAILED, skip." & @CRLF)
            $Skill_FAILED = 0
            ContinueLoop
        EndIf

        ; Vérifie le rechargement via la skillbar (pas la base de données statique)
        Local $rechargeTime = Skill_GetSkillbarInfo($i, "Recharge")
        Local $skillID = Skill_GetSkillbarInfo($i, "SkillID")
        ConsoleWrite("[SMARTCAST] Slot " & $i & "  SkillID=" & $skillID & "  Recharge=" & $rechargeTime & @CRLF)

        If $rechargeTime > 0 Then
            ConsoleWrite("[SMARTCAST] Slot " & $i & " encore en recharge (" & $rechargeTime & "), skip." & @CRLF)
            ContinueLoop
        EndIf

        If $skillID = 0 Then
            ConsoleWrite("[SMARTCAST] Slot " & $i & " vide, skip." & @CRLF)
            ContinueLoop
        EndIf

        If $target > 0 And Agent_GetAgentInfo($target, "Allegiance") = $GC_I_ALLEGIANCE_ENEMY Then
            ConsoleWrite("[SMARTCAST] Cast slot " & $i & " sur cible " & $target & @CRLF)
            UseSkillEx($i, $target)
            Return True
        Else
            ConsoleWrite("[SMARTCAST] Cible invalide ou pas ennemie (Allegiance=" & Agent_GetAgentInfo($target, "Allegiance") & "), pas de cast." & @CRLF)
        EndIf
    Next

    ; Aucune compétence disponible, attaque basique
    If $target > 0 And Agent_GetAgentInfo($target, "Allegiance") = $GC_I_ALLEGIANCE_ENEMY Then
        ConsoleWrite("[SMARTCAST] Aucune compétence dispo, attaque basique sur " & $target & @CRLF)
        Agent_Attack($target)
    EndIf

    Return False
EndFunc

Func UseSkillEx($skillSlot, $targetId, $timeout = 5200)
    Local $myID = Agent_GetMyID()
    Local $castingSkill = Agent_GetAgentInfo($myID, "Skill")
    ConsoleWrite("[USESKILL] Slot=" & $skillSlot & "  Target=" & $targetId & "  CastingSkill=" & $castingSkill & @CRLF)

    If $castingSkill <> 0 Then
        ConsoleWrite("[USESKILL] Déjà en train de caster (Skill=" & $castingSkill & "), annulation." & @CRLF)
        Return False
    EndIf

    Local $tDeadlock = TimerInit()

    ; Change de cible si nécessaire
    Local $currentTarget = Agent_GetCurrentTarget()
    ConsoleWrite("[USESKILL] Cible actuelle=" & $currentTarget & "  Cible voulue=" & $targetId & @CRLF)
    If $currentTarget <> $targetId Then
        ConsoleWrite("[USESKILL] Changement de cible vers " & $targetId & @CRLF)
        Agent_ChangeTarget($targetId)
    EndIf

    ; Lance la compétence en passant explicitement la cible
    ConsoleWrite("[USESKILL] Lancement Skill_UseSkill(slot=" & $skillSlot & ", target=" & $targetId & ")" & @CRLF)
    Skill_UseSkill($skillSlot, $targetId)

    Do
        Sleep(50)
        Local $myDead = Agent_GetAgentInfo($myID, "IsDead")
        Local $targetDead = Agent_GetAgentInfo($targetId, "IsDead")
        Local $recharge = Skill_GetSkillbarInfo($skillSlot, "Recharge")
        ConsoleWrite("[USESKILL] En cours... MyDead=" & $myDead & "  TargetDead=" & $targetDead & "  Recharge=" & $recharge & "  Elapsed=" & Round(TimerDiff($tDeadlock)) & "ms" & @CRLF)

        If $myDead Then
            ConsoleWrite("[USESKILL] Personnage mort pendant le cast." & @CRLF)
            Return False
        EndIf
        If $targetDead Then
            ConsoleWrite("[USESKILL] Cible morte pendant le cast." & @CRLF)
            Return False
        EndIf
    Until ($recharge > 0) Or TimerDiff($tDeadlock) > $timeout

    If TimerDiff($tDeadlock) > $timeout Then
        ConsoleWrite("[USESKILL] TIMEOUT sur slot " & $skillSlot & " après " & $timeout & "ms." & @CRLF)
        $Skill_FAILED = $skillSlot
        Return False
    EndIf

    ConsoleWrite("[USESKILL] Compétence slot " & $skillSlot & " lancée avec succès." & @CRLF)
    Return True
EndFunc
