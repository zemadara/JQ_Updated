#include-once
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

; --- Globals GUI ---
Global $g_bGwInitialized = False
Global $g_h_MainGUI
Global $g_i_CtrlID_Button_Start
Global $g_i_CtrlID_CBX_Render
Global $g_i_CtrlID_Edit_Console
Global $g_i_CtrlID_Label_Faction
Global $g_i_CtrlID_Label_Kurzick
Global $g_i_CtrlID_Label_Luxon
Global $g_i_CtrlID_Label_Imperial
Global $g_i_CtrlID_Label_Balth
Global $g_i_CtrlID_Label_Runs
Global $g_i_CtrlID_Label_Zkeys
Global $g_i_CtrlID_Label_Session

Global $g_h_SessionTimer = TimerInit()

Func JQ_GUI_Create()
    Opt("GUIOnEventMode", True)
    Opt("GUICloseOnESC", False)

    ; Le bot démarre en pause — l'utilisateur clique Run pour lancer.
    $boolRun = False

    $g_h_MainGUI = GUICreate("JQ Bot", 400, 540, -1, -1)
    GUISetOnEvent($GUI_EVENT_CLOSE, "_JQ_GUI_Close")

    ; --- Section stats ---
    GUICtrlCreateLabel("Faction :", 10, 12, 70, 18)
    $g_i_CtrlID_Label_Faction = GUICtrlCreateLabel($PlayingFor, 125, 12, 120, 18)

    GUICtrlCreateLabel("Faction Kurzick :", 10, 36, 110, 18)
    $g_i_CtrlID_Label_Kurzick = GUICtrlCreateLabel("0", 125, 36, 120, 18)

    GUICtrlCreateLabel("Faction Luxon :", 10, 56, 110, 18)
    $g_i_CtrlID_Label_Luxon = GUICtrlCreateLabel("0", 125, 56, 120, 18)

    GUICtrlCreateLabel("Faction Impériale :", 10, 76, 110, 18)
    $g_i_CtrlID_Label_Imperial = GUICtrlCreateLabel("0", 125, 76, 120, 18)

    GUICtrlCreateLabel("Faction Balthazar :", 10, 96, 110, 18)
    $g_i_CtrlID_Label_Balth = GUICtrlCreateLabel("0", 125, 96, 120, 18)

    GUICtrlCreateLabel("Parties jouées :", 10, 120, 110, 18)
    $g_i_CtrlID_Label_Runs = GUICtrlCreateLabel("0", 125, 120, 80, 18)

    GUICtrlCreateLabel("Zkeys échangés :", 10, 140, 110, 18)
    $g_i_CtrlID_Label_Zkeys = GUICtrlCreateLabel("0", 125, 140, 80, 18)

    GUICtrlCreateLabel("Session :", 10, 160, 110, 18)
    $g_i_CtrlID_Label_Session = GUICtrlCreateLabel("00:00:00", 125, 160, 100, 18)

    ; --- Bouton Run / Pause ---
    $g_i_CtrlID_Button_Start = GUICtrlCreateButton("Run", 10, 190, 90, 28)
    GUICtrlSetOnEvent($g_i_CtrlID_Button_Start, "_JQ_GUI_ToggleRun")

    ; --- Checkbox rendu GW ---
    $g_i_CtrlID_CBX_Render = GUICtrlCreateCheckbox("Rendu GW activé", 115, 194, 150, 20)
    GUICtrlSetState($g_i_CtrlID_CBX_Render, $GUI_CHECKED)
    GUICtrlSetOnEvent($g_i_CtrlID_CBX_Render, "_JQ_GUI_ToggleRender")

    ; --- Console log ---
    GUICtrlCreateLabel("Logs :", 10, 230, 50, 16)
    $g_i_CtrlID_Edit_Console = GUICtrlCreateEdit("", 10, 248, 378, 278, _
        BitOR($ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL, $WS_VSCROLL))

    GUISetState(@SW_SHOW, $g_h_MainGUI)

    AdlibRegister("JQ_GUI_Update", 1000)
EndFunc

Func JQ_GUI_Update()
    If Not $g_h_MainGUI Then Return

    GUICtrlSetData($g_i_CtrlID_Label_Faction, $PlayingFor)
    If $g_bGwInitialized Then
        GUICtrlSetData($g_i_CtrlID_Label_Kurzick, World_GetWorldInfo("CurrentKurzick"))
        GUICtrlSetData($g_i_CtrlID_Label_Luxon, World_GetWorldInfo("CurrentLuxon"))
        GUICtrlSetData($g_i_CtrlID_Label_Imperial, World_GetWorldInfo("CurrentImperial"))
        GUICtrlSetData($g_i_CtrlID_Label_Balth, World_GetWorldInfo("CurrentBalth"))
    EndIf
    GUICtrlSetData($g_i_CtrlID_Label_Runs, $iTotalRuns)
    GUICtrlSetData($g_i_CtrlID_Label_Zkeys, $MyTotalZkeys)

    Local $iElapsed = Int(TimerDiff($g_h_SessionTimer) / 1000)
    Local $iH = Int($iElapsed / 3600)
    Local $iM = Int(Mod($iElapsed, 3600) / 60)
    Local $iS = Mod($iElapsed, 60)
    GUICtrlSetData($g_i_CtrlID_Label_Session, StringFormat("%02d:%02d:%02d", $iH, $iM, $iS))

    GUICtrlSetData($g_i_CtrlID_Button_Start, $boolRun ? "Pause" : "Run")
EndFunc

Func JQ_Log($sMsg)
    Local $sLine = "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $sMsg
    ConsoleWrite($sLine & @CRLF)
    If $g_h_MainGUI Then
        _GUICtrlEdit_AppendText($g_i_CtrlID_Edit_Console, $sLine & @CRLF)
    EndIf
EndFunc

Func _JQ_GUI_ToggleRun()
    $boolRun = Not $boolRun
    JQ_Log($boolRun ? "Bot démarré." : "Bot en pause.")
EndFunc

Func _JQ_GUI_ToggleRender()
    If Not $g_bGwInitialized Then Return
    If GUICtrlRead($g_i_CtrlID_CBX_Render) = $GUI_CHECKED Then
        Ui_EnableRendering()
        JQ_Log("Rendu GW activé.")
    Else
        Ui_DisableRendering()
        JQ_Log("Rendu GW désactivé.")
    EndIf
EndFunc

Func _JQ_GUI_Close()
    AdlibUnRegister("JQ_GUI_Update")
    If $g_bGwInitialized Then Ui_EnableRendering()
    Exit
EndFunc
