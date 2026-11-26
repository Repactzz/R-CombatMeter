REPACT COMBAT METER  |  v1.0.0
WoW Forever 1.60.1 / Interface 16001
==================================

INSTALLATION
1. ZIP entpacken.
2. Den Ordner RepactCombatMeter nach
   World of Warcraft\_forever_\Interface\AddOns\ kopieren.
   Die .toc-Datei muss direkt in RepactCombatMeter liegen,
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
/rpm        Guide erneut öffnen
/rpm demo   Beispieldaten ein- oder ausschalten
/rpm hide   alle Fenster ein- oder ausblenden
/rpm lock   sämtliche Gruppen sperren / entsperren
/rpm reset  gemeinsame Kampfdaten nach Bestätigung löschen
/repactmeter ist ein Alias für /rpm.

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

WICHTIG: Die API ResetAllCombatSessions löscht die gemeinsame
Blizzard-Datenquelle, nicht nur die Repact-Anzeigen. Andere
Damage Meter, die dieselbe Quelle verwenden, sind betroffen.
Wer das nicht möchte, kann Auto-Reset im Guide ausschalten.

CLIENT-EINSCHRÄNKUNGEN
WoW Forever schützt bestimmte Kampfdaten. Das Addon nutzt die
offizielle Schnittstelle C_DamageMeter, keine Combat-Log-Hooks.
Geheime Zahlen können nur direkt in unterstützten UI-Elementen
angezeigt werden. Prozentanteile erscheinen deshalb nur, wenn
die zugrunde liegenden Zahlen für Addons lesbar sind (in der
Regel nach dem Kampf). Ein Strich kennzeichnet nicht berechenbare
Werte. Die Rangfolge stammt vom Client. Während geschützter
Kämpfe können Zahlen als ungekürzte Ganzzahlen erscheinen.
Wenn keine Daten erscheinen, aktiviere das integrierte Damage
Meter in den WoW-Spieloptionen. Es ist möglich, dass das
Blizzard-Fenster dadurch zusätzlich sichtbar wird.

TESTSTATUS
Lua-Syntaxprüfung und lokaler simulierter API-/UI-Test bestanden:
Ersteinrichtung, Damage-Prozentanteile, Healing, Overall,
Fenster hinzufügen, Gruppensperre, Reset bei Instanzwechsel,
Combat-Reset-Aufschub und Fenster ein-/ausblenden.
Nicht in einem laufenden WoW-Forever-Client getestet. Es handelt
sich um eine erste installierbare Version.

API-Referenz:
https://warcraft.wiki.gg/wiki/API_C_DamageMeter.GetCombatSessionFromType
https://github.com/Atraeau/WoW-Addons/blob/main/docs/api/Items-Inventory/C_DamageMeter.md
