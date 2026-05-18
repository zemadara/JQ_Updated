# Bot Jade Quarry (JQ)

Bot AutoIt pour Guild Wars 1 — automatise les runs Jade Quarry : échange de faction, achat de Zkeys et combat en arène.

---

## Prérequis

**Guild Wars 1** doit être lancé et connecté avant de démarrer le bot. Le client officiel NCsoft et le client Steam fonctionnent tous les deux.

**AutoIt3 32 bits** doit être installé sur le PC. Téléchargement : https://www.autoitscript.com/site/autoit/downloads — prendre la version normale (pas x64).

**La librairie GwAu3** est déjà incluse dans le dossier parent (`GwAu3-main`). Aucune installation supplémentaire nécessaire.

**Internet requis au premier lancement** : le Pathfinder de GwAu3 télécharge automatiquement un fichier de données de cartes (`maps.rar`) depuis GitHub. Ce téléchargement se fait une seule fois.

---

## Structure des fichiers

```
JQ Updated/
├── JQ_Main.au3       — point d'entrée, c'est ce fichier qu'on lance
├── JQ_Economy.au3    — échange faction Impériale, achat Zkeys chez Tolkano
├── JQ_Movement.au3   — navigation (portails, carrières)
├── JQ_Combat.au3     — sélection et lancement des compétences
├── JQ_Quarry.au3     — détection et priorité des cibles en arène
└── MoveTest.au3      — script de test des méthodes de déplacement (indépendant)
```

---

## Avant de lancer

1. Être connecté dans l'outpost Jade Quarry Kurzick (MapID 296) ou Luxon (MapID 295). Le côté est détecté automatiquement.
2. Avoir de la faction Impériale disponible à échanger, ou au moins de la faction Balthazar pour acheter des Zkeys.
3. Tolkano doit être accessible dans l'outpost (présent dans les deux versions de la carte).

---

## Lancement

Faire un clic droit sur `JQ_Main.au3` et choisir "Run Script". Le script demande les droits administrateur au lancement, c'est normal et nécessaire pour accéder à la mémoire du processus GW.

Guild Wars doit déjà tourner au moment du lancement. Le bot cherche la fenêtre nommée "Guild Wars" et récupère son PID automatiquement.

---

## Ce que fait le bot

**En outpost**, à chaque cycle :
- Il échange toute la faction Impériale disponible en faction Balthazar auprès de l'officier de faction.
- Il achète un Zkey chez Tolkano avec la faction Balthazar obtenue.
- Il entre en file d'attente via `Map_EnterChallenge` et attend le match. Si aucun match ne démarre dans la minute, il se réinscrit automatiquement.

**En arène** (MapID 223) :
- Il choisit un portail au hasard parmi ceux de sa faction et s'y rend.
- Il navigue vers les carrières de jade, combat les ennemis à portée et tente de capturer les points.
- En cas de mort, il attend la résurrection puis reprend la navigation.

**Cycle complet** : outpost → match → outpost, en boucle jusqu'à ce qu'on l'arrête.

---

## Contrôles

Un menu est accessible via l'icône dans la barre système (system tray) :

- **Arrêter après le match** : le bot finit le match en cours puis s'arrête. Cliquer à nouveau pour relancer.
- **Quitter** : ferme le script immédiatement.

---

## Notes

Le bot ne modifie pas les fichiers de Guild Wars et ne simule pas de clics souris. Il lit la mémoire du processus GW et envoie des paquets réseau, de la même façon que le font les bot frameworks standards pour GW1.

Garder Guild Wars en fenêtre active ou en arrière-plan ne change pas le comportement du bot. Il n'a pas besoin du focus.

Les codes de dialog (échanges de faction, achat Zkeys) ont été identifiés par observation des logs en jeu. Si une mise à jour de GW modifie ces codes, ils se trouvent dans `JQ_Economy.au3`.
