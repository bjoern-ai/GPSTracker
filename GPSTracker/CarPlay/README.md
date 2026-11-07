# CarPlay

Apple hat die Berechtigung „CarPlay Driving Task App“ für das Entwicklerkonto erteilt. Sie steht in `GPSTracker/GPSTracker.entitlements`. Diesen Branch erst zusammenführen, wenn die Ansicht im Auto getestet wurde.

## Berechtigung für die App einschalten

1. Auf developer.apple.com unter *Certificates, IDs & Profiles → Identifiers* die App-ID `com.bjoernczibulla.GPSTracker` öffnen.
2. Unter *Capability Requests* bzw. *Additional Capabilities* „CarPlay Driving Task“ aktivieren und speichern.
3. In Xcode das Projekt neu bauen. Die automatische Signierung lädt dann ein passendes Profil.

Danach testen: im Auto oder mit Apples „CarPlay Simulator“ aus den *Additional Tools for Xcode*.
