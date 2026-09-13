#!/bin/bash
# KatsuTun updater.
# Installs every file listed in data/manifest.txt from one exact GitHub commit,
# so an install or update is always a consistent snapshot of the repository.
#
#   katsu-update check            compare installed commit with GitHub
#   katsu-update apply [--force]  install the newest commit (only changed files)
#   katsu-update auto             cron entry point, honours AUTO_UPDATE
#   katsu-update enable|disable   toggle auto update
#   katsu-update interval <min>   auto update check interval (1-1440)
#   katsu-update branch <name>    track another branch
#   katsu-update repo <user>/<repo>  track another repository (fork)
#   katsu-update rollback         restore files from the previous update
#   katsu-update status           machine readable state for the menus
#   katsu-update log [n]          show last n log lines

CONF_DIR="${KATSU_CONF_DIR:-/etc/katsutun}"
CONF="$CONF_DIR/update.conf"
REPO_CONF="$CONF_DIR/repo.conf"
STATE_COMMIT="$CONF_DIR/commit"
STATE_LATEST="$CONF_DIR/latest"
STATE_LASTCHECK="$CONF_DIR/lastcheck"
LOG="$CONF_DIR/update.log"
BACKUP_DIR="$CONF_DIR/backup"
LOCK="${KATSU_LOCK:-/run/katsu-update.lock}"
CRON_FILE="${KATSU_CRON_FILE:-/etc/cron.d/katsu-update}"
GH_RAW="${KATSU_GH_RAW:-https://raw.githubusercontent.com}"
GH_API="${KATSU_GH_API:-https://api.github.com}"
# Test hook: prefix every install path (e.g. KATSU_ROOT=/tmp/fake)
ROOT="${KATSU_ROOT:-}"

E_OK=0; E_ERR=1; E_UPDATE_AVAILABLE=10

mkdir -p "$CONF_DIR" "$BACKUP_DIR"

# ------------------------------------------------------------------ config
default_conf() {
cat > "$CONF" <<'END'
# KatsuTun auto update settings. Edit with: menu-update
# Repo yang diikuti diatur di repo.conf, bukan di sini.
AUTO_UPDATE=on
INTERVAL=5
RESTART_SERVICES=on
# Optional GitHub token to raise the API rate limit (60 req/hour without one)
GITHUB_TOKEN=
END
}
[ -s "$CONF" ] || default_conf
# shellcheck disable=SC1090
. "$CONF"
AUTO_UPDATE=${AUTO_UPDATE:-on}
INTERVAL=${INTERVAL:-5}
RESTART_SERVICES=${RESTART_SERVICES:-on}
# Pre-repo.conf installs kept the repository here; keep those values.
LEGACY_REPO=$REPO
LEGACY_BRANCH=$BRANCH

# ------------------------------------------------------------- repo identity
# repo.conf (see data/repo.conf) is the single source of truth for which
# repository this VPS follows. setup.sh writes it and no update overwrites it,
# so a fork keeps pointing at itself.
default_repo_conf() {
cat > "$REPO_CONF" <<END
# KatsuTun — sumber script & branding.
# Ubah lalu jalankan: katsu-update apply --force
GH_USER="\${GH_USER:-${1:-Recva-by-katsu}}"
GH_REPO="\${GH_REPO:-${2:-autosc}}"
GH_BRANCH="\${GH_BRANCH:-${3:-main}}"
BRAND="\${BRAND:-KatsuTun}"
REPO_SLUG="\$GH_USER/\$GH_REPO"
REPO_URL="https://github.com/\$REPO_SLUG"
ISSUES_URL="\$REPO_URL/issues"
RAW="https://raw.githubusercontent.com/\$REPO_SLUG/\$GH_BRANCH"
END
    chmod 644 "$REPO_CONF"
}
if [ ! -s "$REPO_CONF" ]; then
    default_repo_conf "${LEGACY_REPO%%/*}" "${LEGACY_REPO#*/}" "$LEGACY_BRANCH"
fi
# shellcheck disable=SC1090
. "$REPO_CONF"
REPO="$REPO_SLUG"
BRANCH="$GH_BRANCH"
# Drop the duplicated keys left by older installs so only repo.conf decides.
grep -q '^\(REPO\|BRANCH\)=' "$CONF" && sed -i '/^REPO=/d;/^BRANCH=/d' "$CONF"

set_conf() {
    if grep -q "^$1=" "$CONF"; then
        sed -i "s|^$1=.*|$1=$2|" "$CONF"
    else
        echo "$1=$2" >> "$CONF"
    fi
}

set_repo_conf() {
    if grep -q "^$1=" "$REPO_CONF"; then
        sed -i "s|^$1=.*|$1=\"\${$1:-$2}\"|" "$REPO_CONF"
    else
        echo "$1=\"\${$1:-$2}\"" >> "$REPO_CONF"
    fi
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
    [ -z "$QUIET" ] && echo "$*"
    return 0
}

curl_gh() {
    local hdr=()
    [ -n "$GITHUB_TOKEN" ] && hdr=(-H "Authorization: Bearer $GITHUB_TOKEN")
    curl -fsSL --connect-timeout 10 --max-time 60 "${hdr[@]}" "$@"
}

# ------------------------------------------------------------------- cron
write_cron() {
    local iv=$INTERVAL spec
    [[ "$iv" =~ ^[0-9]+$ ]] && [ "$iv" -ge 1 ] && [ "$iv" -le 1440 ] || iv=5
    if [ "$AUTO_UPDATE" = "on" ]; then
        if [ "$iv" -lt 60 ]; then
            spec="*/$iv * * * *"
        else
            spec="0 */$((iv / 60)) * * *"
        fi
        cat > "$CRON_FILE" <<END
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
$spec root /usr/bin/katsu-update auto >/dev/null 2>&1
END
        chmod 644 "$CRON_FILE"
    else
        rm -f "$CRON_FILE"
    fi
}

# ------------------------------------------------------------------ remote
installed_commit() { cat "$STATE_COMMIT" 2>/dev/null; }

latest_commit() {
    # Lightweight API call that returns only the SHA of the branch head.
    local sha
    sha=$(curl_gh -H "Accept: application/vnd.github.sha" \
        "$GH_API/repos/$REPO/commits/$BRANCH" 2>/dev/null | tr -d '[:space:]')
    if [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
        echo "$sha" > "$STATE_LATEST"
        date +%s > "$STATE_LASTCHECK"
        echo "$sha"
        return 0
    fi
    return 1
}

remote_version() { curl_gh "$GH_RAW/$REPO/$1/data/version" 2>/dev/null | tr -d '[:space:]'; }

# ------------------------------------------------------------------- apply
apply() {
    local force=0 sha cur tmp manifest changed=0 failed=0 services=() n=0
    [ "$1" = "--force" ] && force=1

    exec 9>"$LOCK"
    if ! flock -n 9; then
        log "[SKIP] another update is already running"
        return $E_ERR
    fi

    sha=$(latest_commit) || { log "[ERROR] cannot reach GitHub ($REPO@$BRANCH)"; return $E_ERR; }
    cur=$(installed_commit)
    if [ "$sha" = "$cur" ] && [ $force -eq 0 ]; then
        log "[OK] already up to date (${sha:0:7})"
        return $E_OK
    fi

    tmp=$(mktemp -d) || return $E_ERR
    trap 'rm -rf "$tmp"' RETURN
    manifest="$tmp/manifest.txt"
    if ! curl_gh -o "$manifest" "$GH_RAW/$REPO/$sha/data/manifest.txt" || [ ! -s "$manifest" ]; then
        log "[ERROR] manifest not found in commit ${sha:0:7}"
        return $E_ERR
    fi

    log "[INFO] updating ${cur:0:7} -> ${sha:0:7} ($REPO@$BRANCH)"

    # Download everything first; nothing is installed if any file fails.
    while read -r src dst mode svc; do
        [[ -z "$src" || "$src" == \#* ]] && continue
        n=$((n + 1))
        if ! curl_gh -o "$tmp/$n" "$GH_RAW/$REPO/$sha/$src" || [ ! -s "$tmp/$n" ]; then
            log "[ERROR] download failed: $src"
            failed=1
        fi
    done < "$manifest"
    [ $failed -eq 1 ] && { log "[ERROR] update aborted, nothing changed"; return $E_ERR; }

    rm -rf "$BACKUP_DIR"; mkdir -p "$BACKUP_DIR"
    n=0
    while read -r src dst mode svc; do
        [[ -z "$src" || "$src" == \#* ]] && continue
        n=$((n + 1))
        dst="$ROOT$dst"
        if [ -f "$dst" ] && cmp -s "$tmp/$n" "$dst"; then
            continue
        fi
        mkdir -p "$(dirname "$dst")" "$BACKUP_DIR/$(dirname "$dst")"
        [ -f "$dst" ] && cp -p "$dst" "$BACKUP_DIR$dst"
        install -m "${mode:-755}" "$tmp/$n" "$dst"
        changed=$((changed + 1))
        log "  updated $dst"
        [ -n "$svc" ] && services+=("$svc")
    done < "$manifest"

    echo "$sha" > "$STATE_COMMIT"
    echo "$cur" > "$BACKUP_DIR/.commit"

    if [ "$RESTART_SERVICES" = "on" ] && [ ${#services[@]} -gt 0 ]; then
        for s in $(printf '%s\n' "${services[@]}" | sort -u); do
            systemctl is-enabled "$s" >/dev/null 2>&1 || continue
            systemctl restart "$s" 2>/dev/null && log "  restarted $s" || log "  [WARN] restart $s failed"
        done
    fi

    log "[OK] update finished: $changed file(s) changed, now at ${sha:0:7} (v$(cat "$ROOT/opt/.ver" 2>/dev/null))"
    return $E_OK
}

rollback() {
    local prev
    prev=$(cat "$BACKUP_DIR/.commit" 2>/dev/null)
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null | grep -v '^\.commit$')" ]; then
        log "[ERROR] no backup to roll back to"
        return $E_ERR
    fi
    (cd "$BACKUP_DIR" && find . -type f ! -name .commit -print0) | while IFS= read -r -d '' f; do
        cp -p "$BACKUP_DIR/$f" "/${f#./}" && log "  restored /${f#./}"
    done
    [ -n "$prev" ] && echo "$prev" > "$STATE_COMMIT" || rm -f "$STATE_COMMIT"
    log "[OK] rolled back to ${prev:0:7}"
}

check() {
    local sha cur
    sha=$(latest_commit) || { echo "error"; return $E_ERR; }
    cur=$(installed_commit)
    if [ "$sha" = "$cur" ]; then
        echo "uptodate ${sha:0:7}"
        return $E_OK
    fi
    echo "available ${cur:0:7} -> ${sha:0:7} (v$(remote_version "$sha"))"
    return $E_UPDATE_AVAILABLE
}

status() {
    # Output is eval'ed by the menus, so every value is quoted.
    local cur latest last state
    cur=$(installed_commit); latest=$(cat "$STATE_LATEST" 2>/dev/null); last=$(cat "$STATE_LASTCHECK" 2>/dev/null)
    if [ -n "$latest" ] && [ "$latest" != "$cur" ]; then state=available; else state=uptodate; fi
    printf 'REPO=%q\n'             "$REPO"
    printf 'BRANCH=%q\n'           "$BRANCH"
    printf 'AUTO_UPDATE=%q\n'      "$AUTO_UPDATE"
    printf 'INTERVAL=%q\n'         "$INTERVAL"
    printf 'RESTART_SERVICES=%q\n' "$RESTART_SERVICES"
    printf 'VERSION=%q\n'          "$(cat "$ROOT/opt/.ver" 2>/dev/null)"
    printf 'COMMIT=%q\n'           "${cur:0:7}"
    printf 'LATEST=%q\n'           "${latest:0:7}"
    printf 'LASTCHECK=%q\n'        "${last:+$(date -d @"$last" '+%Y-%m-%d %H:%M:%S')}"
    printf 'STATE=%q\n'            "$state"
    printf 'CRON=%q\n'             "$([ -f "$CRON_FILE" ] && echo on || echo off)"
}

case "$1" in
    check)     check ;;
    apply)     apply "$2" ;;
    auto)
        [ "$AUTO_UPDATE" = "on" ] || exit $E_OK
        QUIET=1 apply ;;
    enable)    set_conf AUTO_UPDATE on;  AUTO_UPDATE=on;  write_cron; log "[INFO] auto update enabled (every $INTERVAL min)" ;;
    disable)   set_conf AUTO_UPDATE off; AUTO_UPDATE=off; write_cron; log "[INFO] auto update disabled" ;;
    interval)
        if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] && [ "$2" -le 1440 ]; then
            set_conf INTERVAL "$2"; INTERVAL=$2; write_cron; log "[INFO] interval set to $2 min"
        else
            echo "interval must be 1-1440 minutes"; exit $E_ERR
        fi ;;
    branch)
        if [[ "$2" =~ ^[A-Za-z0-9._/-]+$ ]]; then
            set_repo_conf GH_BRANCH "$2"; BRANCH=$2; rm -f "$STATE_LATEST"; log "[INFO] now tracking branch $2"
        else
            echo "invalid branch name"; exit $E_ERR
        fi ;;
    repo)
        if [[ "$2" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
            set_repo_conf GH_USER "${2%%/*}"; set_repo_conf GH_REPO "${2#*/}"
            REPO=$2; rm -f "$STATE_LATEST"; log "[INFO] now tracking repo $2"
        else
            echo "use: katsu-update repo <user>/<repo>"; exit $E_ERR
        fi ;;
    restart-services)
        case "$2" in on|off) set_conf RESTART_SERVICES "$2"; log "[INFO] restart services: $2" ;; *) echo "use on|off"; exit $E_ERR ;; esac ;;
    token)     set_conf GITHUB_TOKEN "$2"; log "[INFO] github token $([ -n "$2" ] && echo set || echo cleared)" ;;
    cron)      write_cron ;;
    rollback)  rollback ;;
    status)    status ;;
    log)       tail -n "${2:-30}" "$LOG" 2>/dev/null ;;
    *)         sed -n '2,17p' "$0"; exit $E_ERR ;;
esac
