#!/usr/bin/env bash
# Moves the wrapper to other native SallaPush versions, or checks that every pin of them agrees.
#
#   scripts/bump-native.sh <version>                             SallaPush iOS and Android to <version>
#   scripts/bump-native.sh --ios <version> [--android <version>]
#   scripts/bump-native.sh --android <version>
#   scripts/bump-native.sh --check                               every pin agrees (scripts/verify.sh pins)
#
# A bump needs gh, logged in (gh auth login), and python3. It
#   1. validates each version: X.Y.Z or X.Y.Z-<pre-release>;
#   2. fetches the native API files at the new tags into tool/api-parity/, and stops, saying which, when gh can't
#      read a repository or a tag doesn't exist (nothing is changed then);
#   3. rewrites every pin of NATIVE_PINS (scripts/common.sh): the podspec, Package.swift, docs/snippets/Podfile, the
#      example's Swift package reference, the Gradle dependency, mapping.json's nativeVersions, and the versions and
#      the links to the native docs in README.md, docs/ and RELEASING.md;
#   4. adds "- SallaPush iOS <v> and SallaPush Android <v>." under "## [Unreleased]", "### Changed" in CHANGELOG.md;
#      a platform already at its version is left out of every step, and a bump that moves neither changes nothing;
#   5. runs --check and the API parity check (with Flutter: FLUTTER, else flutter on PATH), and shows how the native
#      API files changed. The parity check names every native symbol that needs a decision in mapping.json.
# It never commits, pushes or prints a credential. Review the change, map the new symbols, wrap the new API, update the
# docs, and open the pull request.
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$scripts/.." && pwd -P)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
. "$scripts/common.sh"

fail() {
  printf 'bump-native.sh: %s\n' "$*" >&2
  exit 1
}

usage() {
  echo "usage: scripts/bump-native.sh <version> | --ios <version> [--android <version>] | --android <version> | --check" >&2
  exit 2
}

command -v python3 >/dev/null 2>&1 || fail "python3 not found"

# pins check | pins current <platform> | pins set <platform> <version>: checks that every pin of each platform names
# one version, prints the version every pin of <platform> names, or rewrites every pin of <platform> to <version>. The
# pins come from NATIVE_PINS; a file with another number of matches than its count fails all three, before anything is
# written.
pins() {
  python3 - "$root" "$@" -- "${NATIVE_PINS[@]}" <<'PY'
import os, re, sys

arguments = sys.argv[1:]
root, mode = arguments[0], arguments[1]
separator = arguments.index("--")
options, entries = arguments[2:separator], arguments[separator + 1:]
problems, found = [], {}
texts, plans = {}, []
for entry in entries:
    path, rest = entry.split("|", 1)
    rest, count = rest.rsplit("|", 1)
    pattern, platform = rest.rsplit("|", 1)
    if mode == "set" and platform != options[0]:
        continue
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        problems.append(f"{path} is missing; it pins SallaPush {platform}")
        continue
    if path not in texts:
        with open(full, encoding="utf-8") as handle:
            texts[path] = handle.read()
    regex = re.compile(pattern, re.MULTILINE)
    matches = list(regex.finditer(texts[path]))
    if (count == "+" and not matches) or (count != "+" and len(matches) != int(count)):
        problems.append(f"{path} names SallaPush {platform} {len(matches)} time(s), not {count}: {pattern}")
        continue
    for match in matches:
        found.setdefault(platform, []).append((match.group(1), path))
    plans.append((path, regex))
if problems:
    sys.exit("\n".join(problems))
if mode == "check":
    failed = False
    for platform in ("ios", "android"):
        pins = found.get(platform, [])
        versions = sorted({version for version, _ in pins})
        name = "SallaPush iOS" if platform == "ios" else "SallaPush Android"
        if len(versions) == 1:
            files = sorted({path for _, path in pins})
            print(f"{name} {versions[0]}: {len(pins)} pins in {', '.join(files)}")
        else:
            failed = True
            print(f"{name} is pinned at {len(versions)} versions:")
            for version, path in pins:
                print(f"  {path}: {version}")
    sys.exit(1 if failed else 0)
if mode == "current":
    versions = sorted({version for version, _ in found.get(options[0], [])})
    if len(versions) != 1:
        sys.exit(f"SallaPush {options[0]} is pinned at {len(versions)} versions")
    print(versions[0])
    sys.exit(0)
version = options[1]
for path, regex in plans:
    texts[path] = regex.sub(lambda m: m.group(0)[:m.start(1) - m.start(0)] + version + m.group(0)[m.end(1) - m.start(0):],
                            texts[path])
for path in {path for path, _ in plans}:
    with open(os.path.join(root, path), "w", encoding="utf-8") as handle:
        handle.write(texts[path])
print(f"pinned SallaPush {options[0]} {version} in {len({path for path, _ in plans})} files")
PY
}

# changelog <line>: adds "- <line>" under ## [Unreleased], ### Changed, once.
changelog() {
  python3 - "$root/CHANGELOG.md" "$1" <<'PY'
import re, sys

path, line = sys.argv[1], f"- {sys.argv[2]}"
with open(path, encoding="utf-8") as handle:
    lines = handle.read().split("\n")
try:
    start = lines.index("## [Unreleased]")
except ValueError:
    sys.exit("CHANGELOG.md has no '## [Unreleased]' section")
end = next((index for index in range(start + 1, len(lines)) if lines[index].startswith("## [")), len(lines))
section = lines[start:end]
if line in section:
    sys.exit(0)
if "### Changed" in section:
    position = start + section.index("### Changed") + 1
    while position < end and not lines[position].startswith("### "):
        position += 1
    while lines[position - 1] == "":
        position -= 1
    lines.insert(position, line)
else:
    insert = end
    while insert > start + 1 and lines[insert - 1] == "":
        insert -= 1
    lines[insert:insert] = ["", "### Changed", "", line]
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))
PY
}

# fetch <repository> <tag> <path in the repository> <destination>: the file at the tag, through gh.
fetch() {
  local repository="$1" tag="$2" path="$3" destination="$4"
  gh api "repos/$repository" --jq .full_name >/dev/null 2>&1 ||
    fail "gh cannot read $repository: check that gh is logged in (gh auth status, gh auth login)"
  gh api "repos/$repository/git/ref/tags/$tag" >/dev/null 2>&1 || fail "$repository has no tag $tag"
  gh api -H 'Accept: application/vnd.github.raw' "repos/$repository/contents/$path?ref=$tag" >"$destination" ||
    fail "cannot fetch $path of $repository at $tag"
}

ios=""
android=""
case "${1:-}" in
  --check)
    [ "$#" -eq 1 ] || usage
    pins check || fail "the native SallaPush pins disagree; scripts/bump-native.sh <version> rewrites them all"
    exit 0
    ;;
  '' | -h | --help) usage ;;
  --ios | --android)
    while [ "$#" -gt 0 ]; do
      [ "$#" -ge 2 ] || usage
      case "$1" in
        --ios) ios="$2" ;;
        --android) android="$2" ;;
        *) usage ;;
      esac
      shift 2
    done
    ;;
  *)
    [ "$#" -eq 1 ] || usage
    ios="$1"
    android="$1"
    ;;
esac

for version in $ios $android; do
  [[ "$version" =~ $NATIVE_VERSION_RE ]] || fail "$version is not a native release version: X.Y.Z or X.Y.Z-<pre-release>"
done
# Every pin is checked before anything is written. A platform already at its version is left as it is.
pins check >/dev/null || fail "the pins disagree already; fix them first (scripts/bump-native.sh --check)"
if [ -n "$ios" ] && [ "$ios" = "$(pins current ios)" ]; then
  echo "SallaPush iOS already at $ios"
  ios=""
fi
if [ -n "$android" ] && [ "$android" = "$(pins current android)" ]; then
  echo "SallaPush Android already at $android"
  android=""
fi
[ -n "$ios$android" ] || exit 0
command -v gh >/dev/null 2>&1 || fail "gh not found: install the GitHub CLI and log in (gh auth login)"

work="$(mktemp -d "${TMPDIR:-/tmp}/sallapush-bump.XXXXXX")"
trap 'rm -rf "$work"' EXIT
[ -z "$ios" ] || fetch "$NATIVE_IOS_REPOSITORY" "$ios" API.txt "$work/native-ios-API.txt"
[ -z "$android" ] || fetch "$NATIVE_ANDROID_REPOSITORY" "$android" sallapush/api/sallapush.api \
  "$work/native-android-sallapush.api"

if [ -n "$ios" ]; then
  cp "$work/native-ios-API.txt" "$root/tool/api-parity/native-ios-API.txt"
  pins set ios "$ios"
fi
if [ -n "$android" ]; then
  cp "$work/native-android-sallapush.api" "$root/tool/api-parity/native-android-sallapush.api"
  pins set android "$android"
fi
if [ -n "$ios" ] && [ -n "$android" ]; then
  changelog "SallaPush iOS $ios and SallaPush Android $android."
elif [ -n "$ios" ]; then
  changelog "SallaPush iOS $ios."
else
  changelog "SallaPush Android $android."
fi

pins check
echo
git -C "$root" --no-pager diff --stat -- tool/api-parity || true
git -C "$root" --no-pager diff -- tool/api-parity/native-ios-API.txt tool/api-parity/native-android-sallapush.api || true
echo
if resolve_flutter 2>/dev/null; then
  (cd "$root" && "$DART" run tool/check_api_parity.dart) ||
    echo "Map every native symbol named above in tool/api-parity/mapping.json, wrap the new API, then update the docs."
else
  echo "Flutter not found: run scripts/verify.sh parity to list the native symbols that need a decision."
fi
