# Tourspur

Tourspur für das iPhone: Strecken live aufzeichnen, als GPX exportieren, über iCloud Drive synchronisieren, per Siri starten und mit Fotos auf der eigenen WordPress-Website veröffentlichen.

## Funktionen

- **Live-Aufzeichnung** mit Karte, Geschwindigkeit, Höhe, Richtung und GPS-Genauigkeit, auch bei gesperrtem Bildschirm
- **Gespeicherte Strecken** mit Kartenansicht, Statistiken und Höhen-/Geschwindigkeitsprofil
- **GPX-Export** (GPX 1.1) über das iOS-Teilen-Menü
- **Ordner-Sync**: Strecken automatisch in einen selbst gewählten Ordner (z. B. iCloud Drive) schreiben
- **Kurzbefehle und Siri**: Aufzeichnung starten, stoppen oder umschalten
- **Auf WordPress veröffentlichen** (optional): in der Detailansicht einer Strecke Fotos aus der Mediathek auswählen und mit „Auf Website veröffentlichen“ als Beitragsentwurf auf die eigene Website laden (GPX-Datei, Fotos und Fotospur-Block)
- **WordPress-Plugin „Fotospur“**: zeichnet die Strecke im Beitrag ohne Kartendienst und setzt die Fotos anhand von Aufnahmezeit und Ort an die passende Stelle, siehe [`wordpress-plugin/`](wordpress-plugin/)

Keine Benutzerkonten, keine Werbung, kein Tracking. Die Daten bleiben auf dem Gerät, außer du veröffentlichst eine Strecke auf deiner eigenen WordPress-Website.

## Voraussetzungen

- Xcode 15 oder neuer
- iOS 17 oder neuer
- Keine externen Abhängigkeiten, nur Apple-Frameworks (SwiftUI, MapKit, CoreLocation, Charts, AppIntents)

## Selbst bauen

1. Repository klonen und `GPSTracker.xcodeproj` in Xcode öffnen.
2. Unter *Signing & Capabilities* dein eigenes **Team** auswählen.
3. Die **Bundle Identifier** auf eine eigene ID ändern (z. B. `com.deinname.GPSTracker`).
4. Auf einem iPhone ausführen. Für Hintergrund-Aufzeichnung die Standort-Berechtigung „Immer“ erteilen.

## WordPress-Plugin

Tourspur kann Strecken mit Fotos als Beitragsentwurf auf deiner eigenen WordPress-Website veröffentlichen. Dafür brauchst du das Plugin „Fotospur“:

1. [`wordpress-plugin/tourspur-fotospur.zip`](wordpress-plugin/tourspur-fotospur.zip) herunterladen.
2. In WordPress unter **Plugins → Neues Plugin hinzufügen → Plugin hochladen** die ZIP-Datei installieren und aktivieren.
3. Unter **Benutzer → Profil → Anwendungspasswörter** ein Anwendungspasswort anlegen und es mit Website-URL und Benutzername in Tourspur unter **Einstellungen → WordPress** eintragen.

Details in [`wordpress-plugin/README.md`](wordpress-plugin/README.md).

## Projektstruktur

```
GPSTracker/
├── Models/      Track und TrackPoint
├── Services/    LocationManager, TrackStore (Speichern/Sync), GPXExporter
├── Views/       SwiftUI-Ansichten (Live, Liste, Detail, Karte, Diagramme)
└── Intents/     Kurzbefehle/Siri (AppIntents)
wordpress-plugin/ WordPress-Plugin „Fotospur“ für die Veröffentlichung
website/         Produkt- und Datenschutzseite
```

## Mitmachen

Fehlerberichte und Pull Requests sind willkommen. Die Oberfläche ist auf Deutsch, der Code auf Englisch.

## Lizenz

Der Quellcode steht unter der [MIT-Lizenz](LICENSE).

Name „Tourspur“ und App-Icon sind davon ausgenommen: Wer eine eigene Version veröffentlicht, z. B. im App Store, verwendet bitte einen anderen Namen und ein eigenes Icon.
