# Fotospur

Bildergalerie für rollermomente.de: Die Fotos einer Tour sitzen an der Stelle der
Tourspur-Strecke, an der sie aufgenommen wurden. Ein Regler oder „Abspielen“ fährt
die Strecke ab und blendet die Fotos ein, darunter liegt das Höhenprofil.

Die Strecke wird als SVG gezeichnet, ohne Kartenkacheln oder andere Dienste.

## Benutzung

1. Tour in Tourspur als GPX exportieren.
2. Daten erzeugen (Zeit und Ort der Fotos kommen aus den EXIF-Daten):

   ```
   python3 gpx_to_fotospur.py tour.gpx IMG_0001.jpeg IMG_0002.jpeg \
       --url-prefix https://rollermomente.de/wp-content/uploads/2026/10/
   ```

   Ohne Bilddateien geht es auch per Hand: `"Adresse|Titel|HH:MM"`.
3. Die Ausgabe in WordPress als Block „Individuelles HTML“ einfügen.
   `fotospur.css` und `fotospur.js` (im Plugin-Ordner unter `assets/`) müssen einmal auf der Seite eingebunden sein.

Einfacher geht es mit dem WordPress-Plugin in `../wordpress-plugin/rollermomente-fotospur/`:
Es bringt den Block „Fotospur“ mit, in dem man GPX-Datei und Fotos direkt aus der Mediathek auswählt.
