# WordPress-Plugin „Fotospur“

Mit diesem Plugin kann Tourspur Strecken direkt auf deiner eigenen WordPress-Website veröffentlichen. Es stellt den Block **Fotospur** bereit: Er zeichnet die Strecke aus der GPX-Datei, zeigt Kilometer, Dauer und Höhenmeter und setzt deine Fotos an die Stelle der Strecke, an der sie aufgenommen wurden.

Die Strecke wird ohne Kartendienst gezeichnet, es werden keine Daten an Dritte übertragen.

## Voraussetzungen

- WordPress 6.5 oder neuer, PHP 7.4 oder neuer
- Website über **https** erreichbar
- Ein Benutzer mit der Rolle *Autor* oder höher

## Installation

1. [`tourspur-fotospur.zip`](tourspur-fotospur.zip) herunterladen.
2. In WordPress: **Plugins → Neues Plugin hinzufügen → Plugin hochladen**, die ZIP-Datei auswählen und **Jetzt installieren** tippen.
3. Plugin **aktivieren**.
4. **Benutzer → Profil → Anwendungspasswörter**: einen Namen eingeben (z. B. „Tourspur“) und **Neues Anwendungspasswort hinzufügen**. Das angezeigte Passwort kopieren.
5. In Tourspur unter **Einstellungen → WordPress** die Website-URL (z. B. `https://meine-website.de`), deinen WordPress-Benutzernamen und das Anwendungspasswort eintragen und **Verbindung testen**.

Du hast noch die erste Version (`rollermomente-fotospur`) installiert? Erst das neue Plugin aktivieren, dann das alte deaktivieren und löschen. Bestehende Beiträge funktionieren weiter.

## Benutzung

- **Aus der App:** In einer gespeicherten Strecke optional Fotos auswählen und **Auf Website veröffentlichen** tippen. Tourspur lädt die GPX-Datei und die Fotos in die Mediathek und legt einen Beitragsentwurf mit dem Fotospur-Block an. Den Entwurf prüfst und veröffentlichst du im WordPress-Editor.
- **Im Editor:** Den Block „Fotospur“ in einen Beitrag einfügen, eine GPX-Datei und Fotos auswählen.

Fotos ohne Aufnahmezeit und Ort werden gleichmäßig in der gewählten Reihenfolge auf der Strecke verteilt; ein Hinweis darauf ist nur für angemeldete Redakteure sichtbar.

Mehrere Fotos von derselben Stelle teilen sich einen Punkt auf der Strecke (z. B. „3–5“). Beim Abspielen hält die Fotospur dort an und zeigt die Fotos nacheinander, mit den Pfeilen im Foto lässt sich auch von Hand blättern.

## Datenschutz

Die App sendet die Daten direkt vom iPhone an die eingetragene Website (WordPress-REST-API über https). Das Anwendungspasswort wird im Schlüsselbund des iPhones gespeichert und lässt sich in WordPress jederzeit widerrufen.

## Lizenz

MIT, wie die App. Enthält die Schrift IBM Plex Mono © IBM Corp. unter der SIL Open Font License 1.1.
