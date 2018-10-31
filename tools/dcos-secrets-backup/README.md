# DC/OS Secrets Backup and Restore Utility
This is a minimal viable product that should back up and restore secrets from a DC/OS cluster using the DC/OS Secrets APIs.  Secrets are encrypted at rest (with AES256 and a default or specified cipher key), and stored in a flat tar file.

## Usage
backup with:
```bash
./dcos-secrets-backup \
    --hostname <dcos-master-hostname> \
    --username <superuser-uid> \
    --password <superuser-password> \
    [--cipherkey <32-byte-cipher-key>] \
    [--destfile <location-for-output-tar>] \
    backup
```


restore with:
```
./dcos-secrets-backup \
    --hostname <dcos-master-hostname> \
    --username <superuser-uid> \
    --password <superuser-password> \
    [--cipherkey <32-byte-cipher-key>] \
    [--sourcefile <location-for-output-tar>] \
    restore
```

## Behavior:
`backup` will grab all secrets, encrypt them with aes256 and a cipher key, and store them in a tar file


`restore` will untar the file, decrypt them, and create/update them in the cluster


The tar file location defaults to `secrets.tar`.  It can be changed with `--destfile` (for backup) and `--sourcefile` (for restore)


It will default to use a secret cipher key of `ThisIsAMagicKeyString12345667890` - you can specify this with --cipherkey, and it must be a 32 byte string.


## Caveats
This is a minimal viable product / work in progress.  It works, but it has several things to be aware of:
* This will create secrets that don't exist, and update existing ones (**it will overwrite existing ones - be careful here**)
* If you try to restore with invalid/non-matching cipherkey, I *think* it will fail but I haven't put any actual checks in there (it fails because it's trying to post something that isn't actual JSON and saying it's JSON).
* There is minimal error checking throughout.
* Very minimal testing has occurred.  Try on a non-prod cluster.

## Todo:
* Add certificate verification