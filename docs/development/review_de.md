# Wichtig zu beachten beim Review des LDAP-Dogus
Folgende Dinge sollten bei jedem Upgrade des LDAP-Dogus **unbedingt** getestet werden:
- Kann von einer älteren Version direkt auf die neue geupgraded werden? z.B. `2.4.48-3`. 
  - Sollte es nicht möglich sein, muss das upgrade im `pre-upgrade.sh`-Script unterbunden werden!
- Werden nach der Password-Änderunge weiterhin Mails verschickt, die darüber benachrichtigen?
- Ist es noch möglich, User anzulegen & zu updaten?
- Kann man das Passwort beim nächsten Login über CAS noch zurücksetzen lassen? (Checkbox dafür beim Bearbeiten des Users auswählen)
- Ist es noch möglich, Service-Accounts zu erstellen?