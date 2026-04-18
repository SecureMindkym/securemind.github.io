#!/usr/bin/env bash
# ==============================================================================
# security-cleanup.sh — Purge sensitive findings from repo + git history
# ==============================================================================
#
# WARNING: This script REWRITES git history. Coordinate with all collaborators
#          before running. Anyone with a clone will need to reclone or rebase.
#
# Usage:
#   ./scripts/security-cleanup.sh --dry-run     # show what would happen
#   ./scripts/security-cleanup.sh --confirm     # actually do it
#
# Requirements:
#   - git (>= 2.22)
#   - git-filter-repo (https://github.com/newren/git-filter-repo)
#       Install: pip install git-filter-repo
# ==============================================================================

set -euo pipefail

DRY_RUN=true
if [[ "${1:-}" == "--confirm" ]]; then
  DRY_RUN=false
elif [[ "${1:-}" != "--dry-run" ]]; then
  echo "Usage: $0 [--dry-run|--confirm]"
  exit 1
fi

run() {
  if $DRY_RUN; then
    echo "[DRY-RUN] $*"
  else
    echo "[EXEC] $*"
    eval "$@"
  fi
}

echo "=========================================="
echo " Security Cleanup — securemind.github.io"
echo "=========================================="
echo "Mode: $($DRY_RUN && echo 'DRY-RUN' || echo 'EXECUTE')"
echo

# ------------------------------------------------------------------------------
# 1. Verify git-filter-repo is available
# ------------------------------------------------------------------------------
if ! command -v git-filter-repo &>/dev/null; then
  echo "ERROR: git-filter-repo not found. Install with: pip install git-filter-repo"
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Backup current state
# ------------------------------------------------------------------------------
BACKUP_DIR="../securemind-backup-$(date +%Y%m%d-%H%M%S)"
echo "[*] Creating backup at: $BACKUP_DIR"
run "cp -r . '$BACKUP_DIR'"

# ------------------------------------------------------------------------------
# 3. Files to purge from working tree AND history
# ------------------------------------------------------------------------------
PURGE_FILES=(
  "runsc-wiki.md"
  "my-cloud-wiki/tiddlers/\$__StoryList.tid"
  "my-cloud-wiki/tiddlywiki.info"
  "container_info.json"
)

echo
echo "[*] Removing files from working tree:"
for f in "${PURGE_FILES[@]}"; do
  if [[ -e "$f" ]]; then
    run "git rm -rf --ignore-unmatch '$f'"
  fi
done

# Also remove the my-cloud-wiki directory entirely
run "rm -rf my-cloud-wiki/"

# ------------------------------------------------------------------------------
# 4. String replacements to scrub from ALL history
# ------------------------------------------------------------------------------
REPLACE_FILE="$(mktemp)"
cat > "$REPLACE_FILE" <<'EOF'
auditscraper==>[REDACTED-PROJECT]
AuditScraper==>[REDACTED-PROJECT]
Audity==>[REDACTED-PROJECT]
AuditDB==>[REDACTED-DB]
Audity-Engine==>[REDACTED-ENGINE]
21.4.1.50==>[REDACTED-IP]
160.79.104.10==>[REDACTED-IP]
container_01G7nh7tdhdXMMHBrDVz5yKM--claude_code_remote--120d42==>[REDACTED-CONTAINER]
bc85c1230b-v==>[REDACTED-IFACE]
bookstackpass==>[CHANGE-ME]
rootpass==>[CHANGE-ME]
EOF

echo
echo "[*] Will replace strings across ALL git history:"
cat "$REPLACE_FILE"

# ------------------------------------------------------------------------------
# 5. Branch name change (the branch name itself leaks the project codename)
# ------------------------------------------------------------------------------
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
NEW_BRANCH="claude/connect-external-service"

echo
echo "[*] Renaming branch '$CURRENT_BRANCH' -> '$NEW_BRANCH'"
run "git branch -m '$CURRENT_BRANCH' '$NEW_BRANCH'"

# ------------------------------------------------------------------------------
# 6. Commit current cleanup
# ------------------------------------------------------------------------------
run "git add -A"
run "git commit -m 'Security cleanup: remove sensitive transcripts and config' || true"

# ------------------------------------------------------------------------------
# 7. Rewrite history with git-filter-repo
# ------------------------------------------------------------------------------
echo
echo "[*] Rewriting history to scrub strings + purge files"
for f in "${PURGE_FILES[@]}"; do
  run "git filter-repo --path '$f' --invert-paths --force"
done
run "git filter-repo --replace-text '$REPLACE_FILE' --force"

# ------------------------------------------------------------------------------
# 8. Force-push to remote (DANGEROUS)
# ------------------------------------------------------------------------------
echo
echo "[!] About to FORCE PUSH rewritten history to remote."
echo "[!] All collaborators MUST re-clone after this completes."

if $DRY_RUN; then
  echo "[DRY-RUN] git push origin '$NEW_BRANCH' --force-with-lease"
  echo "[DRY-RUN] git push origin --delete '$CURRENT_BRANCH'"
else
  read -p "Type 'PURGE' to confirm force-push: " CONFIRM
  if [[ "$CONFIRM" == "PURGE" ]]; then
    git push origin "$NEW_BRANCH" --force-with-lease
    git push origin --delete "$CURRENT_BRANCH" || echo "Old branch already gone"
  else
    echo "Aborted by user. Local cleanup is done; remote untouched."
  fi
fi

# ------------------------------------------------------------------------------
# 9. Cleanup
# ------------------------------------------------------------------------------
rm -f "$REPLACE_FILE"
run "git reflog expire --expire=now --all"
run "git gc --prune=now --aggressive"

echo
echo "=========================================="
echo " Cleanup complete."
echo " Backup at: $BACKUP_DIR"
echo "=========================================="
echo
echo "Post-cleanup checklist:"
echo "  [ ] Verify branch on GitHub no longer contains sensitive data"
echo "  [ ] Notify collaborators to re-clone"
echo "  [ ] Rotate any credentials that were exposed (defaults, even if test)"
echo "  [ ] Contact GitHub Support to purge cached views if exposure was severe"
echo "  [ ] Review GitHub Pages cache (may serve old content for ~10 minutes)"
