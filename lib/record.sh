#!/usr/bin/env bash
# Copyright (c) 2026 Control Plane Limited. All rights reserved.
# Built by ControlPlane for the FINOS OSERA Exchange.
# SPDX-License-Identifier: Apache-2.0
#
# Shared by every check action. The actions take no inputs: they read the job environment the fitness workflow sets
# once in its first step (OSERA_TAG, OSERA_REPOSITORY, OSERA_EXPECTED_ORG, OSERA_APPROVED_PRODUCERS, OSERA_ACTOR,
# OSERA_RESULTS_DIR, OSERA_PACK, OSERA_LIBRARY). Only OSERA_TAG and OSERA_REPOSITORY are required, the rest default here.
# The one way a check records its verdict:
#   record <standard> <requirement> <check id or empty> <status> <evidence>
# Writes one JSON record per requirement into $OSERA_RESULTS_DIR, prints one log line,
# and returns failure when the status is fail (which turns the step red).
# Status values are the fitness page's: pass, warn, fail, not-tested, not-applicable, manual-evidence-required.
: "${OSERA_TAG:?OSERA_TAG is required}"; : "${OSERA_REPOSITORY:?OSERA_REPOSITORY is required}"
: "${OSERA_EXPECTED_ORG:=finos-osera}"; : "${OSERA_APPROVED_PRODUCERS:=.osera-fitness/approved-producers/approved_producers.yaml}"
: "${OSERA_ACTOR:=${GITHUB_ACTOR:-}}"; : "${OSERA_PACK:=OSERA-SP-0.1.0}"; : "${OSERA_LIBRARY:=}"
export OSERA_EXPECTED_ORG OSERA_APPROVED_PRODUCERS OSERA_ACTOR OSERA_PACK OSERA_LIBRARY
mkdir -p "${OSERA_RESULTS_DIR:=.osera-results}"
VERSION="${OSERA_TAG#v}"; VERSION="${VERSION%%+*}"   # v2.14.2+osera-patch.001 -> 2.14.2
BASE="v${VERSION}+patch.baseline"                    # the baseline tag FORK-003 requires
export VERSION BASE
# Every check names itself first: check_is <standard> <requirement> <check id or empty>. If the check then dies on an
# unexpected error (a missing baseline tag, a git failure), the exit trap records not-tested with the failing command,
# so the requirement never silently disappears from the result.
check_is() { CHECK_STD="$1"; CHECK_REQ="$2"; CHECK_ID="$3"; }
on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ -n "${CHECK_REQ:-}" ] && [ ! -f "$OSERA_RESULTS_DIR/$CHECK_REQ.json" ]; then
    record "$CHECK_STD" "$CHECK_REQ" "$CHECK_ID" not-tested "check could not run: '${LAST_COMMAND:-?}' failed" || true
  fi
}
trap 'LAST_COMMAND=$BASH_COMMAND' DEBUG
trap on_exit EXIT
record() {
  jq -n --arg standard "$1" --arg requirement "$2" --arg check "$3" --arg status "$4" --arg evidence "$5" \
     '$ARGS.named + {standard_version: "0.1.0"} | .check |= (if . == "" then null else . end)' > "$OSERA_RESULTS_DIR/$2.json"
  echo "$2 $4: $5"
  [ "$4" != "fail" ]
}
