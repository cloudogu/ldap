# # Sending an e-mail after changing a user's password

If a user's password has changed, an e-mail is sent to this user with information about the changed password. This
e-mail is always sent, irrespective of whether the user has changed his password himself or whether the password was
changed by another user, e.g. an administrator.

The e-mail is sent to the user's e-mail address stored in the LDAP.

## Configuration of the e-mail content

The sender e-mail address, the subject and the text of the e-mail can be configured via the following etcd values:

* `mail_sender`: specifies the e-mail address that is displayed as the sender of the e-mail.
* `password_change/mail_subject`: specifies the subject of the e-mail.
* `password_change/mail_text`: specifies the text of the e-mail.

The following should be noted:

* These values are optional. If no values are set, default values are used.
* In the texts, umlauts must be specified in encoded form.
    * `%uid`: Für die User-ID (=Username) des Nutzers
    * `%name`: Für den kompletten Namen (cn) des Nutzers 


 