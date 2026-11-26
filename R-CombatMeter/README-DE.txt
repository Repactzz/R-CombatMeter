R-CombatMeter  |  v1.0.5
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

SPRACHE
Deutsch bei deutschem WoW-Client, sonst Englisch.
Die Sprache wird beim Laden automatisch erkannt.

BEDIENUNG
- Modus im Header wählen:
  Schaden                = aktueller Kampf, Schaden und DPS
  Schaden gesamt         = gesamter Schaden und Gesamt-DPS
  Heilung                = aktueller Kampf, Heilung und HPS
  Heilung gesamt         = gesamte Heilung und Gesamt-HPS
- + öffnet die Window Control. Freie Fenster erscheinen mittig auf dem Bildschirm.
  Verbundene Fenster werden direkt oberhalb des gewählten Fensters eingefügt. Bis zu 12 Fenster.
- Header ziehen, um ein Fenster bzw. seine Gruppe zu bewegen.
  Eine freie Gruppe nahe über oder unter eine andere ziehen.
  Der leuchtende Spalt zeigt die Andockposition vor dem Loslassen.
  Nach dem Andocken verschwindet der leuchtende Spalt.
  Alternativ über das + Menü anhängen.
- Das Schlosssymbol sperrt oder entsperrt die ganze Fenstergruppe.
- Untere rechte Ecke im entsperrten Zustand ziehen:
  Höhe und Breite aller verbundenen Fenster gleichzeitig ändern.
  Die Zeilenzahl wird an die verfügbare Bildschirmhöhe angepasst.
- Schriftrollen-Icon im Header: verfügbare Kämpfe auswählen; Live kehrt zur aktuellen Anzeige zurück.
  Der Verlauf enthält die vom Spiel gespeicherten Sitzungen bis zum Reset.
- Im Guide lassen sich Akzent- und Headerfarbe per Farbauswahl einstellen.
- Die animierte Demo-Vorschau simuliert wechselnde Ranglisten und Balken.
- Mausrad über dem Meter: weitere Spieler anzeigen.
- Türkiser Markierungsstrich: eigener Charakter.
- Positionen, Modi, Größen, Verknüpfungen, Sperren und
  Einstellungen bleiben je Charakter gespeichert, auch nach /reload.

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
