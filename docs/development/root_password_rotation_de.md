# Rotation des LDAP-Root-Passworts

## Hintergrund

Das LDAP-Backend speichert das Passwort seiner privilegierten Root-DN `cn=admin,<openldap_suffix>` in `olcRootPW`.
Dieses Konto ist unabhängig von CES-Benutzern und Service-Accounts.

Bisher wurde `olcRootPW` nur bei der Datenbankinitialisierung gesetzt. Spätere Änderungen an der verschlüsselten
`rootpwd`-Konfiguration blieben daher wirkungslos. Instanzen, die ursprünglich mit LDAP bis einschließlich Version
2.6.7-4 installiert wurden, können außerdem noch ein Passwort enthalten, das eine ältere `doguctl`-Version mit Gos
`math/rand` erzeugt hat.

## Verhalten beim Start

`startup.sh` ruft jetzt bei jedem Start `applyRootPassword` auf, während der Initialisierungs-Daemon läuft:

1. Sie sucht unterhalb von `cn=config` die Backend-Datenbank, deren `olcSuffix` dem Wert von `OPENLDAP_SUFFIX`
   entspricht.
2. Sie liest `rootpwd` oder erzeugt mit `doguctl random` ein Passwort, wenn der Schlüssel fehlt.
3. Sie hasht das Passwort mit `slappasswd` und ersetzt `olcRootPW` über `ldapi:///`.

Erzeugte Klartextpasswörter werden nicht persistiert, da kein Dogu die Root-DN verwendet. Die Aktualisierung besitzt
keinen Abschluss-Marker und läuft nach jedem Start, auch nach der Wiederherstellung eines alten LDAP-Konfigurations-Volumes.

## Fehlerbehandlung

Wenn das Backend nicht gefunden oder aktualisiert werden kann, protokolliert der Start eine Warnung mit dem Präfix
`[ROOT-PASSWORD]` und läuft weiter, damit die Service-Accounts abgeglichen werden können. Beim nächsten Start folgt
ein neuer Versuch. Passwortwerte werden nie protokolliert.
