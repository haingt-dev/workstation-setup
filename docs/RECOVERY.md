# Disaster Recovery System

End-to-end pipeline để restore Hải's workstation từ scratch trên máy mới. Tận dụng OneDrive 5TB làm encrypted cold backup. VM-validated 2026-05-25 (Fedora 44 Cloud).

## TL;DR — Disaster Recovery (in 5 commands)

```bash
# 1. Install bootstrap prereqs
sudo dnf install -y git curl gh gnupg2 rclone

# 2. Auth GitHub (browser opens)
gh auth login --web

# 3. Clone workstation-setup
gh repo clone haingt-dev/workstation-setup ~/Projects/workstation-setup

# 4. Run recovery (interactive, ~60-90 min)
cd ~/Projects/workstation-setup && ./recover.sh

# 5. (Optional, after recovery) pull Forge models
cd ~/Projects/home-server && ./scripts/forge-pull-models.sh
```

Recovery cần **bundle passphrase** (lưu password manager). Bộ recover.sh hỏi tự động ở Phase 2.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ DAILY BACKUP (cron 23:00)                                    │
│                                                              │
│   daily-bundle.sh → tar + GPG AES256 + rclone push          │
│     ↓                                                        │
│   onedrive-dev:dev/recovery-bundle/daily/  (~750MB)         │
│   Retention: 7d + 4w + 12m (server-side)                    │
│   23:00 aligns with bandwidth flip to unlimited.            │
└─────────────────────────────────────────────────────────────┘
                          ↓ (disaster)
┌─────────────────────────────────────────────────────────────┐
│ RECOVERY (interactive, 7 phases)                            │
│                                                              │
│ 0. Detect prereqs   3. Secrets (SSH/GPG/gh/rclone)          │
│ 1. System base       4. Claude state (~/.claude/+.json)     │
│ 2. Cloud bundle      5. Agent + Brain (uv + venv + DB)      │
│                      6. 6 repos + .env + post-hooks         │
│                      7. Verify                              │
└─────────────────────────────────────────────────────────────┘
```

## Bundle composition (~688MB encrypted daily)

| Section | Contents |
|---|---|
| `secrets/` | ~/.ssh, ~/.gnupg, gh oauth token, **rclone.conf + bundle.pass + bundle.conf** (self-files), **onedriver auth_tokens.json** (per-mount, skip re-OAuth on restore) |
| `claude/` | CLAUDE.md, core-memory, brains, settings.json, hooks (Claude Code lifecycle hooks), **dot-claude.json (global MCP)**, plans, projects.tar.gz (conv history), plugins.tar.gz (cache + marketplaces) |
| `envs/` | All .env files via **manifest.txt** (sequential `env-N.bin` + path mapping — handles dashes in dirnames correctly) |
| `brain/` | brain.db (sqlite `.backup` WAL-safe snapshot) |
| `home-server/` | tier1 (.env × 4 incl. ebooks), tier2 (configs+DBs + ebooks/data/config). **tier3 (Forge outputs) is NOT here** — separate primary-only artifact, see §3.2 |
| `chimera/` | Godot version pin (if present), ~/.config/godot, VS Code User, extensions list |
| `crontabs/` | Snapshot user crontab |
| `manifest.txt + repos.txt` | Bundle metadata + auto-generated repo list with remotes |

## Setup (one-time, đã hoàn thành 2026-05-25)

### 1. rclone OAuth (Microsoft 365 Business tenant)

```bash
# Pre-config: tenant + drive_type
rclone config create onedrive-dev onedrive \
    drive_type business \
    tenant bluesea98.onmicrosoft.com \
    --non-interactive

# Generate token via OAuth (browser opens)
rclone authorize "onedrive"
# Login với haint@bluesea98.onmicrosoft.com → grant consent
# Returns token JSON — saved to ~/.config/rclone/rclone.conf

# Get drive_id via Graph API
curl -H "Authorization: Bearer $(rclone config show onedrive-dev | grep access_token | head -1 | cut -d'"' -f4)" \
    https://graph.microsoft.com/v1.0/me/drive | python3 -m json.tool | grep '"id"'
# Add drive_id to config
rclone config update onedrive-dev drive_id "b!..." --non-interactive
```

**M365 Business gotcha**: rclone OAuth fails với "AADSTS650051 service principal already present" nếu tenant chưa consent rclone app. Fix: Azure Portal → Microsoft Entra ID → Enterprise applications → search App ID `b15665d9-eda6-4092-8539-0eec376afd59` → Permissions → "Grant admin consent for bluesea98". Rồi retry OAuth.

### 2. Bundle passphrase

```bash
mkdir -p ~/.config/recovery
openssl rand -base64 32 > ~/.config/recovery/bundle.pass
chmod 600 ~/.config/recovery/bundle.pass

# CRITICAL: copy passphrase to password manager (Bitwarden/1Password)
# + memorize 4-6 chars head — proof of life if password manager also lost
cat ~/.config/recovery/bundle.pass
```

### 3. Bundle config

```bash
cp ~/Projects/workstation-setup/scripts/backup/bundle.conf.example \
   ~/.config/recovery/bundle.conf
chmod 600 ~/.config/recovery/bundle.conf
# Edit: set RCLONE_REMOTE_FALLBACK="" if no B2 backup
```

#### 3.1. B2 fallback hardening (REQUIRED if using B2 — one-time per bucket)

B2 keeps all file versions. rclone's retention `delete` only **hides** files (a
hide-marker) unless `hard_delete=true`, and hidden versions **still count toward
the 10GB free cap**. Without this step, real storage only grows — `rclone size`
looks fine (~6GB) while Backblaze emails "Daily Storage Cap reached 75/100%"
(measure truth with `rclone size <remote> --b2-versions`). Hit 2026-06-05.

```bash
# 1. Retention hard-deletes instead of hiding (applies going forward)
rclone config update b2-recovery hard_delete true

# 2. Server-side safety net: purge any hidden version after 1 day (survives DR,
#    independent of rclone config — bucket-side, persists on a new machine)
rclone backend lifecycle b2-recovery:hai-recovery-bundle -o daysFromHidingToDeleting=1

# 3. One-shot: purge the existing backlog of hidden versions
rclone cleanup b2-recovery:hai-recovery-bundle

# Verify visible == all-versions (no dead weight left):
rclone size b2-recovery:hai-recovery-bundle
rclone size b2-recovery:hai-recovery-bundle --b2-versions
```

#### 3.2. Tier3 (Forge outputs) is primary-only (since 2026-06-17)

The main bundle mirrors to **both** remotes. Tier3 Forge outputs (Stable
Diffusion gallery, 850MB+ and growing) used to ride *inside* that bundle, so
every weekly snapshot ballooned to ~1.5GB and — once kept ×4 as weekly — blew
the B2 free cap (75% alert 2026-06-17, real cause, **not** hidden versions this
time). Tier3 is now built as a **separate** `recovery-tier3-<date>.tar.gz.gpg`
artifact pushed to the **PRIMARY remote only**, under `<primary>/tier3/`.
Retention: `RETAIN_TIER3_WEEKS` (default 8) on primary. The B2 main bundle stays
uniform (~600MB) regardless of how large Forge outputs grow.

DR does **not** auto-restore tier3 (it's regenerable — keeps recovery lean). To
restore the Forge gallery manually after recovery:

```bash
src="$RCLONE_REMOTE_PRIMARY/tier3"   # e.g. onedrive-dev:dev/recovery-bundle/tier3
latest=$(rclone lsf "$src/" --include "recovery-tier3-*.tar.gz.gpg" | sort -r | head -1)
rclone copy "$src/$latest" /tmp/
gpg --decrypt --passphrase-file ~/.config/recovery/bundle.pass \
    --output /tmp/tier3.tar.gz "/tmp/$latest"
tar xzf /tmp/tier3.tar.gz -C ~/Projects/home-server   # restores forge/data/forge/outputs
```

### 4. First push + install cron

```bash
# Test (no push)
~/Projects/workstation-setup/scripts/backup/daily-bundle.sh --no-push

# Real push
~/Projects/workstation-setup/scripts/backup/daily-bundle.sh

# Install daily 4:30 AM cron (also removes legacy brain.db.bak cron)
~/Projects/workstation-setup/scripts/backup/install-cron.sh
```

## Recovery commands cheatsheet

```bash
# Full interactive
./recover.sh

# Resume after failure
./recover.sh --from-phase 5

# Skip phase (vd: bundle pre-staged manually)
./recover.sh --skip-phase 2

# Dry-run preview
./recover.sh --dry-run

# Single phase
./recover.sh --only-phase 6

# Autonomous (no confirms)
./recover.sh --non-interactive
```

## Pre-disaster homework (verify periodically)

- [x] Bundle passphrase saved in password manager ✓
- [x] rclone.conf in bundle (self-files commit `540cab8`) ✓
- [x] daily-bundle cron installed ✓
- [ ] **Fill Civitai modelVersionId** trong `~/Projects/home-server/forge/models.yml` (9 LoRAs)
- [ ] Run `~/Projects/workstation-setup/scripts/vscode_sync.sh --commit` weekly để keep extensions list fresh
- [ ] Save disaster card to Google Keep (xem `DISASTER-CARD.txt` in repo root)
- [ ] **Push commits regularly** — recovery clones from GitHub origin. Unpushed commits = lost if disaster strikes
- [ ] Optional: setup B2 fallback remote cho dual-cloud redundancy

## After recovery — what's auto-restored vs manual

**Auto-restored (bundle covers)**:
- ✓ SSH/GPG/gh tokens, all .env files (incl AirVPN, Civitai, Anthropic, OPENAI keys)
- ✓ Conversation history + plans + memories + brains
- ✓ Global MCP config (haingt-brain, todoist)
- ✓ Plugin marketplaces + cache (engram excluded — reinstall manually)
- ✓ Cross-project symlinks (declarative — see `assets/symlinks.yml`; none active currently)
- ✓ Crontab (incl daily-bundle re-install)
- ✓ rclone.conf + bundle.conf + bundle.pass (self-files restored Phase 3)
- ✓ brain.db (sqlite WAL-safe snapshot)
- ✓ Godot binary auto-installed từ pin file
- ✓ VS Code User settings + extensions list
- ✓ **onedriver auth tokens** (Dev + Personal) → systemd units enabled in Phase 3 → mounts auto-start on next login
- ✓ **calibre-sync.timer** installed in Phase 6 (daily 22:30 backup local → cloud)
- ✓ **Calibre Library content** auto-fetched từ cloud nếu local empty (Phase 6 post-hook, prompt-or-auto tuỳ INTERACTIVE flag)

**Manual after recovery (cannot auto)**:
1. **Forge models** (~9GB): `cd ~/Projects/home-server && ./scripts/forge-pull-models.sh` (URLs trong forge/models.yml)
2. **HuggingFace login** (nếu gated models): `huggingface-cli login`
3. **chimera assets reimport**: open Godot lần đầu → tự reimport (5-30 min)
4. **home-server stack up**: `cd ~/Projects/home-server && ./scripts/up.sh all`
5. **engram plugin reinstall** (excluded từ bundle vì recursive dirs): qua marketplace
6. **Calibre Library content** (~26GB, NOT in bundle — too large): **auto-fetched** trong Phase 6 post-hook nếu local empty + cloud có data. Interactive mode prompt `[Y/n]`, non-interactive auto-fetch. Manual fallback: `rclone copy "onedrive-dev:Calibre Library/" "/home/haint/Data/Calibre Library/" --progress`. Daily backup local→cloud by `calibre-sync.timer` (22:30).
7. **OneDrive content** sống dưới `~/Data/OneDrive/{Dev,Personal}` qua onedriver. On-demand placeholders → file chỉ download khi mở. Không có manual restore step — onedriver pulls metadata lazily.

## Verification (quarterly drill)

Sử dụng VM Fedora Cloud test:

```bash
# 1. Create VM (qemu/virt-manager hoặc Vagrant)
# 2. Inside VM: chạy 5 commands ở TL;DR
# 3. Bundle pull happens via Phase 2 từ cloud
# 4. State fingerprint compare:
~/Projects/workstation-setup/scripts/state-fingerprint.sh > vm-state.json
# Run on host:
~/Projects/workstation-setup/scripts/state-fingerprint.sh > host-state.json
# Diff (expected: brain count differs by N memories saved since bundle; binary versions newer in VM)
```

## Trade-offs documented

- **Single bundle (R1)**: 1 file ~688MB/day. Cần passphrase đúng để mở toàn bộ.
- **GPG symmetric over rclone crypt**: portable — decrypt anywhere với passphrase. Mất deduplication.
- **plugins/cache in bundle (R6, exclude engram)**: ~60MB nhưng skip plugin reinstall. Engram excluded do recursive nested dir bug — reinstall manual.
- **Conversation history full backup**: 832MB → ~150MB compressed. Acceptable bandwidth VN.
- **MS 365 single point of failure**: hedge với B2 fallback (optional, currently disabled).
- **rclone OAuth in M365 Business**: yêu cầu tenant admin grant consent on rclone app. Recovery preserves token via bundle, no re-OAuth needed.
- **OneDrive client = onedriver (jstaf) not abraunegg/onedrive**: chuyển 2026-05-25 để có Files-On-Demand (Windows-equivalent placeholder semantics). Trade-off: onedriver KHÔNG hỗ trợ pinning folder "always local" → Calibre Library tách ra `~/Data/Calibre Library/` (real local btrfs), backup riêng qua `calibre-sync.timer`. Fresh-setup OAuth cần workaround `WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11 onedriver --auth-only <mount>` trên KDE Plasma Wayland (Gdk Error 71 native).

## Related docs

- `DISASTER-CARD.txt` (workstation-setup root) — siêu ngắn 5-command cheatsheet cho Google Keep
- `~/Projects/Idea_Vault/40 Library/My Setup.md` — hardware context + 2026 NAND/RAM market
- `~/.claude/plans/agent-v-brain-system-swirling-simon.md` — original design plan
