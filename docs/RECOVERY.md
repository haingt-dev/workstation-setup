# Disaster Recovery System

End-to-end pipeline để restore Hải's workstation từ scratch trên máy mới. Tận dụng OneDrive 5TB làm encrypted cold backup.

## TL;DR

**Backup** (chạy daily tự động sau khi setup):
```bash
~/Projects/workstation-setup/scripts/backup/daily-bundle.sh
```

**Recovery** trên máy mới:
```bash
# Bước 1: Bootstrap (1 lệnh)
curl -fsSL https://raw.githubusercontent.com/haingt-dev/workstation-setup/master/bootstrap.sh | bash

# Bước 2: Theo instructions in ra (3 lệnh):
gh auth login --web
gh repo clone haingt-dev/workstation-setup ~/Projects/workstation-setup
cd ~/Projects/workstation-setup && ./recover.sh
```

Total time: ~60-90 phút trên máy mới. Brain restored, conversations preserved, 6 repos cloned, home-server nguyên trạng.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ DAILY BACKUP DAEMON (cron 4:30 AM)                          │
│                                                              │
│   daily-bundle.sh                                            │
│     ↓                                                        │
│   tar + GPG encrypt (AES256) + rclone push                  │
│     ↓                                                        │
│   OneDrive primary  +  B2 fallback (optional)               │
│   Retention: 7 daily + 4 weekly + 12 monthly                │
└─────────────────────────────────────────────────────────────┘
                          ↓ (disaster strikes)
┌─────────────────────────────────────────────────────────────┐
│ RECOVERY PIPELINE (interactive, 7 phases)                   │
│                                                              │
│ Phase 0: Detect mode (prereqs)                              │
│ Phase 1: System base (./setup.sh)                           │
│ Phase 2: Cloud bundle pull + decrypt                        │
│ Phase 3: Secrets restore (SSH/GPG/gh)                       │
│ Phase 4: Claude state (~/.claude/)                          │
│ Phase 5: Agent + Brain (clone + venv + brain.db)            │
│ Phase 6: 6 critical repos + .env + post-hooks               │
│ Phase 7: Verify + report                                    │
└─────────────────────────────────────────────────────────────┘
```

## Bundle composition

| Section | Contents | Size (est) |
|---|---|---|
| `secrets/` | ~/.ssh, ~/.gnupg, gh token | <1MB |
| `claude/` | CLAUDE.md, core-memory, brains, settings, plans, projects.tar.gz, plugins.tar.gz | ~250MB |
| `envs/` | .env files from 6 critical repos | <1MB |
| `brain/` | brain.db (sqlite .backup, WAL-safe) | 30MB |
| `home-server/` | tier1 (.env × 3), tier2 (configs+DBs), tier3 (Forge outputs, weekly) | ~30MB / ~800MB w/tier3 |
| `ironcradle/` | Godot version pin, user config, VS Code User, extensions list | ~10MB |
| `crontabs/` | user crontab snapshot | <1KB |
| `manifest.txt + repos.txt` | metadata + repo list | <1KB |

**Total**: ~300MB encrypted (daily), ~1GB on weekly snapshots (Tier 3 included).

## Setup (first-time, 1 lần duy nhất)

### 1. rclone OAuth (OneDrive + optional B2)

```bash
rclone config
# n) New remote
#   name: onedrive-dev
#   storage: onedrive
#   drive_type: personal
#   auto_config: yes → browser auth

# Optional fallback (B2 free tier 10GB):
# n) New remote
#   name: b2-recovery
#   storage: b2
#   account: <B2 account ID>
#   key: <B2 app key>
```

### 2. GPG passphrase

```bash
# Generate long random passphrase
openssl rand -base64 32 > ~/.config/recovery/bundle.pass
chmod 600 ~/.config/recovery/bundle.pass

# CRITICAL: copy this passphrase to password manager
# Memorize at least 4-6 chars head + tail
```

### 3. Config bundle daemon

```bash
mkdir -p ~/.config/recovery
cp ~/Projects/workstation-setup/scripts/backup/bundle.conf.example \
   ~/.config/recovery/bundle.conf
# Edit RCLONE_REMOTE_* if names differ from defaults
```

### 4. First backup (test)

```bash
~/Projects/workstation-setup/scripts/backup/daily-bundle.sh --no-push --tier3
# This builds full bundle locally (incl tier3 outputs) to verify
# Encrypted bundle moved to ~/recovery-bundle-YYYY-MM-DD.tar.gz.gpg
# Inspect, decrypt manually: gpg --decrypt ~/recovery-bundle-*.gpg | tar tz
```

### 5. Install cron

```bash
~/Projects/workstation-setup/scripts/backup/install-cron.sh
# Prompts confirm, replaces legacy brain.db.bak cron
```

### 6. Verify cron + first cloud push

```bash
crontab -l | grep daily-bundle
# Wait until 4:30 AM tomorrow OR force run:
~/Projects/workstation-setup/scripts/backup/daily-bundle.sh
# Check cloud:
rclone lsf onedrive-dev:dev/recovery-bundle/daily/
```

## Pre-disaster homework

Critical: complete BEFORE relying on recovery.

- [ ] **bundle.pass in password manager**: write down passphrase, store somewhere accessible (Bitwarden, 1Password, paper safe)
- [ ] **Bootstrap URL**: write down `https://raw.githubusercontent.com/haingt-dev/workstation-setup/master/bootstrap.sh` somewhere offline
- [ ] **rclone config backup**: rclone config ALSO needs to be restorable. Add `~/.config/rclone/rclone.conf` to secrets section of bundle? **Note**: currently not included — would need to be re-OAuth'd. Add to bundle if convenient.
- [ ] **Civitai modelVersionId**: fill in `~/Projects/home-server/forge/models.yml` (search civitai.com for each LoRA filename)
- [ ] **VS Code extensions checked in**: run `~/Projects/workstation-setup/scripts/vscode_sync.sh --commit` to capture current state
- [ ] **Symlinks YAML audit**: run `~/Projects/workstation-setup/scripts/audit_symlinks.sh` to catch any unmanaged links

## Recovery commands cheatsheet

```bash
# Full interactive recovery
./recover.sh

# Resume after failure (e.g., Phase 4 worked, retry from 5)
./recover.sh --from-phase 5

# Skip one phase
./recover.sh --skip-phase 2

# Test without changes
./recover.sh --dry-run

# Just one phase
./recover.sh --only-phase 6

# Autonomous
./recover.sh --non-interactive
```

## Manual steps remaining after recovery

Theo plan, recovery cover almost everything. Còn lại:

1. **Forge models** (~9GB): `cd ~/Projects/home-server && ./scripts/forge-pull-models.sh`
   - Requires `CIVITAI_API_KEY` in `home-server/.env` (auto-restored từ bundle)
   - Requires manifest filled in (homework above)

2. **HuggingFace login** (nếu pull gated models): `huggingface-cli login`

3. **IronCradle assets reimport**: lần đầu open Godot, tự reimport 5-30 phút

4. **home-server up**: `cd ~/Projects/home-server && ./scripts/up.sh all` để verify 4 sections chạy

## Verification (quarterly drill)

Test recovery flow định kỳ:

```bash
# 1. Build a VM (qemu/virt-manager)
# 2. Install Nobara base
# 3. Inside VM:
curl -fsSL https://raw.githubusercontent.com/haingt-dev/workstation-setup/master/bootstrap.sh | bash
# Follow instructions printed
gh auth login --web
gh repo clone haingt-dev/workstation-setup ~/Projects/workstation-setup
cd ~/Projects/workstation-setup && ./recover.sh --dry-run

# 4. If dry-run looks good, real run:
./recover.sh

# 5. Time the full run, compare to baseline. Update plan if regressions.
```

## Trade-offs documented

- **Single bundle (R1)**: 1 file ~300MB/day. Cần passphrase đúng để mở toàn bộ. Acceptable.
- **GPG symmetric over rclone crypt**: portable (any machine với passphrase = decrypt). Lose deduplication.
- **plugins/cache in bundle (R6)**: +74MB nhưng skip plugin reinstall (faster + no internet on restore).
- **Conversation history full backup**: 832MB → ~150MB compressed. Acceptable for daily bandwidth on VN internet.
- **MS 365 single point of failure**: hedge với B2 fallback.

## Related docs

- [ONEDRIVE-BACKUP.md (home-server)](~/Projects/home-server/docs/ONEDRIVE-BACKUP.md) — earlier design doc (now subsumed into daily-bundle)
- [My Setup.md (Idea_Vault)](~/Projects/Idea_Vault/40\ Library/My\ Setup.md) — hardware context + 2026 NAND/RAM market
