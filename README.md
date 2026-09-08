<div align="center">
  <img src="https://github.com/pterodactyl.png?size=180" width="110" alt="Pterodactyl">
  <h1>ZxvCode Pterodactyl Installer</h1>
  <p>Interactive Panel & Wings setup with validation, diagnostics, backups, protection checks, and a clean dark interface.</p>
  <p>
    <a href="https://pterodactyl.io/"><img src="https://img.shields.io/badge/Pterodactyl-Official-0d1117?style=for-the-badge&logo=pterodactyl&logoColor=white" alt="Pterodactyl"></a>
    <a href="https://github.com/NanoXyinDev"><img src="https://img.shields.io/badge/GitHub-NanoXyinDev-0d1117?style=for-the-badge&logo=github" alt="GitHub NanoXyinDev"></a>
  </p>
</div>

<div align="center">
  <img src="https://readme-typing-svg.demolab.com?font=JetBrains+Mono&weight=600&size=20&duration=2800&pause=900&color=8B9CFF&center=true&vCenter=true&width=760&lines=Interactive+Pterodactyl+setup;Panel+%2B+Wings+%2B+Node+workflow;Health+checks+%2B+safe+backups;Clean+dark+panel+appearance" alt="Animated project description">
</div>

---

## What it provides

- Interactive Panel setup: domain, database, administrator, URL, PHP, Composer, Nginx, Redis and MariaDB.
- Interactive Node profile: name, description, location, FQDN, SSL, proxy, memory, disk, daemon/SFTP ports and allocations.
- Wings installation with architecture detection and systemd integration.
- DNS and input validation before important configuration steps.
- Health and diagnostics menu for PHP, Composer, MariaDB, Redis, Nginx, Docker, Wings and Panel state.
- Safe Panel backups containing `.env`, database dump when available, Wings configuration and Node profile.
- Backup archive verification before relying on a recovery file.
- Clean dark Panel appearance with animated ambient background, glass-like surfaces and responsive controls.
- Protection manifest checksum verification, PHP linting and automatic backups before replacement.
- No fabricated protection handlers: the supplied source is treated according to its actual manifest.

## Interactive flow

```text
Panel domain
     │
     ├── Database + Redis
     ├── PHP + Composer
     ├── Nginx + SSL
     ├── Admin account
     │
     └── Node profile
           ├── Location
           ├── FQDN
           ├── Resources
           ├── Ports
           └── Allocation range
                    │
                    ▼
                 Wings
                    │
                    ▼
             Panel Node config
```

The installer does not invent the authoritative Wings `config.yml`. Pterodactyl's documented workflow is to create the Node in the Panel, open its Configuration tab, and place the generated configuration in `/etc/pterodactyl/config.yml`. See the [official Wings documentation](https://pterodactyl.io/wings/1.0/installing).

## Panel appearance

The optional theme is installed as a separate stylesheet so the Panel can keep its normal frontend assets. A backup of the affected layout and theme file is created before installation.

The theme includes:

- animated ambient glow
- subtle grid background
- glass-like panels
- cleaner form controls
- softer shadows
- improved focus states
- custom scrollbar
- responsive-friendly spacing
- local branding mark under `public/zxvcode/`

## Diagnostics & recovery

The installer includes a health check that can quickly verify the services normally required by a working installation. It also provides a backup workflow for configuration and database data.

Backups are stored under:

```text
/var/backups/zxvcode-ptero/
```

## Protection source handling

The protection directory contains 23 manifest entries. The installer verifies the manifest checksum and runs PHP syntax validation before replacing a destination file. It does not invent a missing `PROTECT15` handler simply because payload numbering reaches 23.

## Requirements

The automated Panel path targets Debian and Ubuntu with root access. Wings requires Linux and Docker-capable virtualization; Pterodactyl documents Ubuntu 20.04/22.04/24.04, Debian 11/12/13, and several RHEL-family systems for Wings. See the [official Wings documentation](https://pterodactyl.io/wings/1.0/installing).

For current Panel releases, check the official release page before production deployment. The official repository currently lists the latest stable Panel release separately from the development image. See the [official Panel releases](https://github.com/pterodactyl/panel/releases).

## Run

```bash
chmod +x install.sh
sudo ./install.sh
```

The script is intended to be run interactively as root. Do not pipe an unreviewed copy of any installer into a privileged shell on a production machine.

## Tests

```bash
bash tests/security-test.sh
```

For a shell syntax-only pass:

```bash
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

## Links

- [Pterodactyl](https://pterodactyl.io/)
- [Pterodactyl Panel](https://github.com/pterodactyl/panel)
- [Pterodactyl Documentation](https://github.com/pterodactyl/documentation)
- [NanoXyinDev](https://github.com/NanoXyinDev)

## License

This installer is an independent setup utility for Pterodactyl. Pterodactyl remains the property of its respective project and contributors.


## Remote install

Use the bootstrap entrypoint so the complete project is downloaded before the installer starts.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NanoXyinDev/Installer-Pterodactyl-v1/main/bootstrap.sh)
```

Direct piping of `install.sh` is also supported.


### Menu consolidation
Theme backups are managed from `Backup and recovery`; the Appearance menu only handles applying and rebuilding the theme, avoiding duplicate backup commands.

### Theme installer safety

The ZXV PROTECT theme is installed as a standalone CSS/JavaScript layer. It does not replace the Panel React components. Before activating the theme, the installer checks the Panel Artisan command and compiles Blade views; if that check fails, the layout changes are rolled back automatically. The theme assets are served from `public/zxvcode-panel.css` and `public/zxvcode-panel.js`.

### Latest theme behavior

- Welcome text follows the local time automatically: `PAGI`, `SIANG`, `SORE`, or `MALAM`.
- Old ZXV greeting text is cleaned from supported layouts and from the dashboard DOM so duplicate welcome text does not remain after an update.
- The dashboard server switch is presented as `SHOW ANOTHER SERVER` while keeping the Panel's native behavior.
- Admin and server-creation screens keep the native React/Blade structure and receive the same motion layer.
- Admin server deletion routes through the protected deletion service so the Panel record, Wings data, databases, and the matching Pterodactyl volume are handled together. Volume cleanup is constrained to the configured Pterodactyl volume root and the server UUID.
