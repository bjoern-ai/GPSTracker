# Tourspur

Tourspur für das iPhone: Strecken live aufzeichnen, als GPX exportieren, über iCloud Drive synchronisieren und per Siri starten.

## Funktionen

- **Live-Aufzeichnung** mit Karte, Geschwindigkeit, Höhe, Richtung und GPS-Genauigkeit, auch bei gesperrtem Bildschirm
- **Gespeicherte Strecken** mit Kartenansicht, Statistiken und Höhen-/Geschwindigkeitsprofil
- **GPX-Export** (GPX 1.1) über das iOS-Teilen-Menü
- **Ordner-Sync**: Strecken automatisch in einen selbst gewählten Ordner (z. B. iCloud Drive) schreiben
- **Kurzbefehle und Siri**: Aufzeichnung starten, stoppen oder umschalten

Keine Benutzerkonten, keine Werbung, kein Tracking. Die Daten bleiben auf dem Gerät.

## Voraussetzungen

- Xcode 15 oder neuer
- iOS 17 oder neuer
- Keine externen Abhängigkeiten, nur Apple-Frameworks (SwiftUI, MapKit, CoreLocation, Charts, AppIntents)

## Selbst bauen

1. Repository klonen und `GPSTracker.xcodeproj` in Xcode öffnen.
2. Unter *Signing & Capabilities* dein eigenes **Team** auswählen.
3. Die **Bundle Identifier** auf eine eigene ID ändern (z. B. `com.deinname.GPSTracker`).
4. Auf einem iPhone ausführen. Für Hintergrund-Aufzeichnung die Standort-Berechtigung „Immer“ erteilen.

## Projektstruktur

```
GPSTracker/
├── Models/      Track und TrackPoint
├── Services/    LocationManager, TrackStore (Speichern/Sync), GPXExporter
├── Views/       SwiftUI-Ansichten (Live, Liste, Detail, Karte, Diagramme)
└── Intents/     Kurzbefehle/Siri (AppIntents)
website/         Produkt- und Datenschutzseite
```

## Mitmachen

Fehlerberichte und Pull Requests sind willkommen. Die Oberfläche ist auf Deutsch, der Code auf Englisch.

## Lizenz

Der Quellcode steht unter der [MIT-Lizenz](LICENSE).

Name „Tourspur“ und App-Icon sind davon ausgenommen: Wer eine eigene Version veröffentlicht, z. B. im App Store, verwendet bitte einen anderen Namen und ein eigenes Icon.
