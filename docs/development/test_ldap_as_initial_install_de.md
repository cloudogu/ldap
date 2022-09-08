# Lokale LDAP-Version als Initial-Installation testen

Es ist nicht bzw. nur sehr schwierig möglich, LDAP zu purgen und neu zu installieren.
Es ist aber sinvoll, vor dem Release von LDAP zu testen, wie es sich verhält, wenn es initial installiert bzw. über das 
CES-Setup installiert wird. Dies ist mit einem einfachen Trick möglich:

1. Auf einem vorinstallierten CES die zu testende LDAP-Version mit `cesapp build .` bauen
2. LDAP-Image-ID herausfinden (z.B. mit `docker images`) und dann mit `docker save image-id > /vagrant/ldap.tar.gz` exportieren
3. In ein CES wechseln, in dem das ces-setup noch nicht durchlaufen wurde
4. Das alte Image mit `docker load < /vagrant/ldap.tar.gz` importieren
5. Mit `docker images` die Image-ID des grade geladenen images herausfinden
6. Herausfinden, welches das neuste LDAP-Release ist: https://github.com/cloudogu/ldap/releases
7. Taggen des Images: `docker tag <image-id> registry.cloudogu.com/official/ldap:<release-version>`
8. Durchführen des CES-Setups

Das Ces-Setup wird versuchen, immer die neuste LDAP-Version zu installieren.
Beim Pull des LDAP-Images wird dann (wenn der Tag richtig gesetzt wurde) nicht das neuste Image pullen, sondern
das von uns vorher importierte Image verwenden.
Für die meisten Fälle ist dieses Vorgehen ausreichend, wenn aber die dogu.json der alten LDAP-Version nicht mit dem
importierten Image kompatibel ist (z.B durch veränderte Volumes), wird dieses Vorgehen nicht funktionieren.