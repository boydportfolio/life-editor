# First public preview

Target: **Sunday, November 1, 2026**, with a candidate ready by Friday,
October 30. The first release will be **0.1.0-alpha.1**, marked as a GitHub
prerelease. This is a usable early preview, not the complete 1.0 product.
The full [requirement register](ROADMAP.md) remains in scope.

November 2 update: development has continued through the
[social framing checkpoint](REFRAMING-CHECKPOINT.md). The original November 1
target has passed; it does not imply that the preview gates below are complete.
No release or tag was created by those development commits.

## Work toward the date

| Date | Deliverable |
|---|---|
| October 27–28 | Requirements/UI audit, crash fixes, remembered workspace controls, reproducible package and checksum. |
| October 29 | Freeze preview scope; complete import/edit/save/reopen/export smoke projects and review failure handling. |
| October 30 | Build the exact tagged candidate, verify archive contents, licenses, checksums and documented format coverage. |
| October 31 | Fresh-user install/source-build checks, keyboard/accessibility smoke pass, final known-issues triage. |
| November 1 | Publish the qualified prerelease and source archive after the checks below; document any blocked gate. |

## Preview gates

- [ ] Exact candidate commit passes source CI and local native/helper tests.
- [x] Development candidate is built, launched and exercised with decoded local media on a supported Mac.
- [x] Import, split, music fade, styled title, save/reopen and export pass together.
- [x] Multicam master audio and switching pass a saved/reopened project smoke check.
- [ ] Keyboard navigation and the 1280 × 800 workspace receive a visible/manual pass.
- [ ] Corrupt import, cancelled export and unwritable destination preserve existing work.
- [ ] Source archive, package contents, dependency notices and checksums are verified.
- [ ] Release notes match actual features, known issues and signing status.

November 4: the [running-app audit](MANUAL-WORKFLOW-AUDIT.md) closes the core
combined edit/delivery and saved/reopened multicam smoke checks in an optimized
development build. Camera fixtures are synthetic local movies, not a concert
usability session. The exact published commit still needs its own CI/package and
installation checks. The historical inspection limits below do not describe the
completed November 4 workflows.

Passing unit/integration fixtures does not automatically close manual gates.
November 1 native inspection now verifies launch, caption editing/navigation and
safe-guide choices. A later file-picker/inspection failure leaves real-media
import and the full manual smoke unverified. Component-view renders and exported
frames do not stand in for those gates. See [social delivery](SOCIAL-DELIVERY.md)
for the current evidence and limits.

## Packaging

```sh
scripts/package-preview.sh 0.1.0-alpha.1
```

The command builds a fresh app, verifies its ad-hoc signature and arm64 executable,
includes license/notices and preview instructions, writes a commit/build manifest,
creates a ZIP, re-extracts it and verifies the signature again, then writes a
SHA-256 checksum. Existing output files are refused. It does not publish or tag.
If pinned helpers are present, the normal build verifies and bundles them with
matching source and notices; otherwise BUILD.json records native-only decoding.

Current development packages are **not notarized** and Gatekeeper rejects the
ad-hoc app as a consumer download. Do not describe them as a signed/notarized
installation. If signing credentials remain unavailable, the first public release
can publish the tagged source preview and clear source-build instructions under
the owner's original exception. An ad-hoc development archive, if offered, must
remain explicitly labeled. No security-bypass helper is supplied.

Developer ID signing/notarization requires actual owner credentials. No credentials
are needed for source builds. Publication will use the exact tested commit;
creating this plan or reviewing it does not create authorization for unrelated
account/security changes.

## What this release does not close

The 1.0 gates still include remaining music/retiming tools, advanced creator tools,
complete document integration, the broad format/failure matrix, complete accessibility,
musician/student usability, M1 performance and all three owner workflows.


November 6: the [candidate validation record](RELEASE-VALIDATION.md) records a
fresh source checkout/build, extracted development-package checks, helper import,
basic keyboard/workspace smoke and failure preservation. The first frozen
candidate failed hosted optimized compilation despite local success; the source
probe actor-isolation correction requires its own final CI/native and packaging
checks before tagging. The public preview will be source-first, with no consumer
app download advertised. The release tag/manifests, rather than the historical
target date above, identify the published candidate.
