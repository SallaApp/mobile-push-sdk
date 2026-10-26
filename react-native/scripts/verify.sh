#!/usr/bin/env bash
# The full verification of the SallaPush React Native SDK.
#
#   scripts/verify.sh [step...]    run from anywhere; without steps, every step in order, stopping at the first failure
#
# CI runs the portable steps (PORTABLE_STEPS) on Linux, android on Linux and ios on macOS. The native steps need JDK 17
# and the Android SDK, and all but android need macOS with Xcode 26:
#   swiftlint   SwiftLint 0.63.2, strict
#   android     the library's unit tests and lint, a release build of the example, and its merged manifest
#   ios         the example in three linkages (static libraries, static and dynamic frameworks), then its XCTest suite
#   smoke       the example's self-test on a booted iOS simulator and a running Android emulator, with a notification
#               in the foreground
#   consumer    fresh Expo apps (SDK 57, SDK 54, React Native Firebase, Yarn) that install the release as the publish
#               workflow packs it, from the file and from its URL, as npm and the GitHub Release serve it
#
# Environment: VERIFY_LOG_DIR (a <step>.log per step and summary.tsv, whose first line and rows name the commit, +dirty
# for a tree with changes; a folder for each commit, as runs of another commit are refused), VERIFY_SIMULATOR_UDID,
# VERIFY_EMULATOR_SERIAL, YARN, SHELLCHECK, SWIFTLINT, ANDROID_HOME, JAVA_HOME.
set -euo pipefail

readonly STEPS="lint typecheck test build pack api parity snippets pins tree shell swiftlint android ios smoke consumer"
readonly PORTABLE_STEPS="lint typecheck test build pack api parity snippets pins tree shell"

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$scripts/.." && pwd -P)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
. "$scripts/common.sh"

work="$(mktemp -d "${TMPDIR:-/tmp}/sallapush-verify.XXXXXX")"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

fail() {
  printf 'verify.sh: %s\n' "$*" >&2
  exit 1
}

usage() {
  echo "usage: scripts/verify.sh [step...]   steps: $STEPS (CI runs $PORTABLE_STEPS, android and ios)" >&2
  exit 2
}

require_macos() {
  [ "$(uname -s)" = Darwin ] || fail "this step needs macOS with Xcode"
}

# ---------------------------------------------------------------------------------------------------------------------
# Portable steps

step_lint() { (cd "$root" && sp_yarn lint); }

step_typecheck() { (cd "$root" && sp_yarn typecheck); }

step_test() {
  local tests
  (cd "$root" && sp_yarn test --coverage)
  (cd "$root" && sp_yarn test:scripts) | tee "$work/scripts.tap"
  tests="$(sed -nE 's/^# tests ([0-9]+)$/\1/p' "$work/scripts.tap" | tail -n 1)"
  [ "${tests:-0}" -gt 0 ] || fail "yarn test:scripts ran no tests"
  echo "yarn test:scripts: $tests tests"
}

step_build() {
  (cd "$root" && sp_yarn build)
  (cd "$root" && node -e "require('./app.plugin.js')")
  echo "app.plugin.js loads"
}

# What npm publishes from this tree: the prepack build, then the list of npm pack's dry run (without scripts, whose output
# would mix with npm's JSON). The package must hold the built library and plugin, the files every app needs and every
# committed file of src/, ios/, android/ and plugin/templates/, and nothing else: no tests, fixtures, mocks or dotfiles,
# and no file that .gitignore hides, which npm packs from those folders as they are on disk.
step_pack() {
  (cd "$root" && npm run prepack) || fail "npm run prepack failed"
  (cd "$root" && npm pack --dry-run --json --ignore-scripts) >"$work/pack.json" || fail "npm pack --dry-run failed"
  git -C "$root" ls-files -z --cached --others --exclude-standard >"$work/pack-files"
  python3 - "$work/pack.json" "$work/pack-files" <<'PY'
import json, re, sys

listing, files = sys.argv[1:3]
with open(listing, encoding="utf-8") as handle:
    packed = {entry["path"] for entry in json.load(handle)[0]["files"]}
with open(files, "rb") as handle:
    committed = {name.decode() for name in handle.read().split(b"\0") if name}
built = {"lib/module/index.js", "lib/typescript/src/index.d.ts", "plugin/build/index.js"}
tops = {"package.json", "README.md", "LICENSE", "app.plugin.js", "SallaPushReactNative.podspec"}
folders = ("src/", "ios/", "android/", "plugin/templates/")
excluded = re.compile(r"(^|/)(__tests__|__fixtures__|__mocks__)/|^android/src/test/|(^|/)\.")
expected = built | tops | {name for name in committed if name.startswith(folders) and not excluded.search(name)}
problems = [f"the package lacks {name}" for name in sorted(expected - packed)]
for name in sorted(packed):
    if excluded.search(name):
        problems.append(f"the package holds {name}, a test, fixture, mock or dotfile")
    elif name not in tops and not name.startswith(folders + ("lib/", "plugin/build/")):
        problems.append(f"the package holds {name}, which isn't part of the package")
    elif name.startswith(folders) and name not in committed:
        problems.append(f"the package holds {name}, which .gitignore hides; remove it, or pack from a fresh clone")
for problem in problems:
    print(problem)
if problems:
    sys.exit(f"verify.sh: {len(problems)} problem(s) in what npm would publish")
print(f"npm pack: {len(packed)} files: the built library and plugin, the native code, the podspec, README.md and LICENSE; "
      "no tests, fixtures, mocks, dotfiles or files .gitignore hides")
PY
}

step_api() { node "$scripts/dump-api.mjs" --check; }

step_parity() { node "$scripts/check-api-parity.mjs"; }

step_snippets() { node "$scripts/check-readme-snippets.mjs"; }

step_pins() { "$scripts/bump-native.sh" --check; }

# The files a build, the checks and a release need, the docs, and the scripts CI and the docs run directly.
readonly REQUIRED_FILES=".gitignore .nvmrc .yarnrc.yml .yarn/releases/yarn-4.11.0.cjs .swiftlint.yml package.json
yarn.lock README.md CHANGELOG.md CONTRIBUTING.md RELEASING.md docs/REFERENCE.md docs/TROUBLESHOOTING.md
LICENSE SallaPushReactNative.podspec app.plugin.js android/build.gradle src/index.ts src/NativeRNSallaPush.ts
plugin/src/index.ts plugin/src/constants.ts
api/sallapush-react-native.api tool/api-parity/native-ios-API.txt tool/api-parity/native-android-sallapush.api
tool/api-parity/mapping.json example/ios/Podfile example/ios/TestPayloads/native.apns
example/android/TestPayloads/native.json scripts/common.sh scripts/dump-api.mjs scripts/check-api-parity.mjs
scripts/check-readme-snippets.mjs"
readonly EXECUTABLE_FILES="scripts/verify.sh scripts/bump-native.sh scripts/self-test.sh"
# This package's workflows, at the repository's root, the only place GitHub runs workflows from.
readonly WORKFLOWS="../.github/workflows/react-native-ci.yml ../.github/workflows/react-native-publish.yml"

# What a commit takes, tracked or untracked and not ignored, of this folder and of the repository's root (its files and
# .github, every package's workflows included): no credential file, no secret, personal path, Apple team id or ticket
# key in any file, every workflow action pinned to a commit, every required file present, every script executable, and
# every Swift file of the example in a target of its Xcode project.
step_tree() {
  git -C "$root" ls-files -z --cached --others --exclude-standard -- . ':(top,glob)*' ':(top).github' >"$work/files" ||
    fail "cannot list the files of $root; run the verification in a clone of the repository"
  git -C "$root" ls-files -z --stage >"$work/staged"
  python3 - "$root" "$work/files" "$work/staged" "$REQUIRED_FILES $WORKFLOWS" "$EXECUTABLE_FILES" <<'PY'
import os, re, sys

root, listing, staged, required, executable = sys.argv[1:6]
with open(listing, "rb") as handle:
    files = [name.decode() for name in handle.read().split(b"\0") if name]
modes = {}
with open(staged, "rb") as handle:
    for entry in handle.read().split(b"\0"):
        if entry:
            meta, name = entry.decode().split("\t", 1)
            modes[name] = meta.split(" ")[0]
problems = []
credential = re.compile(
    r"^(google-services\.json|googleservice-info\.plist|local\.properties|key\.properties|service-account.*\.json|"
    r"\.env.*|.*\.(p8|p12|jks|keystore|mobileprovision|cer))$",
    re.IGNORECASE,
)
# The native repositories' token and key patterns, and this repository's own; the text patterns skip binary files. Each
# pattern is written so that this file's own text never matches it.
revoke = "remove it, and revoke it if it was ever pushed"
secrets = (
    (re.compile(rb"(?<![A-Za-z0-9_])gh[pousr]_[A-Za-z0-9]{36}(?![A-Za-z0-9_])"), "a GitHub token", revoke),
    (re.compile(rb"(?<![A-Za-z0-9_])github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}(?![A-Za-z0-9_])"), "a GitHub token", revoke),
    (re.compile(rb"-----BEGIN [A-Z0-9 ]{0,40}PRIVATE KEY(?: BLOCK)?-----"), "a private key", revoke),
    (re.compile(rb"---- BEGIN SSH2 ENCRYPTED " + rb"PRIVATE KEY ----"), "a private key", revoke),
    (re.compile(rb"PuTTY-User-Key-File-[0-9]+: "), "a private key", revoke),
    (re.compile(rb"x-access-" + rb"token:[^$]"), "a token in a git URL", revoke),
    (re.compile(rb"/Us" + rb"ers/"), "a personal home path", "use $HOME"),
)
texts = (
    (re.compile(rb"(?:DEVELOPMENT_TEA" + rb"M|DevelopmentTea" + rb"m) = [A-Z0-9]{10}(?![A-Za-z0-9_])"), "an Apple team id",
     "set DEVELOPMENT_TEAM in the ignored example/ios/Config/SallaPush.local.xcconfig instead"),
    (re.compile(rb"\b(?:T" + rb"D|S" + rb"P|R" + rb"I|SA" + rb"L|S40" + rb"D)-[0-9]+\b"), "a ticket key",
     "say what the change is instead: the code and docs are written for readers outside the organization"),
)
for name in files:
    path = os.path.join(root, name)
    if credential.match(os.path.basename(name)):
        problems.append(f"{name}: a file of credentials or signing material; never commit it")
    if not os.path.isfile(path):
        continue
    with open(path, "rb") as handle:
        data = handle.read()
    for pattern, what, fix in secrets + (texts if b"\0" not in data else ()):
        if pattern.search(data):
            problems.append(f"{name}: holds {what}; {fix}")
# The example's Swift files: Xcode compiles only those that the project lists, each in a target's Sources.
project = os.path.join(root, "example/ios/SallaPushExample.xcodeproj/project.pbxproj")
if os.path.isfile(project):
    with open(project, encoding="utf-8") as handle:
        sources = handle.read()
    for name in files:
        if re.match(r"^example/ios/(SallaPushExample|SallaPushExampleTests|SallaPushNotificationService)/[^/]+\.swift$", name) \
                and f"/* {os.path.basename(name)} in Sources */" not in sources:
            problems.append(f"{name} is in no Sources phase of example/ios/SallaPushExample.xcodeproj, so it is never "
                            "compiled: add it to its target")
uses = re.compile(r"^\s*(?:-\s+)?uses:\s*(['\"]?)([^\s'\"#]+)\1\s*(?:#.*)?$")
pinned = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[^@\s]+)?@[0-9a-f]{40}$")
allowed = re.compile(r"^\./\.github/[A-Za-z0-9_./-]+$")
for name in files:
    if re.match(r"^(\.\./)?\.github/workflows/[^/]+\.ya?ml$", name) and os.path.isfile(os.path.join(root, name)):
        with open(os.path.join(root, name), encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                match = uses.match(line)
                if match and not (pinned.match(match.group(2)) or allowed.match(match.group(2))):
                    problems.append(f"{name}:{number}: uses {match.group(2)}; pin it to a full commit id (owner/repo@<40 hex> # vX.Y.Z)")
listed = set(files)
for name in required.split() + executable.split():
    if name not in listed:
        problems.append(f"{name} is missing from what a commit takes (absent, or ignored by .gitignore)")
for name in executable.split():
    path = os.path.join(root, name)
    if name in listed and not os.access(path, os.X_OK):
        problems.append(f"{name} is not executable (chmod +x {name})")
    if modes.get(name, "100755") != "100755":
        problems.append(f"{name} is staged with mode {modes[name]}; stage it as executable (git update-index --chmod=+x {name})")
for problem in problems:
    print(problem)
if problems:
    sys.exit(f"verify.sh: {len(problems)} problem(s) in what a commit takes")
print(f"{len(files)} files: no credential, secret, personal path, team id or ticket key; every action pinned; every required file present; every script executable; every Swift file of the example compiled")
PY
}

step_shell() {
  local script shellcheck="${SHELLCHECK:-shellcheck}"
  for script in "$scripts"/*.sh; do
    bash -n "$script" || fail "${script#"$root"/} does not parse (bash -n)"
  done
  echo "bash -n: every script parses"
  if command -v "$shellcheck" >/dev/null 2>&1 &&
    "$shellcheck" --version | grep -qx "version: $SP_SHELLCHECK_VERSION"; then
    (cd "$root" && "$shellcheck" -x -S style scripts/*.sh)
  elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    (cd "$root" && docker run --rm -v "$root:/mnt:ro" -w /mnt "$SP_SHELLCHECK_IMAGE" -x -S style scripts/*.sh)
  else
    fail "shellcheck $SP_SHELLCHECK_VERSION was not found: install it or set SHELLCHECK, or run Docker for $SP_SHELLCHECK_IMAGE"
  fi
  echo "shellcheck $SP_SHELLCHECK_VERSION: no findings"
  "$scripts/self-test.sh"
}

# ---------------------------------------------------------------------------------------------------------------------
# Native steps

step_swiftlint() {
  local swiftlint="${SWIFTLINT:-swiftlint}" version
  command -v "$swiftlint" >/dev/null 2>&1 ||
    fail "SwiftLint is not installed: install $SP_SWIFTLINT_VERSION, or set SWIFTLINT"
  version="$("$swiftlint" version)"
  [ "$version" = "$SP_SWIFTLINT_VERSION" ] ||
    fail "SwiftLint $version found; the rules are pinned to $SP_SWIFTLINT_VERSION (set SWIFTLINT)"
  (cd "$root" && "$swiftlint" lint --strict --quiet --config .swiftlint.yml)
  echo "SwiftLint $version: no violations"
}

# Asserts on an APK's manifest: SallaPush's init provider at initOrder -1, after Firebase's and androidx.startup's
# providers (higher values run first), and SallaPush's FCM service at priority -450.
assert_manifest() {
  local apk="$1" aapt2
  aapt2="$(find "$ANDROID_HOME/build-tools" -maxdepth 2 -name aapt2 -type f | sort | tail -n 1)"
  [ -n "$aapt2" ] || fail "aapt2 was not found under $ANDROID_HOME/build-tools"
  "$aapt2" dump xmltree --file AndroidManifest.xml "$apk" >"$work/manifest.txt"
  python3 - "$work/manifest.txt" <<'PY'
import re, sys

nodes, stack = [], []
for line in open(sys.argv[1], encoding="utf-8"):
    indent = len(line) - len(line.lstrip())
    element = re.match(r"\s*E: ([\w.-]+)", line)
    attribute = re.match(r"\s*A: (?:http://schemas\.android\.com/apk/res/android:)?([\w]+)(?:\(0x[0-9a-f]+\))?=(.*)$", line)
    if element:
        while stack and stack[-1]["indent"] >= indent:
            stack.pop()
        node = {"tag": element.group(1), "indent": indent, "attributes": {}, "parent": stack[-1] if stack else None}
        nodes.append(node)
        stack.append(node)
    elif attribute and stack:
        value = attribute.group(2).strip()
        quoted = re.match(r'^"((?:[^"\\]|\\.)*)"', value)
        stack[-1]["attributes"][attribute.group(1)] = quoted.group(1) if quoted else value.split(" ")[0]

def named(tag, name):
    return [node for node in nodes if node["tag"] == tag and node["attributes"].get("name") == name]

def init_order(node):
    return int(node["attributes"].get("initOrder", "0"), 0)

problems = []
provider = named("provider", "sa.salla.sallapush.reactnative.SallaPushInitProvider")
if len(provider) != 1:
    sys.exit("the manifest must hold SallaPushInitProvider once")
ours = init_order(provider[0])
if ours != -1:
    problems.append(f"SallaPushInitProvider has initOrder {ours}, not -1")
for name in ("com.google.firebase.provider.FirebaseInitProvider", "androidx.startup.InitializationProvider"):
    for node in named("provider", name):
        if init_order(node) <= ours:
            problems.append(f"{name} (initOrder {init_order(node)}) must run before SallaPushInitProvider")
        print(f"{name}: initOrder {init_order(node)}")
service = named("service", "com.salla.push.SallaPushFirebaseMessagingService")
filters = [node for node in nodes if node["tag"] == "intent-filter" and node["parent"] in service]
priorities = sorted(int(node["attributes"].get("priority", "0"), 0) for node in filters)
if priorities != [-450]:
    problems.append(f"SallaPush's FCM service has the intent-filter priorities {priorities}, not [-450]")
for problem in problems:
    print(problem)
if problems:
    sys.exit("the merged manifest is not the one SallaPush needs")
print(f"SallaPushInitProvider: initOrder {ours}; SallaPushFirebaseMessagingService: priority {priorities[0]}")
PY
}

readonly ANDROID_STRING_META_DATA="com.salla.push.APP_VERSION|sallapush_app_version|2.10
com.salla.push.default_channel_name|sallapush_default_channel_name|Today's offers"

# Asserts that an APK's meta-data in ANDROID_STRING_META_DATA (<name>|<string resource>|<text>) each name the string
# resource holding the exact text the consumer app's plugin options give: AAPT types a literal android:value, so "2.10"
# would arrive as the float 2.1.
assert_string_meta_data() {
  local apk="$1" aapt2
  aapt2="$(find "$ANDROID_HOME/build-tools" -maxdepth 2 -name aapt2 -type f | sort | tail -n 1)"
  [ -n "$aapt2" ] || fail "aapt2 was not found under $ANDROID_HOME/build-tools"
  "$aapt2" dump xmltree --file AndroidManifest.xml "$apk" >"$work/strings-manifest.txt"
  "$aapt2" dump resources "$apk" >"$work/strings-resources.txt"
  python3 - "$work/strings-manifest.txt" "$work/strings-resources.txt" "$ANDROID_STRING_META_DATA" <<'PY'
import re, sys

manifest, resources, expected = sys.argv[1:4]
values, current = {}, None
for line in open(manifest, encoding="utf-8"):
    if re.match(r"\s*E: ", line):
        current = None
    named = re.match(r'\s*A: (?:\S+:)?name\(0x[0-9a-f]+\)="([^"]*)"', line)
    if named:
        current = named.group(1)
    valued = re.match(r"\s*A: (?:\S+:)?value\(0x[0-9a-f]+\)=(\S+)", line)
    if valued and current:
        values[current] = valued.group(1)
lines = open(resources, encoding="utf-8").read().splitlines()
entries = {}
for index, line in enumerate(lines):
    entry = re.match(r"\s*resource (0x[0-9a-f]+) (\S+)$", line)
    if entry and index + 1 < len(lines):
        entries[entry.group(1)] = (entry.group(2), lines[index + 1].strip())
problems = []
for row in expected.splitlines():
    name, resource, text = row.split("|")
    value = values.get(name)
    found = entries.get(value[1:]) if value and value.startswith("@") else None
    if found != (f"string/{resource}", f'() "{text}"'):
        problems.append(f"{name} is {value} {found or ''}, not @string/{resource} holding {text!r}")
    else:
        print(f"{name}: @string/{resource}, {text!r}")
for problem in problems:
    print(problem)
sys.exit(1 if problems else 0)
PY
}

step_android() {
  local project apk
  sp_android_env || fail "the Android setup is incomplete"
  cd "$root/example/android"
  ./gradlew --quiet projects >"$work/projects.txt"
  project="$(sed -nE "s/.*Project '(:[^']*mobile-push-react-native)'.*/\1/p" "$work/projects.txt" | head -n 1)"
  [ -n "$project" ] || fail "./gradlew projects lists no autolinked mobile-push-react-native project"
  echo "library project $project"
  ./gradlew --quiet "$project:testDebugUnitTest" "$project:lintDebug" assembleRelease
  assert_tests_ran "$root/android/build/test-results/testDebugUnitTest"
  apk="$root/example/android/app/build/outputs/apk/release/app-release.apk"
  [ -f "$apk" ] || fail "assembleRelease made no $apk"
  assert_manifest "$apk"
}

# Copies the tracked files of example/ios (pod install rewrites some of them) to <dir>, or back from it.
ios_files() {
  local direction="$1" dir="$2" name
  git -C "$root" ls-files -z -- example/ios >"$work/ios-files"
  while IFS= read -r -d '' name; do
    if [ "$direction" = save ]; then
      mkdir -p "$dir/$(dirname "$name")"
      cp -p "$root/$name" "$dir/$name"
    else
      cmp -s "$dir/$name" "$root/$name" || cp -p "$dir/$name" "$root/$name"
    fi
  done <"$work/ios-files"
}

pod_install() {
  (cd "$root/example/ios" && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install --silent) ||
    fail "pod install failed: the SallaPush pods come from https://github.com/SallaApp/mobile-push-ios-sdk.git with git"
}

# Asserts how a build of the example linked the SallaPush pods: libraries (libSallaPush.a), static (frameworks the app
# doesn't embed) or dynamic (frameworks the app embeds, for the extension too).
assert_linkage() {
  local linkage="$1" products="$work/derived-$2/Build/Products/Release-iphonesimulator" pod
  for pod in SallaPush SallaPushCore SallaPushExtension; do
    case "$linkage" in
      libraries) [ -f "$products/$pod/lib$pod.a" ] || fail "$2: $pod is not a static library" ;;
      static)
        [ -d "$products/$pod/$pod.framework" ] && [ ! -e "$products/$SP_EXAMPLE.app/Frameworks/$pod.framework" ] ||
          fail "$2: $pod is not a static framework"
        ;;
      dynamic) [ -d "$products/$SP_EXAMPLE.app/Frameworks/$pod.framework" ] || fail "$2: the app does not embed $pod.framework" ;;
    esac
  done
  echo "$2: SallaPush, SallaPushCore and SallaPushExtension linked as $linkage"
}

ios_build() {
  local name="$1" configuration="$2"
  shift 2
  (cd "$root/example/ios" && xcodebuild -quiet -workspace "$SP_EXAMPLE.xcworkspace" -scheme "$SP_EXAMPLE" \
    -configuration "$configuration" -sdk iphonesimulator -destination "id=$udid" \
    -derivedDataPath "$work/derived-$name" "$@" build) || fail "the $name build of the example failed"
  echo "$name: $configuration build succeeded"
}

step_ios() {
  local picked linkage
  require_macos
  picked="$(sp_simulator "$work")" || fail "no simulator to build for"
  udid="${picked%%$'\t'*}"
  echo "simulator ${picked#*$'\t'} $udid"
  ios_files save "$work/ios-tracked"
  trap 'ios_files restore "$work/ios-tracked"' EXIT
  for linkage in static dynamic; do
    echo "== USE_FRAMEWORKS=$linkage"
    USE_FRAMEWORKS="$linkage" pod_install
    ios_build "frameworks-$linkage" Release
    assert_linkage "$linkage" "frameworks-$linkage"
    rm -rf "$work/derived-frameworks-$linkage"
    ios_files restore "$work/ios-tracked"
  done
  echo "== static libraries (the default)"
  pod_install
  git -C "$root" diff --quiet -- example/ios ||
    fail "pod install changed tracked files of example/ios: $(git -C "$root" diff --name-only -- example/ios | tr '\n' ' ')"
  ios_build libraries Release
  assert_linkage libraries libraries
  (cd "$root/example/ios" && xcodebuild -quiet test -workspace "$SP_EXAMPLE.xcworkspace" -scheme "$SP_EXAMPLE" \
    -destination "id=$udid" -derivedDataPath "$work/derived-libraries" -only-testing:"${SP_EXAMPLE}Tests" \
    -parallel-testing-enabled NO -resultBundlePath "$work/${SP_EXAMPLE}Tests.xcresult") ||
    fail "the example's XCTest suite failed"
  rm -rf "$work/derived-libraries"
  assert_xctests_ran "$work/${SP_EXAMPLE}Tests.xcresult" || fail "${SP_EXAMPLE}Tests ran no test"
  echo "${SP_EXAMPLE}Tests passed"
}

# Prints the JSON after <marker> in the first line of <log> that holds it, within <seconds>; fails after them.
await_marker() {
  local log="$1" marker="$2" seconds="$3" waited=0
  while [ "$waited" -lt "$seconds" ]; do
    if python3 - "$log" "$marker" <<'PY'; then
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    start = line.find(sys.argv[2] + " {")
    if start >= 0:
        value, _ = json.JSONDecoder().raw_decode(line[start + len(sys.argv[2]) + 1 :])
        print(json.dumps(value))
        sys.exit(0)
sys.exit(1)
PY
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done
  return 1
}

# Fails unless the self-test passed; prints "waiting" when it awaits the smoke notification, else why it skipped it.
selftest_result() {
  python3 - "$1" <<'PY'
import json, sys
result = json.loads(sys.argv[1])
if result.get("failed") != 0 or not result.get("passed"):
    print(f"self-test: {result.get('passed')} passed, {result.get('failed')} failed: {result.get('failures')}", file=sys.stderr)
    sys.exit(1)
skipped = "; ".join(result.get("skipped") or [])
print(f"self-test: {result['passed']} passed, 0 failed{'; skipped: ' + skipped if skipped else ''}", file=sys.stderr)
print(result.get("willDisplay", "skipped: no will-display result"))
PY
}

will_display_result() {
  python3 - "$1" <<'PY'
import json, sys
result = json.loads(sys.argv[1])
if result.get("ok") is not True:
    sys.exit("will-display: " + json.dumps(result.get("failures")))
PY
}

smoke_cleanup() {
  [ -z "${stream:-}" ] || kill "$stream" 2>/dev/null || true
  if [ -n "${udid:-}" ]; then
    xcrun simctl terminate "$udid" "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$udid" "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
  fi
  if [ -n "${serial:-}" ]; then
    "$ADB" -s "$serial" uninstall "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
  fi
}

smoke_ios() {
  local picked log result display
  picked="$(sp_simulator "$work")" || fail "no simulator to run on"
  udid="${picked%%$'\t'*}"
  echo "simulator ${picked#*$'\t'} $udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # The example's own bundle id, whatever SallaPush.local.xcconfig sets: every call below names it.
  ios_build smoke Release SALLAPUSH_APP_ID=example_smoke SALLAPUSH_EXAMPLE_BUNDLE_ID="$SP_EXAMPLE_ID"
  xcrun simctl terminate "$udid" "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$work/derived-smoke/Build/Products/Release-iphonesimulator/$SP_EXAMPLE.app"
  rm -rf "$work/derived-smoke"
  log="$work/smoke-ios.log"
  xcrun simctl spawn "$udid" log stream --level info --style compact \
    --predicate "process == \"$SP_EXAMPLE\" AND eventMessage CONTAINS \"SALLAPUSH_SELFTEST\"" >"$log" 2>&1 &
  stream=$!
  sleep 2
  xcrun simctl launch "$udid" "$SP_EXAMPLE_ID" >/dev/null
  result="$(await_marker "$log" SALLAPUSH_SELFTEST 120)" || fail "iOS: no SALLAPUSH_SELFTEST line within 120 s"
  display="$(selftest_result "$result")" || fail "iOS: the self-test failed"
  if [ "$display" = waiting ]; then
    xcrun simctl push "$udid" "$SP_EXAMPLE_ID" "$root/example/ios/TestPayloads/native.apns" >/dev/null
    result="$(await_marker "$log" SALLAPUSH_SELFTEST_WILL_DISPLAY 60)" ||
      fail "iOS: no SALLAPUSH_SELFTEST_WILL_DISPLAY line within 60 s of the smoke notification"
    will_display_result "$result" || fail "iOS: the foreground notification differs from the smoke payload"
    echo "iOS: the smoke notification reached the will-display listener with the payload's values"
  else
    echo "iOS: will-display SKIPPED ($display)"
  fi
  smoke_cleanup
  stream=""
  udid=""
}

smoke_android() {
  local apk pid log result display waited=0
  sp_android_env || fail "the Android setup is incomplete"
  serial="$(sp_emulator)" || fail "no emulator to run on"
  echo "emulator $serial"
  # The example's own application id, whatever sallapush.properties sets: every call below names it. Google services
  # stay out: a google-services.json for another application id has no client for this one.
  (cd "$root/example/android" && ORG_GRADLE_PROJECT_sallapushAppId=example_smoke \
    ORG_GRADLE_PROJECT_sallapushApplicationId="$SP_EXAMPLE_ID" \
    ORG_GRADLE_PROJECT_sallapushSkipGoogleServices=true ./gradlew --quiet assembleRelease)
  apk="$root/example/android/app/build/outputs/apk/release/app-release.apk"
  "$ADB" -s "$serial" uninstall "$SP_EXAMPLE_ID" >/dev/null 2>&1 || true
  "$ADB" -s "$serial" install -r "$apk" >/dev/null
  "$ADB" -s "$serial" shell pm grant "$SP_EXAMPLE_ID" android.permission.POST_NOTIFICATIONS
  "$ADB" -s "$serial" shell am start -W -n "$SP_EXAMPLE_ID/$SP_EXAMPLE_ID.MainActivity" >/dev/null
  log="$work/smoke-android.log"
  : >"$log"
  while [ "$waited" -lt 120 ]; do
    pid="$("$ADB" -s "$serial" shell pidof "$SP_EXAMPLE_ID" | tr -d '\r')" || pid=""
    [ -z "$pid" ] || "$ADB" -s "$serial" logcat -d --pid="$pid" -s ReactNativeJS:V >"$log"
    if result="$(await_marker "$log" SALLAPUSH_SELFTEST 1)"; then
      break
    fi
    waited=$((waited + 2))
  done
  [ -n "${result:-}" ] || [ -n "$pid" ] ||
    fail "Android: the app is not running; it may have crashed at launch (adb logcat -b crash)"
  [ -n "${result:-}" ] || fail "Android: no SALLAPUSH_SELFTEST line within 120 s"
  display="$(selftest_result "$result")" || fail "Android: the self-test failed"
  if [ "$display" = waiting ]; then
    "$ADB" -s "$serial" shell am broadcast -n "$SP_EXAMPLE_ID/$SP_EXAMPLE_ID.TestPushReceiver" \
      --es payload "'$(tr -d '\n' <"$root/example/android/TestPayloads/native.json")'" >/dev/null
    result=""
    waited=0
    while [ "$waited" -lt 60 ]; do
      "$ADB" -s "$serial" logcat -d --pid="$pid" -s ReactNativeJS:V >"$log"
      if result="$(await_marker "$log" SALLAPUSH_SELFTEST_WILL_DISPLAY 1)"; then
        break
      fi
      waited=$((waited + 2))
    done
    [ -n "$result" ] || fail "Android: no SALLAPUSH_SELFTEST_WILL_DISPLAY line within 60 s of the smoke notification"
    will_display_result "$result" || fail "Android: the foreground notification differs from the smoke payload"
    echo "Android: the smoke notification reached the will-display listener with the payload's values"
  else
    echo "Android: will-display SKIPPED ($display)"
  fi
  "$ADB" -s "$serial" shell am force-stop "$SP_EXAMPLE_ID"
  smoke_cleanup
  serial=""
}

step_smoke() {
  require_macos
  trap smoke_cleanup EXIT
  smoke_ios
  smoke_android
}

# ---------------------------------------------------------------------------------------------------------------------
# Consumer apps

readonly CREATE_EXPO_APP=create-expo-app@5.0.0
readonly CONSUMER_NPM=npm@12.2.0
readonly CONSUMER_YARN=yarn@4.18.1
readonly RNFB_VERSION=26.4.0

# Edits <app>/app.json and package.json for a consumer variant: the plugin with every platform's props, and the extra
# libraries of the variant (expo-notifications, or React Native Firebase with dynamic frameworks).
consumer_config() {
  python3 - "$@" <<'PY'
import json, os, sys

app, sdk, variant, dependency = sys.argv[1:5]
name = os.path.basename(app)
with open(os.path.join(app, "app.json"), encoding="utf-8") as handle:
    config = json.load(handle)
expo = config["expo"]
bundle = f"sa.salla.sallapush.consumer.{name}"
expo.setdefault("ios", {})["bundleIdentifier"] = bundle
expo.setdefault("android", {})["package"] = bundle
plugins = [["@salla.sa/mobile-push-react-native", {
    "ios": {"appId": "consumer_check", "requiresUserConsent": True, "appGroup": f"group.{bundle}", "logLevel": "info"},
    "android": {"appId": "consumer_check", "requiresUserConsent": True, "logLevel": "info", "appVersion": "2.10",
                "smallIcon": "./assets/icon.png", "defaultChannelId": "general", "defaultChannelName": "Today's offers"},
}]]
if variant == "firebase":
    expo["ios"]["googleServicesFile"] = "./GoogleService-Info.plist"
    expo["android"]["googleServicesFile"] = "./google-services.json"
    plugins += ["@react-native-firebase/app", ["expo-build-properties", {"ios": {"useFrameworks": "dynamic"}}]]
expo["plugins"] = plugins
with open(os.path.join(app, "app.json"), "w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=2)

# Placeholder Firebase files: enough for the Gradle and CocoaPods builds, never for a run.
if variant == "firebase":
    with open(os.path.join(app, "google-services.json"), "w", encoding="utf-8") as handle:
        json.dump({
            "project_info": {"project_number": "100000000000", "project_id": "placeholder-project",
                             "storage_bucket": "placeholder-project.appspot.com"},
            "client": [{
                "client_info": {"mobilesdk_app_id": "1:100000000000:android:0000000000000000",
                                "android_client_info": {"package_name": bundle}},
                "oauth_client": [], "api_key": [{"current_key": "placeholder-key"}],
                "services": {"appinvite_service": {"other_platform_oauth_client": []}},
            }],
            "configuration_version": "1",
        }, handle, indent=2)
    with open(os.path.join(app, "GoogleService-Info.plist"), "w", encoding="utf-8") as handle:
        handle.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>API_KEY</key><string>placeholder-key</string>
  <key>GCM_SENDER_ID</key><string>100000000000</string>
  <key>PLIST_VERSION</key><string>1</string>
  <key>BUNDLE_ID</key><string>{bundle}</string>
  <key>PROJECT_ID</key><string>placeholder-project</string>
  <key>STORAGE_BUCKET</key><string>placeholder-project.appspot.com</string>
  <key>IS_ADS_ENABLED</key><false/>
  <key>IS_ANALYTICS_ENABLED</key><false/>
  <key>IS_APPINVITE_ENABLED</key><true/>
  <key>IS_GCM_ENABLED</key><true/>
  <key>IS_SIGNIN_ENABLED</key><true/>
  <key>GOOGLE_APP_ID</key><string>1:100000000000:ios:0000000000000000</string>
</dict>
</plist>
""")

with open(os.path.join(app, "package.json"), encoding="utf-8") as handle:
    package = json.load(handle)
with open(os.path.join(app, "node_modules", "expo", "bundledNativeModules.json"), encoding="utf-8") as handle:
    bundled = json.load(handle)
extras = {"@salla.sa/mobile-push-react-native": dependency}
if variant == "notifications":
    extras["expo-notifications"] = bundled["expo-notifications"]
if variant == "firebase":
    extras["expo-build-properties"] = bundled["expo-build-properties"]
    extras["@react-native-firebase/app"] = sys.argv[5]
    extras["@react-native-firebase/messaging"] = sys.argv[5]
package["dependencies"].update(extras)
with open(os.path.join(app, "package.json"), "w", encoding="utf-8") as handle:
    json.dump(package, handle, indent=2)
    handle.write("\n")
PY
}

# Asserts on a prebuilt consumer app what the plugin generates, and on the app's builds what they embed.
consumer_assert() {
  local app="$1" variant="$2" stage="$3"
  python3 - "$app" "$variant" "$stage" <<'PY'
import glob, os, sys

app, variant, stage = sys.argv[1:4]
name = os.path.basename(app)
problems = []

def holds(pattern, text, what):
    files = glob.glob(os.path.join(app, pattern), recursive=True)
    if not files:
        problems.append(f"{pattern} is missing ({what})")
    elif not any(text in open(path, encoding="utf-8").read() for path in files):
        problems.append(f"{pattern} lacks {text!r} ({what})")

if stage == "prebuild":
    holds("ios/*/AppDelegate.swift", "SallaPushRN.start()", "E3")
    holds("ios/*/Info.plist", "<key>SallaPushAppId</key>", "E1")
    holds("ios/Podfile", "target 'SallaPushNotificationService' do", "E4")
    holds("ios/SallaPushNotificationService/NotificationService.swift", "SallaPushServiceExtension", "E5")
    holds("android/app/src/main/AndroidManifest.xml", "com.salla.push.APP_ID", "E8")
    service = glob.glob(os.path.join(app, "android/app/src/main/java/**/SallaPushMessagingService.kt"), recursive=True)
    base = {"notifications": "ExpoFirebaseMessagingService", "firebase": "ReactNativeFirebaseMessagingService"}.get(variant)
    if base:
        holds("android/app/src/main/java/**/SallaPushMessagingService.kt", base, "E10")
    elif service:
        problems.append("SallaPushMessagingService.kt was generated without an FCM library")
elif stage == "ios":
    apps = glob.glob(os.path.join(app, "derived", "Build", "Products", "Debug-iphonesimulator", "*.app"))
    if not apps or not os.path.isdir(os.path.join(apps[0], "PlugIns", "SallaPushNotificationService.appex")):
        problems.append("the app does not embed SallaPushNotificationService.appex")
    if variant == "firebase" and apps and not os.path.isdir(os.path.join(apps[0], "Frameworks", "SallaPush.framework")):
        problems.append("the dynamic-framework app does not embed SallaPush.framework")
for problem in problems:
    print(f"{name}: {problem}")
sys.exit(1 if problems else 0)
PY
}

# consumer_app <name> <Expo SDK> <variant> <dependency>: an Expo app that installs the package from <dependency>, the
# packed release's file or its URL (allowed in .npmrc), then prebuilds and builds.
consumer_app() {
  local name="$1" sdk="$2" variant="$3" dependency="$4" app="$work/$1" workspace
  echo "== $name: Expo SDK $sdk${variant:+, $variant}, from $dependency"
  (cd "$work" && npx --yes "$CREATE_EXPO_APP" "$name" --template "blank-typescript@sdk-$sdk" --no-install >/dev/null)
  case "$dependency" in http*) printf 'allow-remote=root\n' >"$app/.npmrc" ;; esac
  (cd "$app" && npm install --no-audit --no-fund --loglevel=error)
  consumer_config "$app" "$sdk" "$variant" "$dependency" "$RNFB_VERSION"
  (cd "$app" && npm install --no-audit --no-fund --loglevel=error)
  [ -f "$app/node_modules/@salla.sa/mobile-push-react-native/lib/module/index.js" ] ||
    fail "$name: the install lacks the built lib/"
  (cd "$app" && CI=1 npx expo prebuild --clean --no-install >/dev/null)
  consumer_assert "$app" "$variant" prebuild || fail "$name: the prebuild lacks what the plugin generates"
  (cd "$app/ios" && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install --silent) || fail "$name: pod install failed"
  workspace="$(cd "$app/ios" && ls -d ./*.xcworkspace)"
  workspace="${workspace#./}"
  (cd "$app/ios" && xcodebuild -quiet -workspace "$workspace" -scheme "${workspace%.xcworkspace}" -configuration Debug \
    -sdk iphonesimulator -destination "id=$udid" -derivedDataPath "$app/derived" CODE_SIGNING_ALLOWED=NO build) ||
    fail "$name: the iOS build failed"
  consumer_assert "$app" "$variant" ios || fail "$name: the iOS build lacks what it must embed"
  echo "$name: iOS build succeeded"
  rm -rf "$app/derived"
  (cd "$app/android" && ./gradlew --quiet :app:assembleDebug -PreactNativeArchitectures=arm64-v8a) ||
    fail "$name: the Android build failed"
  assert_string_meta_data "$app/android/app/build/outputs/apk/debug/app-debug.apk" ||
    fail "$name: the plugin's string options don't reach the APK as their exact text"
  echo "$name: Android build succeeded"
  # Removed once checked: its node_modules, pods and builds take several GB, which the next app needs.
  rm -rf "$app"
}

# yarn_install <app> <log>: yarn install, once more after a network error of the registry.
yarn_install() {
  local attempt
  for attempt in 1 2; do
    if (cd "$1" && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 corepack yarn install) >"$2" 2>&1; then
      return 0
    fi
    grep -qE 'ERR_SOCKET_|ECONNRESET|ETIMEDOUT|EAI_AGAIN' "$2" || return 1
    echo "yarn install: a network error (attempt $attempt)"
  done
  return 1
}

# consumer_yarn <name> <url>: the Yarn install of the packed release from its URL.
consumer_yarn() {
  local name="$1" url="$2" app="$work/$1"
  echo "== $name: Expo SDK 57 with $CONSUMER_YARN, from $url"
  (cd "$work" && npx --yes "$CREATE_EXPO_APP" "$name" --template blank-typescript@sdk-57 --no-install >/dev/null)
  python3 - "$app/package.json" "$CONSUMER_YARN" "$url" <<'PY'
import json, sys
path, manager, dependency = sys.argv[1:4]
package = json.load(open(path, encoding="utf-8"))
package["packageManager"] = manager
package["dependencies"]["@salla.sa/mobile-push-react-native"] = dependency
with open(path, "w", encoding="utf-8") as handle:
    json.dump(package, handle, indent=2)
    handle.write("\n")
PY
  : >"$app/yarn.lock"
  # The template's newest Expo releases can be younger than Yarn's default one-day age gate, which is no concern here.
  # Yarn takes plain HTTP only from the hosts unsafeHttpWhitelist names: the local server's here, while the GitHub
  # Release serves HTTPS.
  printf 'nodeLinker: node-modules\nnpmMinimalAgeGate: 0\nunsafeHttpWhitelist:\n  - "127.0.0.1"\n' >"$app/.yarnrc.yml"
  yarn_install "$app" "$work/$name-install.log" || {
    tail -n 40 "$work/$name-install.log"
    fail "$name: yarn install of the packed release failed"
  }
  [ -f "$app/node_modules/@salla.sa/mobile-push-react-native/lib/module/index.js" ] &&
    [ -f "$app/node_modules/@salla.sa/mobile-push-react-native/plugin/build/index.js" ] &&
    [ -f "$app/node_modules/@salla.sa/mobile-push-react-native/plugin/templates/NotificationService.swift" ] ||
    fail "$name: the Yarn install lacks lib/, plugin/build/ or plugin/templates/"
  (cd "$app" && node -e "require('@salla.sa/mobile-push-react-native/app.plugin.js')") ||
    fail "$name: the installed config plugin does not load"
  echo "$name: Yarn installs the packed release from its URL, and its config plugin loads"
}

consumer_cleanup() {
  [ -z "${server:-}" ] || kill "$server" 2>/dev/null || true
}

step_consumer() {
  local picked npm_bin tarball port url waited=0
  require_macos
  trap consumer_cleanup EXIT
  sp_android_env || fail "the Android setup is incomplete"
  picked="$(sp_simulator "$work")" || fail "no simulator to build for"
  udid="${picked%%$'\t'*}"
  # The release as the publish workflow packs it: the pack step's fresh build and checks, then npm pack.
  step_pack
  mkdir -p "$work/release"
  tarball="$(cd "$root" && npm pack --json --ignore-scripts --pack-destination "$work/release" |
    python3 -c 'import json, sys; print(json.load(sys.stdin)[0]["filename"])')" || fail "npm pack failed"
  tarball="$work/release/$tarball"
  [ -f "$tarball" ] || fail "npm pack made no tarball"
  # Its URL, as the GitHub Release serves it, from a local server.
  port="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
  python3 -I -m http.server --bind 127.0.0.1 --directory "$work/release" "$port" >"$work/http.log" 2>&1 &
  server=$!
  url="http://127.0.0.1:$port/${tarball##*/}"
  until curl -fsS -o /dev/null "$url" 2>/dev/null; do
    [ "$waited" -lt 20 ] || fail "the local server does not serve $url"
    sleep 1
    waited=$((waited + 1))
  done
  npm install --prefix "$work/npm" --no-audit --no-fund --loglevel=error "$CONSUMER_NPM" >/dev/null
  npm_bin="$work/npm/node_modules/.bin"
  echo "consumer apps install with npm $("$npm_bin/npm" --version): the packed release, from the file and from its URL"
  PATH="$npm_bin:$PATH" consumer_app consumer57 57 notifications "file:$tarball"
  PATH="$npm_bin:$PATH" consumer_app consumer54 54 "" "$url"
  PATH="$npm_bin:$PATH" consumer_app consumer57firebase 57 firebase "file:$tarball"
  consumer_yarn consumer57yarn "$url"
  kill "$server"
  server=""
}

# ---------------------------------------------------------------------------------------------------------------------
# Runner

case "${1:-}" in -h | --help) usage ;; esac
steps="$*"
[ -n "$steps" ] || steps="$STEPS"
for step in $steps; do
  case " $STEPS " in
    *" $step "*) ;;
    *) fail "unknown step '$step' (steps: $STEPS)" ;;
  esac
done

logs="${VERIFY_LOG_DIR:-$work/logs}"
mkdir -p "$logs"
summary="$logs/summary.tsv"
# The commit this run verifies, +dirty when react-native/ has changes. summary.tsv holds the runs of one commit, named
# in its first line and in every row, so the results of one commit are never taken for another's.
commit="$(git -C "$root" rev-parse -q --verify HEAD 2>/dev/null)" || commit=none
state=clean
[ "$commit" != none ] && [ -z "$(git -C "$root" status --porcelain -- . 2>/dev/null)" ] || state=dirty
revision="$commit"
[ "$state" = clean ] || revision="$commit+dirty"
if [ -f "$summary" ]; then
  recorded="$(sed -nE '1s/^# ([^ ]+) .*/\1/p' "$summary")"
  [ "$recorded" = "$commit" ] ||
    fail "$summary holds the runs of ${recorded:-another commit}, not of $commit: use a VERIFY_LOG_DIR for each commit"
else
  printf '# %s %s\nstep\tresult\tcommit\n' "$commit" "$state" >"$summary"
fi
grouped=false
[ "${GITHUB_ACTIONS:-}" != true ] || [ "$steps" = "${steps%% *}" ] || grouped=true

for step in $steps; do
  function_name="step_$step"
  log="$logs/$step.log"
  ! $grouped || echo "::group::verify.sh $step"
  echo "==> verify.sh $step"
  started="$(date +%s)"
  # A subshell with errexit, outside any if/!/&& context, so a failing command inside a step can never be ignored.
  set +e
  (
    set -e
    "$function_name"
  ) 2>&1 | tee "$log"
  status="${PIPESTATUS[0]}"
  set -e
  seconds=$(($(date +%s) - started))
  ! $grouped || echo "::endgroup::"
  if [ "$status" -ne 0 ]; then
    printf '%s\tfailed\t%s\n' "$step" "$revision" >>"$summary"
    fail "$step: failed (exit $status) after ${seconds}s${VERIFY_LOG_DIR:+; log: $log}"
  fi
  printf '%s\tpassed\t%s\n' "$step" "$revision" >>"$summary"
  echo "verify.sh: $step: ok (${seconds}s)"
done
echo "verify.sh: all passed ($steps)"
