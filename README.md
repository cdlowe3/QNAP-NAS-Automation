# QNAP NAS Automation

Ansible playbooks for automating QNAP NAS monitoring, maintenance, and firmware updates.

These playbooks are written to work with QNAP's BusyBox-based QTS operating system, which has no Python support — all tasks use Ansible's `raw` module to run shell commands directly on the NAS.

Built and tested on a QNAP TS-464 running QTS 5.x.

---

## What's Included

| Playbook | What it does |
|---|---|
| `QNAP_Firmware_Check.yaml` | Checks for QTS updates, downloads and applies them, waits for reboot, verifies new version |
| `QNAP_Quick_Status.yaml` | Health snapshot — uptime, memory, CPU load, disk usage, top processes |
| `QNAP_Storage_Monitor.yaml` | Storage deep-dive — filesystem usage, RAID/MD status, disk I/O, saves a full report |
| `QNAP_Security_Audit.yaml` | Security check — open ports, running services, authorized SSH keys, recent logins |
| `QNAP_Network_Status.yaml` | Network services — SMB/NFS status, listening ports, interface info, share listing |

All playbooks follow a **PRE-CHECK / COLLECT or CONFIGURE / POST-CHECK** pattern so you always see what state the system is in before and after any change.

---

## Requirements

- **Ansible 2.12+** installed on your control machine (the laptop or desktop you run playbooks from)
- **SSH access** to your QNAP NAS with the admin account
- **SSH key authentication** set up on the NAS (see [Setting Up SSH Keys](#setting-up-ssh-keys))
- No Python or extra packages needed on the NAS itself

### Installing Ansible

On macOS:
```bash
brew install ansible
```

On Linux (Debian/Ubuntu):
```bash
sudo apt install ansible
```

---

## Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/cdlowe3/QNAP-NAS-Automation.git
cd QNAP-NAS-Automation
```

### 2. Set up your inventory

The inventory file tells Ansible where your NAS is. Copy the example and fill in your details:

```bash
cp inventory.example inventory
```

Open `inventory` in a text editor and replace the placeholder IPs with your NAS's actual IP address:

```ini
[nas]
my-qnap-nas  ansible_host=192.168.1.100   # Replace with your NAS IP
```

### 3. Set up your variables

```bash
cp group_vars/qnap/vars.yaml.example group_vars/qnap/vars.yaml
cp group_vars/qnap/vault.yaml.example group_vars/qnap/vault.yaml
```

Open `group_vars/qnap/vault.yaml` and replace the placeholder password with your NAS admin password.

Then encrypt the vault file so your password is never stored in plain text:

```bash
ansible-vault encrypt group_vars/qnap/vault.yaml
```

You will be asked to create a vault password. Write that vault password to a file called `.vault_pass` so you do not have to type it every time:

```bash
echo "your_vault_password_here" > .vault_pass
chmod 600 .vault_pass
```

The `.vault_pass` file is listed in `.gitignore` so it will never be committed to git.

### 4. Test connectivity

```bash
ansible nas -m ping -i inventory
```

A successful response looks like:
```
my-qnap-nas | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

If this fails, double-check your NAS IP in the inventory and make sure SSH is enabled on your QNAP (Control Panel > Network & File Services > Telnet / SSH).

### 5. Run your first playbook

```bash
bash scripts/run_quick_status.sh
```

The script will ask if you are on the local network (y) or connecting remotely via Tailscale (n), then run the playbook and save a log file to `Logs/qnap/`.

---

## Setting Up SSH Keys

By default QNAP requires a password for each SSH connection. Setting up key-based authentication means Ansible can connect without prompting for a password every time.

**Step 1 — Generate a key on your control machine** (skip this if you already have one at `~/.ssh/id_ed25519`):

```bash
ssh-keygen -t ed25519 -C "homelab"
```

Press Enter to accept the default file location. Set a passphrase or leave it blank.

**Step 2 — Copy your key to the NAS:**

```bash
ssh-copy-id admin@192.168.1.100
```

You will be prompted for your NAS admin password one last time. After this, SSH will use your key instead.

**Step 3 — Verify it works:**

```bash
ssh admin@192.168.1.100
```

You should connect without a password prompt.

---

## Playbook Details

### QNAP_Firmware_Check.yaml

Handles the full firmware update process without any manual steps. In interactive mode it downloads the update and asks you to confirm before applying. In headless mode (for cron jobs) it applies automatically.

**How it works:**
1. Gets the firmware XML feed URL from QNAP's built-in `auto_update` tool
2. Runs `get_new_firmware` to compare your current version to the latest available
3. Downloads the zip if a newer version exists
4. Prompts for confirmation (or auto-confirms in headless mode)
5. Extracts and applies the firmware, then reboots the NAS
6. Waits for the NAS to come back online (up to 20 minutes)
7. Verifies the new firmware version
8. Optionally checks and renews a Tailscale certificate if firmware reset it

**Running interactively:**
```bash
bash scripts/run_firmware_check.sh
```

**Running headless (for a cron job):**
```bash
bash scripts/run_firmware_check.sh --headless
```

**Note on Tailscale cert renewal:** If you serve a Docker container over Tailscale HTTPS, QNAP firmware updates sometimes reset `/root/` and delete your cert files. The playbook detects this and re-runs `tailscale cert` automatically. To use this feature, set `tailscale_hostname` and `tailscale_app_container` in `group_vars/qnap/vars.yaml`. If you do not use Tailscale, those tasks are skipped.

---

### QNAP_Quick_Status.yaml

A fast health snapshot. Good to run before making changes to confirm baseline state, or any time you want a quick look at what is going on.

Output includes:
- System uptime and load average
- Memory usage
- Disk space across all volumes
- Running process count
- Top processes by CPU
- Active network connections

Saves a timestamped report to `Logs/qnap/` and appends a one-line entry to a persistent log.

```bash
bash scripts/run_quick_status.sh
```

---

### QNAP_Storage_Monitor.yaml

A deeper look at storage health:
- All mounted filesystems with usage
- RAID/MD array status (from `/proc/mdstat`)
- QNAP storage pools (CACHEDEV, HDA volumes)
- Disk I/O statistics

Writes a full report to `Logs/qnap/storage_report_<timestamp>.txt`.

```bash
bash scripts/run_storage_monitor.sh
```

---

### QNAP_Security_Audit.yaml

Generates a security snapshot useful for periodic review or before/after opening ports. Checks:

- All active network connections
- Services matching ssh, smb, ftp, http
- Processes matching suspicious tool names (nc, netcat, nmap, wget, curl)
- Recent entries from `/var/log/auth.log` or `/var/log/secure`
- All user accounts from `/etc/passwd`
- Authorized SSH keys in `/root/.ssh/authorized_keys`
- All listening ports

Writes a full report to `Logs/qnap/security_audit_<timestamp>.txt`.

```bash
bash scripts/run_security_audit.sh
```

---

### QNAP_Network_Status.yaml

Checks the state of your NAS network services:
- SMB (Windows file sharing) process status
- NFS (Linux file sharing) process status
- All listening ports
- Network interface details
- Contents of `/share/`

```bash
bash scripts/run_network_status.sh
```

---

## Local vs. Remote (Tailscale)

All run scripts ask at startup:

```
Are you on the local network? (y/n)
```

- **y** — uses the `[nas]` group from your inventory (LAN IP, fastest)
- **n** — uses the `[tailscale_nas]` group (Tailscale IP, works from anywhere)

This means the same scripts work whether you are home or remote without changing any files.

---

## Repo Structure

```
QNAP-NAS-Automation/
├── playbooks/
│   ├── QNAP_Firmware_Check.yaml
│   ├── QNAP_Quick_Status.yaml
│   ├── QNAP_Storage_Monitor.yaml
│   ├── QNAP_Security_Audit.yaml
│   └── QNAP_Network_Status.yaml
├── scripts/
│   ├── run_firmware_check.sh
│   ├── run_quick_status.sh
│   ├── run_storage_monitor.sh
│   ├── run_security_audit.sh
│   └── run_network_status.sh
├── group_vars/
│   └── qnap/
│       ├── vars.yaml.example
│       └── vault.yaml.example
├── ansible.cfg
├── inventory.example
└── README.md
```

---

## Troubleshooting

**"UNREACHABLE" when running a playbook**
- Confirm SSH works manually: `ssh admin@<your-nas-ip>`
- Make sure SSH is enabled on the NAS: Control Panel > Network & File Services > Telnet / SSH
- Check that the IP in your inventory matches the NAS

**"Permission denied" errors**
- Confirm your SSH key is deployed: `ssh-copy-id admin@<your-nas-ip>`
- If using a non-admin account, some tasks require root — use `admin`

**Vault password errors**
- Make sure `.vault_pass` exists and contains the correct vault password
- Re-check with: `ansible-vault view group_vars/qnap/vault.yaml --vault-password-file .vault_pass`

**Firmware check says "up to date" but you know there is an update**
- QNAP's `auto_update` tool targets your specific model and region. If the tool returns no update, your device may be on a different update channel than the web UI shows.

---

## Tested On

- QNAP TS-464 running QTS 5.1 and 5.2
- Ansible 2.14+ on macOS (control machine)

---

## Contributing

Pull requests and issues welcome. If you have a different QNAP model or hit a QTS version quirk, open an issue with the playbook output and your model info.
