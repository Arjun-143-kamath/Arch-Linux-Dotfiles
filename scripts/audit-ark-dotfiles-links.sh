#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only audit of files that scripts/install.sh intends to deploy.
# Usage: ./scripts/audit-ark-dotfiles-links.sh [repo-path]

REPO_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_DIR="$(cd -- "$REPO_DIR" && pwd)"
HOME_DIR="${HOME:?HOME is not set}"
HOSTNAME_VALUE="$(cat /etc/hostname 2>/dev/null | tr -d '\n' || hostname)"

if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: $REPO_DIR is not a Git working tree." >&2
  exit 1
fi

printf 'Repository: %s\n' "$REPO_DIR"
printf 'Home:       %s\n' "$HOME_DIR"
printf 'Hostname:   %s\n' "$HOSTNAME_VALUE"
printf '\n'
printf '%s\n' '=== ALL REPOSITORY SYMLINKS (source-side) ==='
find "$REPO_DIR" \
  \( \
    -path "$REPO_DIR/.git" -o \
    -path "$REPO_DIR/home/.config/quickshell/k4" -o \
    -path "$REPO_DIR/home/.config/kew" \
  \) -prune \
  -o -type l -printf '[REPO-SYMLINK] %P -> %l\n' 2>/dev/null || true
printf '\n'

checked=0
ok=0
not_linked=0
wrong_link=0
missing=0
repo_symlink=0
untracked=0

tracking_label() {
  local repo_rel="$1"
  if git -C "$REPO_DIR" ls-files --error-unmatch -- "$repo_rel" >/dev/null 2>&1; then
    TRACKING_LABEL='tracked'
  else
    untracked=$((untracked + 1))
    TRACKING_LABEL='UNTRACKED'
  fi
}

check_home_entry() {
  local repo_rel="$1"
  local source="$REPO_DIR/$repo_rel"
  local rel="${repo_rel#home/}"
  local target="$HOME_DIR/$rel"
  local source_real target_real label
  checked=$((checked + 1))
  tracking_label "$repo_rel"
  label="$TRACKING_LABEL"

  # The installer currently uses find -type f, so a symlink inside home/
  # is silently skipped. Report it explicitly rather than following it.
  if [[ -L "$source" ]]; then
    repo_symlink=$((repo_symlink + 1))
    printf '[REPO-SYMLINK-SKIPPED] [%s] %s -> %s\n' "$label" "$repo_rel" "$(readlink -- "$source")"
    return
  fi

  if [[ ! -f "$source" ]]; then
    missing=$((missing + 1))
    printf '[SOURCE-MISSING]       [%s] %s\n' "$label" "$repo_rel"
    return
  fi

  source_real="$(realpath -e -- "$source")"

  if [[ -L "$target" ]]; then
    target_real="$(realpath -e -- "$target" 2>/dev/null || true)"
    if [[ -n "$target_real" && "$target_real" == "$source_real" ]]; then
      ok=$((ok + 1))
      printf '[LINK-OK]              [%s] %s -> %s\n' "$label" "$rel" "$target_real"
    elif [[ -z "$target_real" ]]; then
      missing=$((missing + 1))
      printf '[BROKEN-LINK]          [%s] %s -> %s\n' "$label" "$rel" "$(readlink -- "$target")"
    else
      wrong_link=$((wrong_link + 1))
      printf '[WRONG-LINK]           [%s] %s -> %s (expected %s)\n' "$label" "$rel" "$target_real" "$source_real"
    fi
  elif [[ -e "$target" ]]; then
    not_linked=$((not_linked + 1))
    printf '[NOT-A-SYMLINK]        [%s] %s exists as a regular file/directory\n' "$label" "$rel"
  else
    missing=$((missing + 1))
    printf '[MISSING-TARGET]       [%s] %s\n' "$label" "$rel"
  fi
}

check_machine_entry() {
  local repo_rel="$1"
  local source="$REPO_DIR/$repo_rel"
  local prefix="machines/$HOSTNAME_VALUE/"
  local rel="${repo_rel#"$prefix"}"
  local target="$HOME_DIR/.config/hypr/machines/$HOSTNAME_VALUE/$rel"
  local source_real target_real label
  checked=$((checked + 1))
  tracking_label "$repo_rel"
  label="$TRACKING_LABEL"

  if [[ -L "$source" ]]; then
    repo_symlink=$((repo_symlink + 1))
    printf '[REPO-SYMLINK-SKIPPED] [%s] %s -> %s\n' "$label" "$repo_rel" "$(readlink -- "$source")"
    return
  fi

  if [[ ! -f "$source" ]]; then
    missing=$((missing + 1))
    printf '[SOURCE-MISSING]       [%s] %s\n' "$label" "$repo_rel"
    return
  fi

  source_real="$(realpath -e -- "$source")"
  if [[ -L "$target" ]]; then
    target_real="$(realpath -e -- "$target" 2>/dev/null || true)"
    if [[ -n "$target_real" && "$target_real" == "$source_real" ]]; then
      ok=$((ok + 1))
      printf '[LINK-OK]              [%s] %s -> %s\n' "$label" "$target" "$target_real"
    elif [[ -z "$target_real" ]]; then
      missing=$((missing + 1))
      printf '[BROKEN-LINK]          [%s] %s -> %s\n' "$label" "$target" "$(readlink -- "$target")"
    else
      wrong_link=$((wrong_link + 1))
      printf '[WRONG-LINK]           [%s] %s -> %s (expected %s)\n' "$label" "$target" "$target_real" "$source_real"
    fi
  elif [[ -e "$target" ]]; then
    not_linked=$((not_linked + 1))
    printf '[NOT-A-SYMLINK]        [%s] %s exists as a regular file/directory\n' "$label" "$target"
  else
    missing=$((missing + 1))
    printf '[MISSING-TARGET]       [%s] %s\n' "$label" "$target"
  fi
}

printf '%s\n' '=== HOME FILES (expected symlinks) ==='
while IFS= read -r -d '' source; do
  check_home_entry "${source#"$REPO_DIR"/}"
done < <(
  find "$REPO_DIR/home" \
    \( \
      -path "$REPO_DIR/home/.config/quickshell/k4" -o \
      -path "$REPO_DIR/home/.config/kew" \
    \) -prune \
    -o \( -type f -o -type l \) -print0 2>/dev/null | sort -z
)

# K4 is a Git submodule, deployed as one directory symlink.
printf '\n%s\n' '=== K4 SUBMODULE (expected directory symlink) ==='
K4_SOURCE="$REPO_DIR/home/.config/quickshell/k4"
K4_TARGET="$HOME_DIR/.config/quickshell/k4"

if [[ -d "$K4_SOURCE" ]] && \
   git -C "$K4_SOURCE" rev-parse --show-toplevel >/dev/null 2>&1; then
  K4_SOURCE_REAL="$(realpath -e -- "$K4_SOURCE")"
  K4_TARGET_REAL="$(realpath -e -- "$K4_TARGET" 2>/dev/null || true)"

  if [[ -L "$K4_TARGET" && "$K4_TARGET_REAL" == "$K4_SOURCE_REAL" ]]; then
    echo "[SUBMODULE-LINK-OK] $K4_TARGET -> $K4_SOURCE_REAL"
  elif [[ -L "$K4_TARGET" ]]; then
    echo "[SUBMODULE-WRONG-LINK] $K4_TARGET -> $(readlink -- "$K4_TARGET")"
  elif [[ -e "$K4_TARGET" ]]; then
    echo "[SUBMODULE-NOT-LINKED] $K4_TARGET exists but is not a symlink"
  else
    echo "[SUBMODULE-MISSING] $K4_TARGET"
  fi
else
  echo "[SUBMODULE-UNINITIALIZED] $K4_SOURCE"
fi

printf '\n%s\n' "=== MACHINE FILES for $HOSTNAME_VALUE (expected symlinks) ==="
if [[ -d "$REPO_DIR/machines/$HOSTNAME_VALUE" ]]; then
  while IFS= read -r -d '' source; do
    check_machine_entry "${source#"$REPO_DIR"/}"
  done < <(find "$REPO_DIR/machines/$HOSTNAME_VALUE" \( -type f -o -type l \) -print0 2>/dev/null | sort -z)
else
  echo "No machine-specific configuration for hostname '$HOSTNAME_VALUE'."
fi

printf '\n%s\n' '=== OTHER MACHINE CONFIGS (not expected on this host) ==='
while IFS= read -r repo_rel; do
  [[ "$repo_rel" == machines/* ]] || continue
  machine_name="${repo_rel#machines/}"
  machine_name="${machine_name%%/*}"
  [[ "$machine_name" == "$HOSTNAME_VALUE" ]] && continue
  printf '[OTHER-MACHINE]       %s\n' "$repo_rel"
done < <(git -C "$REPO_DIR" ls-files -- machines | sort -u)

printf '\n%s\n' '=== SYSTEM FILES (installer copies these; symlinks are NOT expected) ==='
check_system_copy() {
  local repo_rel="$1" target="$2"
  local source="$REPO_DIR/$repo_rel"
  if [[ ! -e "$source" ]]; then
    printf '[SOURCE-MISSING]       %s\n' "$repo_rel"
  elif [[ ! -e "$target" ]]; then
    printf '[COPY-MISSING]         %s (expected copy at %s)\n' "$repo_rel" "$target"
  elif cmp -s -- "$source" "$target" 2>/dev/null; then
    printf '[COPY-OK]              %s -> %s\n' "$repo_rel" "$target"
  else
    printf '[COPY-DRIFT]           %s differs from %s\n' "$repo_rel" "$target"
  fi
}

for mapping in \
  "system/greetd/config.toml|/etc/greetd/config.toml" \
  "system/greetd/regreet.toml|/etc/greetd/regreet.toml" \
  "system/sddm/theme.conf|/etc/sddm.conf.d/theme.conf" \
  "system/sddm/wallpaper.conf|/etc/sddm.conf.d/wallpaper.conf" \
  "system/usr/local/bin/sddm-wallpaper|/usr/local/bin/sddm-wallpaper"; do
  IFS='|' read -r source_rel target <<< "$mapping"
  if [[ -e "$REPO_DIR/$source_rel" || -L "$REPO_DIR/$source_rel" ]]; then
    check_system_copy "$source_rel" "$target"
  fi
done

printf '\n%s\n' '=== SUMMARY (home + active machine entries) ==='
printf 'Checked entries:       %d\n' "$checked"
printf 'Correct symlinks:      %d\n' "$ok"
printf 'Not symlinked:         %d\n' "$not_linked"
printf 'Wrong symlinks:        %d\n' "$wrong_link"
printf 'Missing/broken:        %d\n' "$missing"
printf 'Repo symlinks skipped: %d\n' "$repo_symlink"
printf 'Untracked source files:  %d\n' "$untracked"
printf '\nRead-only audit complete; no files were changed.\n'
