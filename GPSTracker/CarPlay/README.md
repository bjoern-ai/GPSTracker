# CarPlay

Die CarPlay-Ansicht ist fertig angelegt, aber noch nicht aktiv: Ohne Apples CarPlay-Berechtigung erscheint Tourspur nicht in CarPlay. Diesen Branch erst zusammenführen, wenn die Berechtigung da ist und die Ansicht im Auto getestet wurde.

## Sobald Apple die Berechtigung erteilt hat

1. In der Mail von Apple prüfen, welche Kategorie erteilt wurde. Der Code ist für „Driving Task“ gebaut. Bei einer anderen Kategorie sind andere Vorlagen erlaubt, dann muss die Ansicht angepasst werden.
2. Auf developer.apple.com unter *Certificates, IDs & Profiles → Profiles* ein Provisioning Profile für `com.bjoernczibulla.GPSTracker` anlegen und dabei unter *Entitlements* die CarPlay-Berechtigung auswählen. Das Profil in Xcode importieren und für das Target `GPSTracker` auswählen.
3. In Xcode eine Datei `GPSTracker/GPSTracker.entitlements` anlegen und dem Target unter *Code Signing Entitlements* zuweisen, mit diesem Eintrag:

   ```xml
   <key>com.apple.developer.carplay-driving-task</key>
   <true/>
   ```

4. Testen: im Auto oder mit Apples „CarPlay Simulator“ aus den *Additional Tools for Xcode*.
