#!/usr/bin/env bash
# Functions use BASE_DIR, WORKSPACE_ROOT, TARGETS and selection options from sync.sh.
wants_target() {
  local t
  for t in "${TARGETS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

select_destinations() {
  # Discover once, then apply the same selection to generation, excludes, cleanup.
  DESTINATIONS=("$WORKSPACE_ROOT")
  for candidate in "$WORKSPACE_ROOT"/*/; do
    candidate="${candidate%/}"
    [ "$candidate" != "$BASE_DIR" ] || continue
    if [ -d "$candidate/.git" ] || [ -f "$candidate/.git" ]; then
      DESTINATIONS+=("$candidate")
    elif wants_target codex && [ -d "$candidate/.codex" ]; then
      DESTINATIONS+=("$candidate")
    fi
  done
  SELECTED=()
  if $ALL && [ ${#REQUESTED[@]} -gt 0 ]; then
    echo '--all and --target cannot be combined' >&2; exit 1
  fi
  if [ ${#REQUESTED[@]} -gt 0 ]; then
    for requested in "${REQUESTED[@]}"; do
      matched=false
      for destination in "${DESTINATIONS[@]}"; do
        label="$(basename "$destination")"
        [ "$destination" != "$WORKSPACE_ROOT" ] || label=.
        if [ "$requested" = "$label" ] || [ "$requested" = "$destination" ]; then
          SELECTED+=("$destination"); matched=true; break
        fi
      done
      if ! $matched; then echo "Unknown or ineligible target: $requested" >&2; exit 1; fi
    done
  elif $ALL || $DRY_RUN; then
    SELECTED=("${DESTINATIONS[@]}")
  else
    if [ ! -t 0 ] && ! $INTERACTIVE; then
      echo 'Noninteractive sync requires --all or --target NAME (or --dry-run).' >&2
      exit 1
    fi
    echo "Available destinations for ${TARGETS[*]}:"
    echo '  0. All'
    for ((i=0; i<${#DESTINATIONS[@]}; i++)); do
      destination="${DESTINATIONS[$i]}"
      label="$(basename "$destination")"
      [ "$destination" != "$WORKSPACE_ROOT" ] || label='workspace root (.)'
      creates=''
      sets=''
      if wants_target codex; then
        [ -d "$destination/.codex" ] || creates="$creates .codex"
        [ -d "$destination/.agents" ] || creates="$creates .agents"
      fi
      if wants_target claude && { [ "$destination" = "$WORKSPACE_ROOT" ] || [ -e "$destination/.git" ]; }; then
        [ -d "$destination/.claude" ] || creates="$creates .claude"
        # Mirrors the plansDirectory step in sync-claude.sh: child repos only, needs jq.
        settings="$destination/.claude/settings.local.json"
        if [ "$destination" != "$WORKSPACE_ROOT" ] && command -v jq >/dev/null 2>&1 &&
          ! { [ -f "$settings" ] && jq -e 'has("plansDirectory")' "$settings" >/dev/null 2>&1; }; then
          sets=' plansDirectory'
        fi
      fi
      notes=''
      [ -z "$creates" ] || notes="creates:$creates"
      [ -z "$sets" ] || notes="${notes:+$notes; }sets:$sets"
      [ -z "$notes" ] || notes=" ($notes)"
      printf '  %d. %s%s\n' "$((i+1))" "$label" "$notes"
    done
    while :; do
      printf 'Choose 0 for all, numbers separated by commas/spaces, or cancel: '
      if ! IFS= read -r choice; then echo 'Cancelled.'; exit 0; fi
      case "$choice" in
        all|a) SELECTED=("${DESTINATIONS[@]}"); break ;;
        cancel|c|q|'') echo 'Cancelled.'; exit 0 ;;
      esac
      SELECTED=()
      valid=true
      all=false
      IFS=' ' read -r -a choice_tokens <<< "${choice//,/ }"
      for token in "${choice_tokens[@]}"; do
        case "$token" in *[!0-9]*|'') valid=false; break ;; esac
        # Bound length before arithmetic and treat leading zeroes as decimal.
        if [ ${#token} -gt 6 ]; then valid=false; break; fi
        number=$((10#$token))
        if [ "$number" -eq 0 ]; then all=true; continue; fi
        if [ "$number" -gt ${#DESTINATIONS[@]} ]; then valid=false; break; fi
        SELECTED+=("${DESTINATIONS[$((number-1))]}")
      done
      if $valid && $all; then SELECTED=("${DESTINATIONS[@]}"); break; fi
      if $valid && [ ${#SELECTED[@]} -gt 0 ]; then break; fi
      echo 'Invalid selection; use numbers from the list.'
    done
  fi
}
