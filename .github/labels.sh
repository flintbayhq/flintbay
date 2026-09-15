#!/usr/bin/env bash
#
# Create or update the issue labels for flintbayhq/flintbay.
#
# Maintainer utility, not something a contributor needs to run. It is idempotent:
# `gh label create --force` updates a label that already exists, so re-running after
# editing this file reconciles the repository with it.
#
# Requires the GitHub CLI, authenticated with push access to the repository:
#   https://cli.github.com/
#   gh auth login
#
# Usage:
#   ./.github/labels.sh                      # apply to flintbayhq/flintbay
#   REPO=owner/other ./.github/labels.sh     # apply somewhere else
#   DRY_RUN=1 ./.github/labels.sh            # print what would run, change nothing
#
# Note: this only adds and updates. Labels that exist in the repository but are absent
# here are left alone — delete those by hand if you want them gone.

set -euo pipefail

REPO="${REPO:-flintbayhq/flintbay}"
DRY_RUN="${DRY_RUN:-}"

# A dry run only prints, so it needs neither the CLI nor a login.
if [[ -z "$DRY_RUN" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI not found. Install it from https://cli.github.com/" >&2
    echo "       (DRY_RUN=1 works without it.)" >&2
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "error: gh is not authenticated. Run: gh auth login" >&2
    exit 1
  fi
fi

label() {
  local name="$1" color="$2" description="$3"
  if [[ -n "$DRY_RUN" ]]; then
    printf 'would set  %-28s #%s  %s\n' "$name" "$color" "$description"
    return 0
  fi
  if gh label create "$name" \
      --repo "$REPO" \
      --color "$color" \
      --description "$description" \
      --force >/dev/null; then
    printf 'ok         %s\n' "$name"
  else
    printf 'FAILED     %s\n' "$name" >&2
    return 1
  fi
}

echo "Applying labels to ${REPO}${DRY_RUN:+ (dry run)}"
echo

# --- Type: what kind of report this is -------------------------------------------
label "bug"                 "d73a4a" "Behaves differently than documented"
label "enhancement"         "a2eeef" "New capability or improvement to an existing one"
label "docs"                "0075ca" "Documentation error, gap, or clarification"
label "regression"          "b60205" "Worked in an earlier version, broken in a later one"

# --- Status: where the issue stands ----------------------------------------------
label "needs-triage"        "fbca04" "Not yet looked at"
label "needs-info"          "d876e3" "Waiting on the reporter; closed if it goes quiet"
label "confirmed"           "0e8a16" "Reproduced — the problem is real and understood"
label "in-progress"         "1d76db" "Being worked on now"
label "fixed-pending-release" "5319e7" "Fixed in the build; ships in the next published version"
label "wontfix"             "ffffff" "Deliberately not being changed"
label "duplicate"           "cfd3d7" "Already tracked in another issue"
label "upstream"            "ededed" "Cause lies in a dependency, not in Flintbay"

# --- Area: which part of the product ---------------------------------------------
label "area:widgets"        "c5def5" "Widgets, ports, sizing, rendering"
label "area:bindings"       "c5def5" "Connection Studio, transforms, triggers, ACK, policies"
label "area:video"          "c5def5" "Live video — WebRTC, LL-HLS, RTSP, media gateway"
label "area:dashboard"      "c5def5" "Screens, pages, layout, editing"
label "area:auth"           "c5def5" "Authentication, sessions, workspace RBAC, API keys"
label "area:mcp"            "c5def5" "MCP server and AI-assisted configuration"
label "area:deployment"     "c5def5" "Image, startup, environment contract, reverse proxy"
label "area:data"           "c5def5" "PostgreSQL, Redis, backup, restore, upgrade"
label "area:observability"  "c5def5" "Metrics, logs, audit trail, memory profiler"
label "area:i18n"           "c5def5" "Translation and localization"

# --- Connector: which transport --------------------------------------------------
label "connector:mqtt"      "1d76db" "MQTT source or endpoint"
label "connector:ros2"      "1d76db" "ROS 2 source or endpoint"
label "connector:rest"      "1d76db" "REST source or endpoint"
label "connector:websocket" "1d76db" "WebSocket source or endpoint"

# --- Platform: where it reproduces -----------------------------------------------
label "platform:amd64"      "bfd4f2" "Specific to x86_64 hosts"
label "platform:arm64"      "bfd4f2" "Specific to aarch64 hosts"
label "platform:jetson"     "bfd4f2" "Specific to NVIDIA Jetson"
label "platform:rpi"        "bfd4f2" "Specific to Raspberry Pi"

# --- Invitations -----------------------------------------------------------------
label "good first issue"    "7057ff" "Small and well-scoped — a good place to start"
label "help wanted"         "008672" "Input, testing, or hardware access would help"

echo
echo "Done."
