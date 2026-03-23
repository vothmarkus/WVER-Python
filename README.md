# README – WVER-Skripte

## Zweck

Diese Skripte lesen ausgewählte Messwerte aus dem WVER-Messdatenportal aus und stellen sie in Python strukturiert zur Verfügung bzw. geben sie formatiert in der Konsole aus.

Aktuell werden nur die fachlich interessanten Ist-Werte berücksichtigt, insbesondere:

- Wasserstand
- Abfluss
- Abgabe
- Zufluss
- Wasserstand seit WWJ 2001
- Wasserstand Hauptsee
- Wasserstand Hauptsee seit WWJ 2001
- Abgabe Hauptsee
- Zufluss Obersee
- Wasserstand Obersee

Planwerte und Betriebsplan-Kurven werden bewusst nicht ausgegeben.

## Dateistruktur

### `wver_stationen.py`
Enthält nur die Konfiguration der Messstellen.

Dort sind je Station hinterlegt:

- Anzeigename
- Referenz zur Webseite
- Primärsignal
- verfügbare Signal-URLs

Diese Datei dient ausschließlich als Datenbasis.

### `wver_extract.py`
Enthält die komplette Extraktionslogik.

Aufgaben:

- Abruf der Daten von WVER
- Unterscheidung zwischen:
  - Pegel-/Wehrdaten per Range-Download
  - Talsperrendaten per vollständigem JSON
- Ermittlung des letzten gültigen numerischen Werts
- Vereinheitlichung der Einheiten
- Export in eine JSON-Datei

Wichtige Funktion:

- `extract_station_data()`  
  Liefert alle extrahierten Werte als Python-Dictionary zurück.

- `save_results()`  
  Speichert die Ergebnisse als `wver_interesting_latest.json`.

### `wver_print.py`
Enthält nur die Ausgabe in der Konsole.

Aufgaben:

- Import der Daten aus `wver_extract.py`
- Formatierung von Datum/Uhrzeit
- Formatierung der Werte
- tabellarische Ausgabe je Station

## Voraussetzungen

Benötigt wird nur Standard-Python.

Verwendete Module:

- `json`
- `re`
- `urllib.request`
- `datetime`

Es sind keine zusätzlichen Pakete wie `requests` erforderlich.

## Verwendung

### 1. Werte extrahieren und als JSON speichern
```bash
python wver_extract.py
```

Ergebnis:

- Datei `wver_interesting_latest.json` wird erzeugt

### 2. Werte formatiert in der Konsole anzeigen
```bash
python wver_print.py
```

Beispielausgabe:
```text
Stb. Heimbach UW                       Datum                            Wert
-------------------------------------- -------------------- ----------------
wasserstand                            23.03.2026 - 08:45           56,4 cm
abfluss                                23.03.2026 - 08:45           7,4 m³/s
```

## Logik der Auswertung

### Pegel / Wehre
Bei Pegel- und Wehrdaten wird nur das Ende der Datei per HTTP-Range geladen.  
Das ist schnell und spart Bandbreite.

Diese Daten liegen typischerweise als Zeit-Wert-Paare vor.

### Talsperren
Bei Talsperrendaten wird das vollständige JSON geladen.  
Dort liegen die Werte strukturiert in:

- `columns`
- `data`

Die letzte Zeile ist nicht immer gültig, da für den aktuellen Tag oft noch `"-"` eingetragen ist.  
Deshalb wird von hinten nach vorne der letzte gültige numerische Wert gesucht.

## Einheiten

Falls vom WVER keine brauchbare Einheit geliefert wird, werden Fallbacks gesetzt:

- `wasserstand*` → `cm`
- `abfluss`, `abgabe`, `zufluss*` → `m³/s`

Zusätzlich wird ein fehlerhaft kodiertes `m�/s` automatisch zu `m³/s` korrigiert.

## Hinweise

- Talsperrenwerte sind oft Tageswerte und daher nicht so aktuell wie Pegelwerte im 15-Minuten-Raster.
- Einige Reihen wie `...seit_wwj2001` können aktueller sein als die normalen Tagesmittelreihen.
- Wenn eine Quelle vorübergehend keinen numerischen Wert enthält, wird dies als Fehler bzw. leerer Wert sichtbar.

## Empfohlene Weiterverwendung

Die Skripte eignen sich gut als Basis für:

- Home Assistant
- JSON-Export für Automationen
- Logging historischer Werte
- zyklische Ausführung per Cron oder Task Scheduler

## Empfohlener Projektaufbau

```text
projektordner/
├── wver_stationen.py
├── wver_extract.py
├── wver_print.py
└── wver_interesting_latest.json
```

## Kurzfassung

- `wver_stationen.py` = Konfiguration
- `wver_extract.py` = Daten holen und verarbeiten
- `wver_print.py` = formatiert ausgeben

## Haftungsausschluss

Diese Integration ist ein inoffizielles Projekt.  
Es besteht keine Verbindung zum Wasserverband Eifel-Rur oder zu Home Assistant.

## Lizenz

MIT.
