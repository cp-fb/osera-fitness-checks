# osera-fitness-checks

[![license](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![lint](https://github.com/d1gital-f/osera-fitness-checks/actions/workflows/lint.yaml/badge.svg)](https://github.com/d1gital-f/osera-fitness-checks/actions/workflows/lint.yaml)
[![e2e](https://github.com/d1gital-f/osera-fitness-checks/actions/workflows/e2e.yaml/badge.svg)](https://github.com/d1gital-f/osera-fitness-checks/actions/workflows/e2e.yaml)

This repository contains the reusable GitHub Workflow and the Composite Actions that run the source side
fitness checks of the [OSERA Remediation Standards](https://standards.osera.finos.org/) on a patch repository
at a release tag. One action per requirement of the standards pack, plain bash with git, jq and yq, one signed result.

Playground of 8 Sept 2026 in a personal space, not the finos-osera library yet: the organisation and the `uses:` owner are parameters.

## Workflows

### Fitness checks on a release tag

The [fitness](.github/workflows/fitness.yaml) workflow checks a patch repository at a release tag by performing the following steps:

- Checks out the patch repository at the tag, with every branch and tag, and this library next to it.
- Runs one action per requirement of OSERA-SP-0.1.0 that can be checked on the source (table below). Each writes one record.
- Runs the ControlPlane proposals (REL-004 early warnings), which warn and never fail the run.
- Writes `result.json` in the shape of the [fitness page](https://standards.osera.finos.org/fitness/), one status per standard, with the per requirement records and the proposals underneath.
- Attests `result.json` with GitHub Attestations: an in-toto statement, predicate type `https://osera.finos.org/fitness-result/v1`, signed with the workflow's OIDC identity through Sigstore, stored by GitHub with the repository.
- Uploads `result.json` and the Sigstore bundle as a workflow artifact.
- Fails the run when any blocking check failed.

Example usage, the file a patch repository carries on its patch branch ([template](templates/osera-fitness.yaml)):

```yaml
name: OSERA fitness checks
run-name: OSERA fitness checks on ${{ github.ref_name }}
on:
  push:
    tags: ['v*\+osera-patch.*']
permissions:
  contents: read # for checking out the repository.
  id-token: write # for creating OIDC tokens for signing.
  attestations: write # for GitHub Attestations.
jobs:
  fitness:
    uses: finos-osera/osera-fitness-checks/.github/workflows/fitness.yaml@v1
    with:
      tag: ${{ github.ref_name }}
```

Inputs:

- `tag` (string, required): the release tag under test, for example `v2.14.2+osera-patch.001`. Nothing else: the organisation FORK-001 expects, the library version the actions run from and the repository under test are fixed in the workflow file or derived from the run itself, never taken from the caller.

Outputs:

- `result`: `pass`, `warn` or `fail`.

3rd-party actions used:

- [actions/checkout](https://github.com/actions/checkout)
- [actions/attest](https://github.com/actions/attest)
- [actions/upload-artifact](https://github.com/actions/upload-artifact)

Verify a result: `gh attestation verify result.json --repo <patch repo> --signer-repo <this repo> --predicate-type https://osera.finos.org/fitness-result/v1`.

## Versioning

Callers pin the moving major tag, `@v1`. Releases are exact tags (`v1.0.0`, `v1.0.1`, `v1.1.0`) and `v1` is moved to the latest of them only after the e2e workflow is green, so a producer's repository never changes and still receives fixes. A breaking change becomes `v2` and a pull request on every caller. Every result records the exact library commit that produced it, which is what the gate checks.

## Actions

One composite action per requirement, under [`.github/actions`](.github/actions). Bash only: git for the repository, yq for the evidence file and the approved producers file, jq for the record.

| Action | Requirement | What it checks |
|---|---|---|
| `fork-001-req-001` | FORK-001.REQ-001 | repository in the expected organisation |
| `fork-001-req-002` | FORK-001.REQ-002 | repository name `patch-<project>` |
| `fork-002-req-001` | FORK-002.REQ-001 | `patch/<version>` branch exists and contains the release tag |
| `fork-003-req-001` | FORK-003.REQ-001 | `v<VERSION>+patch.baseline` exists, resolves, is an ancestor of the release tag |
| `src-002-req-001` | SRC-002.REQ-001 | every fix in `.osera/patch-evidence.yaml` links an upstream commit, pull request, advisory or release note |
| `src-002-req-002` | SRC-002.REQ-002 (SHOULD, advisory) | commits naming an upstream commit carry a `Co-authored-by` trailer, not applicable when none does |
| `src-003-req-001` | SRC-003.REQ-001 | new source or test files since the baseline carry the header of the nearest same type file (years, whitespace and asterisks ignored), not applicable when no convention exists |
| `rel-001-req-001` | REL-001.REQ-001 | test provenance recorded in the evidence file: the tested commit, command, runtime, report name, passing result. The release tag may sit after the tested commit only if the commits in between touch nothing but the evidence file and the caller workflow |
| `write-result` | | `result.json` |

ControlPlane proposals, not requirements on the site, put to the working group on [remediation-standards #52](https://github.com/finos-osera/remediation-standards/issues/52). They warn, they never fail the run:

| Action | Id in the result | What it checks |
|---|---|---|
| `proposal-rel-004-producer-named` | CP-REL-004-01 | the evidence file has a producer line |
| `proposal-rel-004-producer-approved` | CP-REL-004-02 | that producer is in the approved producers file ([`approved-producers/approved_producers.yaml`](approved-producers/approved_producers.yaml), the playground copy of the standards site's approved producer list in the shape proposed on #52; the real file is on the standards repository and is empty) |
| `proposal-rel-004-accounts-in-entry` | CP-REL-004-03 | the account that pushed the tag and the accounts on the commits between the baseline tag and the release tag are all in that entry's `github_users` |

Every action takes the same inputs (`tag`, `repository`, `expected-org`, `approved-producers`, `actor`, `results-dir`), sources [`lib/record.sh`](lib/record.sh) (the version and baseline tag derived from the release tag, and the one `record` function every check calls) and writes one JSON record with the standard, the requirement, the site's check id, the status and the evidence. The artifact side checks (REL-002 bytecode level, REL-003 version pattern, REL-004 at the upload and at publication, REL-005 files and checksums, FEED-001) belong to the gate and are not here.

## The result

`result.json` keeps the fitness page's shape and adds two lists:

```json
{
  "standard_pack": "OSERA-SP-0.1.0", "pack_checksum": null,
  "repository": "finos-osera/patch-jackson-core", "release": "v2.14.2+osera-patch.001", "commit": "21869d05...",
  "artifact_digest": null, "producer": "moderne", "result": "pass",
  "signature": "see the GitHub artifact attestation on this file",
  "checks": [{"standard": "FORK-001", "standard_version": "0.1.0", "status": "pass", "evidence": "FORK-001.REQ-001 pass; FORK-001.REQ-002 pass"}],
  "requirements": [{"standard": "FORK-001", "requirement": "FORK-001.REQ-001", "check": "FORK-001.CHECK-001", "status": "pass", "evidence": "..."}],
  "proposals": [{"standard": "REL-004", "requirement": "CP-REL-004-01", "status": "pass", "evidence": "..."}]
}
```

One status per standard is the worst of its requirements; not applicable never outranks pass. The signed copy lives in GitHub's attestation store for the patch repository (and, for a public repository, in Sigstore's transparency log). The gate fetches and verifies it at upload time and keeps it with the artifact.

## Testing

- [lint](.github/workflows/lint.yaml): actionlint on the workflows, shellcheck on every action's bash.
- [e2e](.github/workflows/e2e.yaml): runs the fitness workflow itself against the reference repository at its release tag (the workflow picks the reference when its caller is the library) and compares every status with [`e2e/expected.txt`](e2e/expected.txt).

## Notes

- In GitHub tag filters `+` is a special character: the pattern must be written `v*\+osera-patch.*`, otherwise the workflow never parses.
- Because the caller file lives on the patch branch and not on the repository's default branch, the Actions tab lists it under its path; `run-name` titles every run by the tag.
