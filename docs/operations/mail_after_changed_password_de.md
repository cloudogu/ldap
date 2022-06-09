# E-Mail-Versand nach Änderung eines Nutzer-Passworts

Wenn sich bei einem Nutzer das Passwort geändert hat, so wird diesem Nutzer eine E-Mail mit der Information über ein
geändertes Passwort geschickt. Diese E-Mail wird immer verschickt, unabhängig davon, ob der Nutzer selbst sein Passwort
geändert hat oder ob die Passwortänderung durch einen anderen Nutzer, z.B. einem Administrator, erfolgt ist.

Die E-Mail wird an die im LDAP hinterlegte E-Mail-Adresse des Nutzers verschickt.

## Konfiguration des E-Mail Inhalts

Die Absender-E-Mail-Adresse, der Betreff und der Text der E-Mail können über folgende etcd-Werte konfiguriert werden:

* `password_change/notification_enabled`: legt fest, ob die E-Mail-Benachrichtung aktiv sein soll.
* `password_change/mail_sender`: gibt die E-Mail-Adresse an, die als Absender der E-Mail angezeigt wird.
* `password_change/mail_sender_name`: gibt den Namen an, der als Absender der E-Mail angezeigt wird.
* `password_change/mail_subject`: gibt den Betreff der E-Mail an.
* `password_change/mail_text`: gibt den Text der E-Mail an.

Dabei ist Folgendes zu Beachten:

* Diese Werte sind optional. Sind keine Werte gesetzt, so werden Default-Werte verwendet.
* The following placeholders can be used in the e-mail text:
  * `%uid`: Für die User-ID (=Username) des Nutzers
  * `%name`: Für den kompletten Namen (cn) des Nutzers 


 