# Password-Richtlinien

Im LDAP-Dogu wird standardmäßig eine Passwort-Richtlinie angelegt. Diese Passwort-Richtlinie ist aktuell minimalistisch
gehalten.

## Struktur und Abruf der Default-Passwort-Richtlinie

Für Richtlinien ist im LDAP eine Organisational Unit (OU) mit entsprechenden Namen angelegt worden. Diese ist unter
`dn: ou=Policies,o=ces.local,dc=cloudogu,dc=com` zu finden.

Um alle Einträge unter der OU `Policies` abzurufen, können folgende Befehle ausgeführt werden:

1. Aufrufen der bash-Shell innerhalb des LDAP-Docker-Containers: `docker exec -it ldap bash`
2. Ausführen der LDAP-Suche: `ldapsearch -b "ou=Policies,o=ces.local,dc=cloudogu,dc=com"`<br>
   Dieser Befehl liefert alle Einträge, die unterhalb dieses Eintrags zu finden sind, sowie den Eintrag selbst zurück.
   Die Standard-Passwort-Richtlinie ist diesem Eintrag untergeordnet.<br>
   Die Option `-b` gibt an, dass nach dem Eintrag, der nach der Option angegeben ist, gesucht wird.

## Inhalt der Default-Passwort-Richtlinie

Die Standard-Passwort-Richtlinie ist folgendermaßen aufgebaut:

```
dn: cn=default,ou=Policies,o=ces.local,dc=cloudogu,dc=com
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
```

Die einzelnen Werte haben folgende Bedeutung:

* `dn`: `dn` ist die Abkürzung für `Distinguished Name` und identifiziert einen Eintrag eindeutig. Der DN repräsentiert
  dabei ein Objekt in einem hierarchischen Verzeichnis. Der DN wird von den unteren zu übergeordneten Hierarchiestufen
  von links nach rechts geschrieben. So liegt die `default`-Policy unter der OU `policies`.
* objectClass: Die beiden Objektlassen, `person` und `pwdPolicy` geben an, welche Attribute verwendet werden können.
  Hier können nun alle Werte der Objektklasse `person` und `pwdPolicy` verwendet werden. Die Attribute `cn` und `sn`
  stammen aus der Objektklasse Person, die Attribute `pwdAttribute` und `pwdMustChage` aus der Objektklasse `pwpolicy`
  .<br>
  Zwar werden die beiden Attribute `cn` und `sn` der Objektklasse `person` nicht zwingend benötigt, es ist jedoch
  erforderlich, dass ein Eintrag eine strukturierte (`STRUCTUAL`) Objektklasse besitzt. Die Objektklasse `pwdPolicy` ist
  lediglich eine Hilf-Klasse (`AUXILARY`) und somit alleine nicht ausreichend.
* `cn`: `cn` ist die Abkürzung für `Common Name` und hat in diesem Zusammenhang keine besondere Bedeutung und ist eine
  reine Meta-Information.
* `sn`: `sn` ist die Abkürzung für `Surname` (Nachname) und hat in diesem Zusammenhang keine besondere Bedeutung und ist
  eine reine Meta-Information.
* `pwdAttribute`: Enthält den Namen des Attributs, auf das die Kennwortrichtlinie angewendet wird. In diesem Fall wird
  die Passwort-Richtlinie auf das Nutzer-Attribut `userPassword` angewendet.
* `pwdMustChange`: Gibt mit dem Wert `TRUE` an, dass ein Nutzer (technisch ein LDAP-Eintrag) sein Passwort ändern muss,
  wenn bei ihm das Attribut `pwdReset` auf `TRUE` gesetzt wird.<br>
  Beide Attribute funktionieren nur in Kombination miteinander. Das heißt, ist der Wert `pwdReset` beim Nutzer gesetzt,
  der Wert `pwdMustChange` in der Passwort-Richtlinie steht auf falsch, dann muss der Nutzer sein Passwort nicht ändern.

## Attribut zum Ändern des Passworts beim Nutzer setzen

Um den Nutzer zu einer Passwort-Änderung nach dem Login zu zwingen, muss beim LDAP-Eintrag des Nutzers explizit der Wert
des Attributes `pwdReset` gesetzt werden. Dieses Attribut wird nicht automatisch beim Anlegen eines neuen Eintrags
gesetzt.

Dieses Attribut dient dazu, um anzuzeigen (wenn `TRUE`), dass das Passwort von einem Administrator aktualisiert worden
ist und vom Benutzer geändert werden muss. Ändert der Nutzer sein Passwort, wird in diesem Zuge jedoch vom LDAP
automatisch das Attribut entfernt.

Das Attribut `pwdReset` ist ein sogenanntes `operational Attribute`, das standardmäßig - z.B. bei einer Suche
mit `ldapsearch` - nicht mit zurückgeliefert wird. Um bei einer Suche mit `ldapsearch` die operationalen Attribute mit
anzuzeigen, muss zu der Suche am Ende ein `+` hinzugefügt werden. Um z.B. den Eintrag des Admin-Nutzers inkl.
operationaler Attribute auszugeben, kann folgender Befehl verwendet werden:
`ldapsearch -b "uid=admin,ou=People,o=ces.local,dc=cloudogu,dc=com" +`
Weitere operationale Attribute sind z.B. das Erstellungsdatum des Eintrags und das Datum der letzten Änderung.

### `pwdReset`-Attribut manuell bei einem Nutzer setzen

Um bei einem Nutzer manuell den Wert für das Attribut `pwdReset` zu setzen, kann folgender `ldapmodify`-Befehl
ausgeführt werden. Der Befehl setzt für den Nutzer `admin` das `pwdReset`-Attribut auf `TRUE`, sodass dieser beim Login
sein Passwort ändern muss.

```
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: uid=admin,ou=People,o=ces.local,dc=cloudogu,dc=com
changetype: modify
add: pwdReset
pwdReset: TRUE
EOF
```

## Verknüpfung der Passwort-Richtlinie zu anderen Einträgen

Bei der Installation des Passwort-Richtlinien-Moduls kann ein Default-Eintrag angegeben werden. Dieser Eintrag wird
verwendet, wenn es keine spezifische Angabe für bestimmte Einträge gibt.

Die aktuelle und oben beschriebene Password-Richtlinie ist die aktuelle Standard-Passwortrichtlinie. Diese gilt für alle
Einträge. Da dort keine Regeln, die automatische eine Aktion erfordern, wie z.B. ein Passwort-Ablaufdatum, ist dies
unproblematisch.

Wenn jedoch weitere Passwort-Regeln hinzukommen, muss die Passwort-Richtlinie ggf. so angepasst werden, dass diese nicht
für technische Nutzer und Service-Accounts gelten.