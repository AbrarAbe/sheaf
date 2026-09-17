---
name: flutter-linux-github-release
description: Ships the Sheaf Linux desktop build to GitHub Releases via a tag-triggered GitHub Actions workflow. Use when cutting a release, publishing the Linux x64 tarball to GitHub Releases, or setting up and maintaining this project's desktop release pipeline. Primary release workflow for this desktop/Linux-first project.
---

# Flutter Linux Desktop → GitHub Release

## Overview

Tag-driven release pipeline for the Sheaf Linux desktop app. Pushing a `v*` tag
triggers GitHub Actions, which runs quality gates, builds the Linux x64 release
bundle, packages it as a tarball, generates release notes from Conventional
Commits via git-cliff (`cliff.toml`) for the pushed tag, and publishes
everything to a GitHub Release.

- Version source of truth: `version:` in `pubspec.yaml` (format `X.Y.Z+N`);
  version is supplied by the user **or** derived from commit history via
  `git-cliff --bump` / previous tag — `git cliff --tag vX.Y.Z` assigns the
  unreleased commits to that version
- Tag format: `vX.Y.Z` (the build number `+N` never appears in the tag)
- Platforms shipped today: Linux x64 only. Android is covered separately by the
  `flutter-github-release` skill.

## When to Use

- Cutting a new release of the desktop app
- Publishing artifacts to GitHub Releases
- Setting up `.github/workflows/release.yml` for the first time
- Debugging a failed release run

## Process

### Step 0 — Pre-flight (every release)

1. Quality gates green, per project definition of done:
   - `flutter analyze` — clean
   - `flutter test` — green
2. Bump `version:` in `pubspec.yaml` (e.g. `0.2.0+1` → `0.3.0+1`: increment
   semver, always set build suffix to `+1` — do not increment it). The version for the next tag comes
   from the user (explicit `vX.Y.Z`) **or** from commit history via
   `git-cliff --bump` (see step 3).
3. Regenerate the changelog from Conventional Commits **with the tag** so
   `CHANGELOG.md` gets a versioned header instead of `[Unreleased]`:
    - **Version supplied by user:** `git cliff --tag vX.Y.Z -o CHANGELOG.md`
      (e.g. `git cliff --tag v0.1.1 -o CHANGELOG.md`) — assigns all unreleased
      commits to that tag.
    - **Version from commit history:** `git cliff --bump -o CHANGELOG.md` — bumps
      per `cliff.toml` + Conventional Commits; preview the bump first with
      `git cliff --bumped-version` or `git cliff --bump --dry-run`.
    Do not use bare `git cliff -o CHANGELOG.md` here — it leaves the new section
    under `[Unreleased]`.
4. Sync docs: triangulate user-visible changes since the last tag from three
   sources, then update `README.md` (Features, Keyboard shortcuts, Install,
   Build from source, Project docs) to match — do not ship a release whose
   README still describes the previous milestone or contradicts commit history:
    - `docs/spec.md` + `docs/plan_v*.md` — intended scope
    - `git log <last-tag>..HEAD --oneline` + `git diff <last-tag>..HEAD --stat`
      — what actually shipped (features, shortcuts, flags, install paths, deps)
    - Current `README.md` — what users will read on the release page
5. Commit the version bump + changelog + README/docs with a semantic message
   (`chore(release): v0.1.1`) and push to the default branch.

### Step 1 — One-time pipeline setup (skip once `.github/workflows/release.yml` exists)

1. Copy `templates/linux-release-workflow.yml` (relative to this skill) to
   `.github/workflows/release.yml`.
2. Review the pinned `channel:` — `pubspec.yaml` currently constrains the Dart
   SDK to a beta build (`^3.14.0-95.2.beta`), so the workflow pins the beta
   channel. Switch it to stable when the constraint allows.
3. Commit and push the workflow to the default branch before tagging.

### Step 2 — Tag and ship

```
git tag v0.1.1        # use the version from step 0 (user-supplied or the bump from commit history)
git push origin v0.1.1
```

CI checks out the tag ref — never tag a commit that is not merged to the
default branch. The tag `vX.Y.Z` is the version git-cliff uses in CI
(`--current`); it must match the `X.Y.Z` in `pubspec.yaml`.

### Step 3 — Verify the run

1. GitHub → Actions: the "Release (Linux)" run on the tag is green — both jobs
   (`build-linux`, then `publish-release`) succeed; workflow generated notes
   with `git-cliff --current --strip header` for that tag.
2. GitHub → Releases: the new release lists `sheaf-vX.Y.Z-linux-x64.tar.gz`
   (plus the AppImage) and its body matches the `CHANGELOG.md` section for
   that version (the section created locally with `git cliff --tag vX.Y.Z` /
   `--bump`).
3. Download the tarball, extract it, launch the binary once as a smoke test.

### Step 4 — Recover a failed publish (no rebuild)

Build and publish are separate jobs: `build-linux` uploads the tarball +
AppImage as the `sheaf-linux-x64` artifact, and `publish-release`
(`needs: build-linux`) downloads it and publishes. If `publish-release`
fails (e.g. transient asset-upload timeout — not a quota issue):

1. GitHub → Actions → the failed run → "Re-run failed jobs" — only the
   lightweight publish job reruns, no rebuild.
2. If the run's artifacts are still retained, recover locally without CI:
   `gh run download <run-id> -n sheaf-linux-x64`, verify with
   `tar tzf`, then `gh release upload <tag> <files> --clobber` and
   `gh release edit <tag> --draft=false`.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "Just a tag; tests already passed on main" | Tags can point anywhere. CI gates are cheap insurance against shipping an unmerged or broken ref. |
| "Skip regenerating the changelog" | Release notes are rendered from git-cliff output; a stale `CHANGELOG.md` publishes wrong notes verbatim. |
| "Bare `git cliff -o CHANGELOG.md` is fine" | Without `--tag vX.Y.Z` or `--bump`, the new commits stay under `[Unreleased]` — CI publishes notes for `--current` that don't match the changelog you committed. |
| "The build number doesn't matter" | Build is fixed at `+1` for all releases — do not increment it. |
| "Fix the red run later" | A failed tag run leaves a broken or empty public release page. Fix and re-tag promptly. |

## Red Flags

- Tag pushed while `pubspec.yaml` version does not match the tag (tag `v0.2.0`
  but pubspec still `0.1.0+1`)
- Workflow `channel:`/SDK constraint mismatch causing instant pub failure
- Release drafted manually on GitHub instead of letting CI publish it
- Hand-editing generated `CHANGELOG.md` right before a release or committing a
  `CHANGELOG.md` that still shows `[Unreleased]` (forgot `--tag`/`--bump`)
- Tagging from a feature branch
- Checkout without `fetch-depth: 0` — git-cliff cannot see previous tags and
  generates empty `--current` notes

## Verification

Before tagging:

- [ ] `flutter analyze` clean, `flutter test` green
- [ ] `pubspec.yaml` version equals the intended tag minus the `v` prefix
  (version from user or from `git cliff --bumped-version`)
 - [ ] `CHANGELOG.md` regenerated via `git cliff --tag vX.Y.Z -o CHANGELOG.md`
   or `git cliff --bump -o CHANGELOG.md`, committed — header is `## [X.Y.Z]`,
   not `[Unreleased]`
  - [ ] `README.md` reviewed against `docs/spec.md` / `docs/plan_v*.md` **and**
    `git log`/`git diff` since last tag; new or changed features, shortcuts,
    install steps, and doc links updated (no stale version strings)
- [ ] `.github/workflows/release.yml` present on the default branch with two
  jobs: `build-linux` (builds + uploads `sheaf-linux-x64` artifact) and
  `publish-release` (`needs: build-linux`, checkout `fetch-depth: 0`, notes
  step `args: --current --strip header`)

After the run:

- [ ] Actions run green on the tag ref (`--current` notes for that tag)
- [ ] Release assets contain exactly one tarball named with the correct version
- [ ] Tarball extracts and the app launches
- [ ] Release notes match the `CHANGELOG.md` section for that tag
