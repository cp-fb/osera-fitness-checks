#!/usr/bin/env bash
# Copyright (c) 2026 Control Plane Limited. All rights reserved.
# Built by ControlPlane for the FINOS OSERA Exchange.
# SPDX-License-Identifier: Apache-2.0
#
# Shared by every check action: the one way a check records its verdict.
#   record <standard> <requirement> <check id or empty> <status> <evidence>
# Writes one JSON record per requirement into $OSERA_RESULTS_DIR, prints one log line,
# and returns failure when the status is fail (which turns the step red).
# Status values are the fitness page's: pass, warn, fail, not-tested, not-applicable, manual-evidence-required.
mkdir -p "${OSERA_RESULTS_DIR:=.osera-results}"
VERSION="${OSERA_TAG#v}"; VERSION="${VERSION%%+*}"   # v2.14.2+osera-patch.001 -> 2.14.2
BASE="v${VERSION}+patch.baseline"                    # the baseline tag FORK-003 requires
export VERSION BASE
record() {
  jq -n --arg standard "$1" --arg requirement "$2" --arg check "$3" --arg status "$4" --arg evidence "$5" \
     '$ARGS.named + {standard_version: "0.1.0"} | .check |= (if . == "" then null else . end)' > "$OSERA_RESULTS_DIR/$2.json"
  echo "$2 $4: $5"
  [ "$4" != "fail" ]
}
