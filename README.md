# Jade Quarry Bot (JQ)

AutoIt bot for Guild Wars 1 — automates Jade Quarry runs: faction trading, Zkey purchasing, and arena combat.

---

## Requirements

**Guild Wars 1** must be running and logged in before starting the bot. Both the official NCsoft client and the Steam client work.

**AutoIt3 32-bit** must be installed. Download: https://www.autoitscript.com/site/autoit/downloads — use the standard version (not x64).

**The GwAu3 library** is already included in the parent folder (`GwAu3-main`). No additional installation required.

---

## File structure

```
JQ_Updated/
├── JQ_Main.au3       — entry point, this is the file to run
├── JQ_Economy.au3    — Imperial faction trade, Zkey purchase from Tolkano
├── JQ_Movement.au3   — navigation (portals, quarry shrines)
├── JQ_Combat.au3     — skill selection and casting
├── JQ_Quarry.au3     — target detection and priority scoring
└── JQ_GUI.au3        — stats window, log console, Run/Pause button
```

---

## Before launching

1. Be in the Jade Quarry Kurzick outpost (MapID 296) or Luxon (MapID 295). The side is detected automatically.
2. Have Imperial faction available to trade, or at least Balthazar faction to buy Zkeys.
3. Tolkano must be present in the outpost (available in both versions of the map).

---

## How to launch

Right-click `JQ_Main.au3` and choose **Run Script**. The script requests administrator rights on startup — this is expected and required to access the GW process memory.

Guild Wars must already be running. The bot finds the window named "Guild Wars" and retrieves its PID automatically.

A control window will appear. Click **Run** to start the bot.

---

## What the bot does

**In the outpost**, each cycle:
- Trades all available Imperial faction for Balthazar faction with the faction officer.
- Buys a Zkey from Tolkano using the obtained Balthazar faction.
- Joins the match queue via `Map_EnterChallenge` and waits. If no match starts within a minute, it re-queues automatically.

**In the arena** (MapID 223):
- Picks a random portal on its faction side and moves to it.
- Navigates to jade quarry shrines, fights nearby enemies, and attempts to capture points.
- If killed, waits for resurrection then resumes navigation.

**Full cycle**: outpost → match → outpost, looping until stopped.

---

## Controls

The control window shows live stats and a log console:

- **Run / Pause** button: starts or pauses the bot after the current action completes.
- **GW rendering enabled** checkbox: disables GW window rendering to reduce CPU usage. Rendering is automatically re-enabled when the bot window is closed.

---

## Notes

The bot does not modify Guild Wars files and does not simulate mouse clicks. It reads the GW process memory and sends network packets, following the same approach as standard GW1 bot frameworks.

Guild Wars does not need to be the active window. The bot works in the background.

Dialog codes (faction trades, Zkey purchase) were identified by observing in-game logs. If a GW update changes these codes, they are in `JQ_Economy.au3`.
