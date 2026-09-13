#!/bin/bash
# Verifies that the repository identity lives in exactly one place.
#
#   * data/repo.conf is the only config every script reads
#   * katsu-update follows it (including a fork), and migrates old installs
#     that still carry REPO=/BRANCH= in update.conf
#   * no script outside the two bootstrap files hardcodes the repo slug
#
# Runs entirely offline: GitHub is replaced by a local directory served over
# file:// through the KATSU_GH_RAW / KATSU_GH_API hooks.

set -u
cd "$(dirname "$0")/.."
ROOT_REPO=$PWD
fails=0
ok()   { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; fails=$((fails + 1)); }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --------------------------------------------------------------- static check
echo "== no hardcoded repo slug outside the bootstrap files"
# setup.sh and katsu-update.sh must hardcode a default: they run before
# repo.conf exists on the VPS. README.md documents the installer URL.
allowed="setup.sh|data/katsu-update.sh|data/repo.conf|data/RepoLocal.sh|README.md|tests/.*"
hits=$(git ls-files | grep -vE "^($allowed)$" |
        xargs grep -n "Recva-by-katsu\|raw\.githubusercontent\.com/[A-Za-z0-9_-]*/autosc" 2>/dev/null)
if [ -z "$hits" ]; then ok "only bootstrap files carry the slug"; else
    fail "hardcoded slug found:"; echo "$hits" | sed 's/^/       /'
fi

echo "== every script that uses \$RAW sources repo.conf"
for f in $(grep -rl '\$RAW\|\$REPO_URL\|\$ISSUES_URL\|\$BRAND' --include='*.sh' \
            --exclude-dir=.git --exclude-dir=tests data setup.sh); do
    case "$f" in setup.sh|data/katsu-update.sh|data/repo.conf) continue ;; esac
    grep -q 'repo\.conf' "$f" || fail "$f uses \$RAW without sourcing repo.conf"
done
ok "all consumers source repo.conf"

echo "== repo.conf derives its URLs from GH_USER/GH_REPO/GH_BRANCH"
(
    GH_USER=someone GH_REPO=myfork GH_BRANCH=dev
    . ./data/repo.conf
    [ "$REPO_SLUG" = "someone/myfork" ] || exit 1
    [ "$RAW" = "https://raw.githubusercontent.com/someone/myfork/dev" ] || exit 1
    [ "$ISSUES_URL" = "https://github.com/someone/myfork/issues" ] || exit 1
) && ok "environment override flows into RAW/REPO_URL/ISSUES_URL" \
  || fail "repo.conf did not honour the environment override"

# ------------------------------------------------------- fake GitHub + updater
# A tiny two-file "repository" plus an api/ tree the updater can curl over
# file://, so apply() can be exercised without network access.
make_fake_repo() {
    local root=$1 slug=$2 sha=$3 payload=$4
    mkdir -p "$root/$slug/$sha/data" "$root/api/repos/$slug/commits"
    printf '%s' "$sha" > "$root/api/repos/$slug/commits/main"
    cat > "$root/$slug/$sha/data/manifest.txt" <<END
data/version    /opt/.ver   644
END
    printf '%s\n' "$payload" > "$root/$slug/$sha/data/version"
}

run_update() {
    env KATSU_CONF_DIR="$conf" KATSU_ROOT="$fakeroot" \
        KATSU_LOCK="$tmp/lock" KATSU_CRON_FILE="$tmp/cron" \
        KATSU_GH_RAW="file://$gh" KATSU_GH_API="file://$gh/api" \
        bash "$ROOT_REPO/data/katsu-update.sh" "$@"
}

gh=$tmp/gh
conf=$tmp/etc
fakeroot=$tmp/root
mkdir -p "$conf" "$fakeroot/opt"
make_fake_repo "$gh" "upstream/autosc" "$(printf '%040d' 1)" "9.9.9-upstream"
make_fake_repo "$gh" "someone/myfork"  "$(printf '%040d' 2)" "9.9.9-fork"

echo "== katsu-update follows repo.conf"
cat > "$conf/repo.conf" <<'END'
GH_USER="${GH_USER:-upstream}"
GH_REPO="${GH_REPO:-autosc}"
GH_BRANCH="${GH_BRANCH:-main}"
REPO_SLUG="$GH_USER/$GH_REPO"
REPO_URL="https://github.com/$REPO_SLUG"
RAW="https://raw.githubusercontent.com/$REPO_SLUG/$GH_BRANCH"
END
run_update apply --force >/dev/null 2>&1
if [ "$(cat "$fakeroot/opt/.ver")" = "9.9.9-upstream" ]; then
    ok "installed from the repo named in repo.conf"
else
    fail "expected upstream payload, got $(cat "$fakeroot/opt/.ver" 2>/dev/null)"
fi

echo "== katsu-update repo <user/repo> repoints the VPS to a fork"
run_update repo someone/myfork >/dev/null 2>&1
run_update apply --force >/dev/null 2>&1
if [ "$(cat "$fakeroot/opt/.ver")" = "9.9.9-fork" ]; then
    ok "fork payload installed after switching repo"
else
    fail "expected fork payload, got $(cat "$fakeroot/opt/.ver" 2>/dev/null)"
fi
grep -q 'GH_USER="${GH_USER:-someone}"' "$conf/repo.conf" \
    && ok "repo.conf rewritten, override form kept" \
    || fail "repo.conf not rewritten correctly"

echo "== legacy install (REPO=/BRANCH= in update.conf) is migrated"
rm -rf "$conf"; mkdir -p "$conf"
cat > "$conf/update.conf" <<'END'
REPO=someone/myfork
BRANCH=main
AUTO_UPDATE=on
INTERVAL=5
RESTART_SERVICES=on
GITHUB_TOKEN=
END
rm -f "$fakeroot/opt/.ver"
run_update apply --force >/dev/null 2>&1
if [ "$(cat "$fakeroot/opt/.ver")" = "9.9.9-fork" ]; then
    ok "kept following the legacy repo after migration"
else
    fail "migration lost the configured repo"
fi
grep -q '^REPO=' "$conf/update.conf" && fail "REPO= still duplicated in update.conf" \
    || ok "duplicate keys removed from update.conf"
grep -q 'someone' "$conf/repo.conf" && ok "legacy value moved into repo.conf" \
    || fail "repo.conf does not carry the legacy repo"

echo "== status reports the repo from repo.conf"
run_update status | grep -q "^REPO=someone/myfork$" \
    && ok "status exposes the configured slug" \
    || fail "status did not report the configured slug"

echo "== missing repo.conf is regenerated from the legacy/default values"
rm -f "$conf/repo.conf"
run_update status >/dev/null 2>&1
[ -s "$conf/repo.conf" ] && ok "katsu-update recreated repo.conf" \
    || fail "repo.conf was not recreated"

echo "== setup.sh bootstrap writes repo.conf from the chosen repo"
# Run only the bootstrap block of setup.sh (between the two markers) against the
# fake GitHub tree, so the installer's very first step is covered offline.
sed -n '/^############# Sumber script #############$/,/^############# \/Sumber script #############$/p' \
    setup.sh > "$tmp/bootstrap.sh"
mkdir -p "$gh/someone/myfork/$(printf '%040d' 2)/data"
cp data/repo.conf "$gh/someone/myfork/$(printf '%040d' 2)/data/repo.conf"
setupconf=$tmp/setupconf
( cd "$tmp" && env GH_USER=someone GH_REPO=myfork GH_BRANCH="$(printf '%040d' 2)" \
    KATSU_CONF_DIR="$setupconf" KATSU_GH_RAW="file://$gh" \
    bash "$tmp/bootstrap.sh" >/dev/null 2>&1 )
if [ -s "$setupconf/repo.conf" ] &&
   grep -q 'GH_USER="${GH_USER:-someone}"' "$setupconf/repo.conf" &&
   grep -q 'GH_REPO="${GH_REPO:-myfork}"' "$setupconf/repo.conf"; then
    ok "installer persisted the fork identity"
else
    fail "setup.sh bootstrap did not write the fork identity"
fi
# The written file must still evaluate to that fork with no environment set.
( env -i bash -c ". '$setupconf/repo.conf'; [ \"\$REPO_SLUG\" = someone/myfork ]" ) \
    && ok "repo.conf resolves to the fork on a clean shell" \
    || fail "repo.conf does not resolve to the fork without the environment"

echo ""
if [ $fails -eq 0 ]; then echo "all checks passed"; else echo "$fails check(s) failed"; fi
exit $fails
