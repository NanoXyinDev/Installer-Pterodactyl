# Protection Source Audit

The supplied source has named protection handlers PROTECT1 through PROTECT14.

The manifest contains 23 payload entries. Those entries are not 23 handler names: several entries belong to the same handler. The installer does not invent PROTECT15.

If the Panel is absent, the Protection Manager stops before processing the manifest and reports the actual prerequisite failure instead of `Installed 0 ... Failed: 23`.

Every payload is verified against its SHA-256 checksum and PHP payloads are syntax-checked before replacement. Existing destination files are backed up under `/var/backups/zxvcode-ptero`.
