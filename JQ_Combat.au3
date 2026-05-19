#include-once
#include "..\GwAu3-main\API\_GwAu3.au3"

Global $Skill_FAILED = 0

Func SmartCast()
    Local $myID = Agent_GetMyID()
    Local $isDead = Agent_GetAgentInfo($myID, "IsDead")
    Local $castingSkill = Agent_GetAgentInfo($myID, "Skill")
    JQ_Log("[SMARTCAST] MyID=" & $myID & "  IsDead=" & $isDead & "  CastingSkill=" & $castingSkill)

    If $isDead Then
        JQ_Log("[SMARTCAST] Dead, aborting.")
        Return False
    EndIf

    Local $target = Agent_GetCurrentTarget()
    JQ_Log("[SMARTCAST] Current target: " & $target)

    For $i = 1 To 8
        If $Skill_FAILED = $i Then
            JQ_Log("[SMARTCAST] Slot " & $i & " marked FAILED, skipping.")
            $Skill_FAILED = 0
            ContinueLoop
        EndIf

        Local $rechargeTime = Skill_GetSkillbarInfo($i, "Recharge")
        Local $skillID = Skill_GetSkillbarInfo($i, "SkillID")
        JQ_Log("[SMARTCAST] Slot " & $i & "  SkillID=" & $skillID & "  Recharge=" & $rechargeTime)

        If $rechargeTime > 0 Then ContinueLoop
        If $skillID = 0 Then ContinueLoop

        If $target > 0 And Agent_GetAgentInfo($target, "Allegiance") = $GC_I_ALLEGIANCE_ENEMY Then
            JQ_Log("[SMARTCAST] Casting slot " & $i & " on target " & $target)
            UseSkillEx($i, $target)
            Return True
        Else
            JQ_Log("[SMARTCAST] Invalid or non-enemy target (Allegiance=" & Agent_GetAgentInfo($target, "Allegiance") & "), no cast.")
        EndIf
    Next

    If $target > 0 And Agent_GetAgentInfo($target, "Allegiance") = $GC_I_ALLEGIANCE_ENEMY Then
        JQ_Log("[SMARTCAST] No skill available, basic attack on " & $target)
        Agent_Attack($target)
    EndIf

    Return False
EndFunc

Func UseSkillEx($skillSlot, $targetId, $timeout = 5200)
    Local $myID = Agent_GetMyID()
    Local $castingSkill = Agent_GetAgentInfo($myID, "Skill")
    JQ_Log("[USESKILL] Slot=" & $skillSlot & "  Target=" & $targetId & "  CastingSkill=" & $castingSkill)

    If $castingSkill <> 0 Then
        JQ_Log("[USESKILL] Already casting (Skill=" & $castingSkill & "), aborting.")
        Return False
    EndIf

    Local $tDeadlock = TimerInit()

    Local $currentTarget = Agent_GetCurrentTarget()
    If $currentTarget <> $targetId Then
        JQ_Log("[USESKILL] Switching target to " & $targetId)
        Agent_ChangeTarget($targetId)
    EndIf

    JQ_Log("[USESKILL] Calling Skill_UseSkill(slot=" & $skillSlot & ", target=" & $targetId & ")")
    Skill_UseSkill($skillSlot, $targetId)

    Do
        Sleep(50)
        Local $myDead = Agent_GetAgentInfo($myID, "IsDead")
        Local $targetDead = Agent_GetAgentInfo($targetId, "IsDead")
        Local $recharge = Skill_GetSkillbarInfo($skillSlot, "Recharge")

        If $myDead Then
            JQ_Log("[USESKILL] Character died during cast.")
            Return False
        EndIf
        If $targetDead Then
            JQ_Log("[USESKILL] Target died during cast.")
            Return False
        EndIf
    Until ($recharge > 0) Or TimerDiff($tDeadlock) > $timeout

    If TimerDiff($tDeadlock) > $timeout Then
        JQ_Log("[USESKILL] Timeout on slot " & $skillSlot & " after " & $timeout & "ms.")
        $Skill_FAILED = $skillSlot
        Return False
    EndIf

    JQ_Log("[USESKILL] Skill slot " & $skillSlot & " cast successfully.")
    Return True
EndFunc
