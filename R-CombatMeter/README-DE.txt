R-CombatMeter  |  v1.0.10
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
  Unterbrechungen, Bannungen, Tode = Anzahl im aktuellen oder ausgewählten vergangenen Kampf.
  Tode werden nur angezeigt, wenn der Client diesen Meter-Typ unterstützt.
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
- Schriftrollen-Icon im Header: verfügbare Kämpfe mit Gegnerporträts auswählen.
  Porträts werden beim Erfassen sichtbarer Gegner gespeichert; sonst erscheint ein neutrales Symbol.
  Live kehrt zur aktuellen Anzeige zurück.
- Spielerzeilen anklicken: ein angedocktes, größenangepasstes Fähigkeitenpanel öffnet sich oberhalb der Zeile. Erneut anklicken zum Schließen. Bei zu wenig Platz wird das Panel verkleinert oder unterhalb geöffnet.
  Der Verlauf enthält die vom Spiel gespeicherten Sitzungen bis zum Reset.
- Im Guide lassen sich Akzent- und Headerfarbe per Farbauswahl einstellen.
- Die animierte Demo-Vorschau simuliert wechselnde Ranglisten und Balken.
- Mausrad über dem Meter: weitere Spieler anzeigen.
- Türkiser Markierungsstrich: eigener Charakter.
- Einstellungen > Profile: Charakterprofile auswählen, zurücksetzen oder löschen.
  Änderungen werden im ausgewählten Profil gespeichert. Profile sind accountweit verfügbar.
  Bisherige Einstellungen werden beim ersten Login übernommen.
  Positionen, Modi, Größen, Verknüpfungen, Sperren und Farben bleiben nach /reload erhalten.

CHATBEFEHLE
/rcm        Guide erneut öffnen
/rcm demo   Beispieldaten ein- oder ausschalten
/rcm hide   alle Fenster ein- oder ausblenden
/rcm lock   sämtliche Gruppen sperren / entsperren
/rcm reset  gemeinsame Kampfdaten nach Bestätigung löschen

AUTOMATIK
Auto-Reset startet ausschließlich Schaden gesamt bei Instanzwechsel neu.
Der native Kampfverlauf und alle anderen Meter bleiben erhalten.
Beim Dungeonabschluss bleibt die Gesamtanzeige bis zum Verlassen sichtbar.
Geschützte Gesamtdaten werden erst aktualisiert, wenn sie wieder lesbar sind.
Der manuelle Befehl /rcm reset löscht nach Bestätigung weiterhin alle
gemeinsamen Blizzard-Kampfdaten, einschließlich des Verlaufs.
