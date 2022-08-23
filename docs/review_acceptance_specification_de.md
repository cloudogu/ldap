# Abnahmebedingungen beim Review
Damit dieses Dogu bei einem Review abgenommen werden kann, müssen **alle** der folgenden Bedingungen erfüllt sein.

1. Es wurde ein Pull-Request angelegt
2. Es gibt keine Merge-Konflikte mit dem develop Branch
3. Es ist möglich, von der vorher neusten Version auf diese Version ohne Fehler zu Upgraden
4. Es ist möglich, von einer alten Version (`2.4.48-3` (Stand 23.08.2022)) ohne Fehler auf diese Version zu Upgraden
5. Für **mindestens** alle neuen Features in Bash-Scripten wurden BATS-Tests angelegt
6. Es wurden für Veränderungen am Datei-System des Containers Goss-Tests angelegt. Vorhandene Goss-Tests sind erfolgreich
7. ShellCheck zeigt keine Fehler in Shell-Scripten an
8. Das Jenkins-Build läuft zuverlässig erfolgreich durch
9. Mögliche Kommentare (entweder durch reviewdog oder einen menschlichen Reviewer) an dem Pull-Request wurden alle geprüft und erledigt
10. Die Funktion, die eine Mail versendet, nachdem das Passwort eines Nutzers geändert wurde, funktioniert weiterhin
11. Alle Dogus, die eine Abhängigkeit auf LDAP haben, funktionieren weiterhin mit der neuen Version. Das sind mindestens die folgenden:
    * Jira (indirekt über das ldap-mapper-dogu) => Synchronisieren von Nutzern und Gruppen
    * Confluence (indirekt über das ldap-mapper-dogu) => Synchronisieren von Nutzern und Gruppen
    * Teamscale => Synchronisieren von Nutzern und Gruppen
    * CAS => Login ist möglich, Passwortänderung bei abgelaufenem Passwort, Passwortrichtlinie funktioniert (im CAS)
    * User-Management => Nutzer können angelegt & bearbeitet & gelöscht werden, Password-Reset-Flag kann gesetzt werden, Passwortrichtlinie funktioniert (im Usermgt)
12. Wenn das Dogu initial (beim ldap nur über das ces-setup möglich) installiert wird, funktioniert es
13. Es können Service-accounts erstellt werden (`cesapp command ldap service-account-create test`)
14. Die neuen Features wurden unter Angabe der Issue-Nummer im Changelog hinterlegt