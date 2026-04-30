# Nginx Virtual Host Automation Script
A Bash script to automate the creation of local virtual hosts on an Nginx web server. It sets up the web root directory, generates a default `index.html`, writes and enables the Nginx server block, registers the domain in a dnsmasq hosts file, and reloads Nginx — with full rollback on any failure.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Options](#options)
- [Configuration](#configuration)
- [How It Works](#how-it-works)
    - [1. Directory creation](#1-directory-creation)
    - [2. Index file generation](#2-index-file-generation)
    - [3. Nginx virtual host configuration](#3-nginx-virtual-host-configuration)
    - [4. DNS host entry](#4-dns-host-entry)
    - [5. Enable site and reload Nginx](#5-enable-site-and-reload-nginx)
- [Rollback Mechanism](#rollback-mechanism)
- [IP Address Selection](#ip-address-selection)
- [Domain Validation](#domain-validation)
- [Examples](#examples)
- [File Structure After Execution](#file-structure-after-execution)
- [Known Limitations](#known-limitations)

---

## Requirements

| Dependency | Purpose |
|---|---|
| `bash` ≥ 4.0 | Script runtime (`mapfile`, `[[ ]]`) |
| `nginx` | Web server being configured |
| `systemctl` | Used to reload Nginx |
| `dnsmasq` | Local DNS resolver for the hosts file |
| `ip` (iproute2) | IPv4 address enumeration |
| Root / `sudo` | Required for all file system and service operations |

---

## Installation

```bash
# Clone or copy the script
cp create_domain.sh /usr/local/bin/create_domain.sh
chmod +x /usr/local/bin/create_domain.sh
```

---

## Usage

```
sudo create_domain.sh -d <domain>
```

The script must be run as **root**.

---

## Options

| Flag | Argument | Description |
|---|---|---|
| `-d` | `<domain>` | *(Required)* The domain name to create |
| (none) | | Prints usage information and exits |

---

## Configuration

These variables are defined at the top of the script and can be adjusted before running:

| Variable | Default | Description |
|---|---|---|
| `WEB_ROOT` | `/var/www/html` | Base path where virtual host directories are created |
| `NGINX_AVAILABLE` | `/etc/nginx/sites-available` | Path for Nginx site configuration files |
| `NGINX_ENABLED` | `/etc/nginx/sites-enabled` | Path for Nginx symlinks (enabled sites) |
| `PREFIX` | `vhost.` | Prefix added to the domain name for the web root directory |
| `INDEX_FILE` | `index.html` | Name of the default index file |
| `HOST_FILE` | `/etc` | Directory containing the dnsmasq hosts file |
| `HOST_NAME` | `dnsmasq.hosts` | Name of the dnsmasq hosts file |

---

## How It Works

### 1. Directory creation

Creates `$WEB_ROOT/$PREFIX$DOMAIN` (e.g., `/var/www/html/vhost.example.com`) using `mkdir -p`. Fails early if the path already exists.

### 2. Index file generation

Writes a minimal `index.html` into the new directory. The page displays the domain name and includes a decorative ASCII art block. Basic dark-mode styling is applied inline.

### 3. Nginx virtual host configuration

Writes a server block to `$NGINX_AVAILABLE/<domain>.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name <domain>;
    root /var/www/html/vhost.<domain>;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### 4. DNS host entry

Prompts the user to select a local IPv4 address (see [IP Address Selection](#ip-address-selection)) and appends an entry to `$HOST_FILE/$HOST_NAME`:

```
<selected_ip>  <domain>
```

`127.0.0.1` is always included in the selection list even if not detected on an interface.

### 5. Enable site and reload Nginx

Creates a symlink from `sites-available` to `sites-enabled`, validates the Nginx configuration with `nginx -t`, and reloads the service with `systemctl reload nginx`.

---

## Rollback Mechanism

The script uses `trap ... ERR` to automatically undo all completed steps if any command fails. Rollback is performed in reverse order:

1. Remove symlink (`sites-enabled/<domain>.conf`)
2. Remove Nginx config (`sites-available/<domain>.conf`)
3. Remove index file (`<domain_dir>/index.html`)
4. Remove virtual host directory

State flags (`CREATED_DIR`, `CREATED_INDEX`, `CREATED_CONF`, `CREATED_SYMLINK`) track which steps have completed so only those are rolled back.

> **Note:** The DNS host entry appended to the dnsmasq hosts file is **not** rolled back on failure.

---

## IP Address Selection

The script enumerates all IPv4 addresses on the system and presents an interactive numbered menu:

```
Select an IP address:
1) 127.0.0.1
2) 192.168.1.10
Enter option number:
```

`127.0.0.1` is always appended to the list if not already present, ensuring a loopback option is always available for purely local domains.

---

## Domain Validation

Domain names are validated against the following regular expression:

```
^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$
```

This enforces:

- Lowercase letters, digits, and hyphens only per label
- Labels cannot start or end with a hyphen
- Labels are at most 63 characters
- At least one dot separating labels
- TLD of at least 2 alphabetic characters

Invalid domains cause the script to exit with an error before any files are created.

---

## Examples

```bash
# Create a virtual host for myapp.local
sudo create_domain.sh -d myapp.local

# Create a virtual host for a multi-part domain
sudo create_domain.sh -d api.dev.example.com
```

---

## File Structure After Execution

```
/var/www/html/
└── vhost.example.com/
    └── index.html

/etc/nginx/
├── sites-available/
│   └── example.com.conf
└── sites-enabled/
    └── example.com.conf  →  (symlink to sites-available)

/etc/dnsmasq.hosts
  192.168.1.10  example.com
```

---

## Known Limitations

- **No HTTPS support.** The generated Nginx config listens on port 80 only. TLS must be configured manually (e.g., with Certbot).
- **DNS entry is not rolled back.** If the script fails after writing to the dnsmasq hosts file, the entry must be removed manually.
- **dnsmasq is not reloaded.** After adding the host entry, dnsmasq must be restarted separately for the DNS change to take effect.
- **No duplicate DNS check.** The script does not verify whether the domain already exists in the dnsmasq hosts file before appending.
- **Uppercase domains are rejected.** The domain regex requires all-lowercase input.
