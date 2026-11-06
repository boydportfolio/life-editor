#!/bin/zsh
# Build a reviewable development preview. Publishing is a separate action.
set -eu
cd "${0:A:h:h}"
preview_tag="${1:-0.1.0-alpha.1}"
if [[ ! "$preview_tag" =~ '^[0-9]+\.[0-9]+\.[0-9]+-alpha\.[0-9]+$' ]]; then
  print -u2 'Use a preview version such as 0.1.0-alpha.1.'
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  print -u2 'Commit or set aside source changes before packaging a preview.'
  exit 1
fi
preview_commit=$(git rev-parse HEAD)
preview_destination="${2:-$PWD/dist/releases}"
mkdir -p "$preview_destination"
preview_destination="${preview_destination:A}"
archive_name="Life-Editor-$preview_tag-macOS-arm64.zip"
if [[ -e "$preview_destination/$archive_name" || -e "$preview_destination/$archive_name.sha256" ]]; then
  print -u2 'Preview destination already exists; use a new version or directory.'
  exit 1
fi
preview_lock="$preview_destination/.$archive_name.lock"
if ! mkdir "$preview_lock" 2>/dev/null; then
  print -u2 'Another package job owns this version destination.'
  exit 1
fi
preview_work=""
trap '[[ -z "$preview_work" ]] || rm -rf "$preview_work"; rmdir "$preview_lock"' EXIT
preview_work=$(mktemp -d "$preview_destination/.life-preview.XXXXXXXX")
preview_root="$preview_work/Life Editor $preview_tag"
mkdir -p "$preview_root"
scripts/build-app.sh "$preview_root/Life Editor.app"
preview_app="$preview_root/Life Editor.app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${preview_tag%%-alpha.*}" "$preview_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${preview_tag##*-alpha.}" "$preview_app/Contents/Info.plist"
codesign --force --sign - "$preview_app"
codesign --verify --strict "$preview_app"
lipo "$preview_app/Contents/MacOS/LifeEditor" -verify_arch arm64
cp LICENSE "$preview_root/LICENSE"
cp docs/DEPENDENCIES.md "$preview_root/DEPENDENCIES.md"
cp docs/PREVIEW.md "$preview_root/READ-ME.md"
python3 - "$preview_root" "$preview_tag" <<'PY'
import hashlib, json, os, pathlib, plistlib, re, stat, subprocess, sys
root=pathlib.Path(sys.argv[1]); app=root/'Life Editor.app'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
helpers=app/'Contents/Resources/Helpers'
helper_pair=all((helpers/name).is_file() and os.access(helpers/name,os.X_OK) for name in ('ffmpeg','ffprobe'))
source=pathlib.Path('Sources/LifeCore/Document.swift').read_text()
schema=re.search(r'public static let currentVersion\s*=\s*(\d+)',source)
if schema is None:
    raise SystemExit('Could not determine the project document schema version.')

def payload_hashes(directory):
    result={}
    for base, dirs, files in os.walk(directory,followlinks=False):
        dirs.sort(); files.sort()
        for name in files:
            path=pathlib.Path(base)/name
            if path.name=='BUILD.json' and path.parent==directory:
                continue
            if stat.S_ISREG(path.lstat().st_mode):
                relative=path.relative_to(directory).as_posix()
                result[relative]=hashlib.sha256(path.read_bytes()).hexdigest()
    return dict(sorted(result.items()))

manifest=dict(manifestVersion=1,version=sys.argv[2],commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
              projectDocumentSchemaVersion=int(schema.group(1)),minimumMacOS=info['LSMinimumSystemVersion'],architecture='arm64',
              signing='ad-hoc',notarized=False,mediaHelpers=helper_pair,files=payload_hashes(root))
(root/'BUILD.json').write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
PY
ditto -c -k --sequesterRsrc --keepParent "$preview_root" "$preview_work/$archive_name"
# Validate the archive and signed app after extraction, not just the build tree.
mkdir "$preview_work/verify"
ditto -x -k "$preview_work/$archive_name" "$preview_work/verify"
python3 - "$preview_work/verify/Life Editor $preview_tag" "$preview_root/BUILD.json" <<'PY'
import hashlib, json, os, pathlib, stat, sys
root=pathlib.Path(sys.argv[1]); expected_manifest=pathlib.Path(sys.argv[2])
manifest_path=root/'BUILD.json'
if manifest_path.read_bytes() != expected_manifest.read_bytes():
    raise SystemExit('Extracted BUILD.json differs from the generated manifest.')
manifest=json.loads(manifest_path.read_text())
actual={}
for base, dirs, files in os.walk(root,followlinks=False):
    dirs.sort(); files.sort()
    for name in files:
        path=pathlib.Path(base)/name
        if path.name=='BUILD.json' and path.parent==root:
            continue
        if stat.S_ISREG(path.lstat().st_mode):
            actual[path.relative_to(root).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
expected=manifest.get('files')
if not isinstance(expected,dict):
    raise SystemExit('BUILD.json has no valid per-file payload manifest.')
if actual != expected:
    missing=sorted(set(expected)-set(actual))
    extra=sorted(set(actual)-set(expected))
    changed=sorted(key for key in set(actual)&set(expected) if actual[key] != expected[key])
    raise SystemExit(f'Extracted payload differs from BUILD.json (missing={missing}, extra={extra}, changed={changed}).')
PY
codesign --verify --strict "$preview_work/verify/Life Editor $preview_tag/Life Editor.app"
(cd "$preview_work" && shasum -a 256 "$archive_name" > "$archive_name.sha256")
(cd "$preview_work" && shasum -a 256 -c "$archive_name.sha256")
if [[ "$preview_commit" != "$(git rev-parse HEAD)" || -n "$(git status --porcelain)" ]]; then
  print -u2 'Source changed during packaging; archive was not published.'
  exit 1
fi
# Hard-link installation is atomic and fails if a destination already exists.
# The staging directory is on the destination volume.
ln "$preview_work/$archive_name" "$preview_destination/$archive_name"
ln "$preview_work/$archive_name.sha256" "$preview_destination/$archive_name.sha256"
print -r -- "$preview_destination/$archive_name"
