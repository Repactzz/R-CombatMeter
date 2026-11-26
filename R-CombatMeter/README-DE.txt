R-CombatMeter  |  v1.0.1
WoW Forever 1.60.1 / Interface 16001
==================================

INSTALLATION
1. ZIP entpacken.
2. Den Ordner R-CombatMeter nach
   World of Warcraft\_forever_\Interface\AddOns\ kopieren.
   Die .toc-Datei muss direkt in R-CombatMeter liegen,
   nicht in einem zusätzlichen Unterordner.
3. WoW starten, Addon aktivieren oder /reload eingeben.
4. Beim ersten Laden öffnet sich der Setup-Guide.
   Wähle das Layout und klicke auf FERTIG / SPIELEN.

BEDIENUNG
- Modus im Header wählen:
  Damage Done            = aktueller Kampf, Schaden und DPS
  Damage Done Overall    = gesamter Schaden und Gesamt-DPS
  Healing Done           = aktueller Kampf, Heilung und HPS
  Healing Done Overall   = gesamte Heilung und Gesamt-HPS
- + öffnet die Window Control. Neues Fenster frei oder direkt
  unterhalb der Gruppe anlegen. Bis zu 12 Fenster.
- Header ziehen, um ein Fenster bzw. seine Gruppe zu bewegen.
  Eine freie Gruppe nahe unter eine andere ziehen, um sie
  automatisch anzudocken, oder über das + Menü anhängen.
- L/U im Header sperrt / entsperrt die ganze Fenstergruppe
  (U = unlocked, L = locked).
- Untere rechte Ecke im entsperrten Zustand ziehen:
  Höhe (1 bis 40 Zeilen) und Breite ändern.
- Mausrad über dem Meter: weitere Spieler anzeigen.
- Türkiser Markierungsstrich: eigener Charakter.
- Positionen, Modi, Größen, Verknüpfungen, Sperren und
  Einstellungen bleiben je Charakter gespeichert.

CHATBEFEHLE
/rcm        Guide erneut öffnen
/rcm demo   Beispieldaten ein- oder ausschalten
/rcm hide   alle Fenster ein- oder ausblenden
/rcm lock   sämtliche Gruppen sperren / entsperren
/rcm reset  gemeinsame Kampfdaten nach Bestätigung löschen

AUTOMATIK
Die Current-Session des Forever-Clients trennt die Kämpfe.
Overall nutzt die vom Client aggregierten Daten.
Auto-Reset ist standardmäßig aktiviert und im Guide abschaltbar.
Bei Eintritt, Austritt oder Wechsel einer Dungeon-/Raid-Instanz
wird ein Reset angefordert und außerhalb des Kampfs ausgeführt.
Bei einem vom Client gemeldeten Abschluss (LFG-/Challenge-Event)
erfolgt ebenfalls ein Reset. Nicht jeder klassische Dungeon oder
Raid liefert ein eindeutiges Abschlussereignis; dann wird beim
Verlassen zurückgesetzt. Ein einzelner Bosskill setzt NICHT den
gesamten Raid zurück. Instanzwechsel werden nach Ladebildschirm
kurz verzögert geprüft.
