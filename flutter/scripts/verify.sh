#!/usr/bin/env bash
# The full verification of the SallaPush Flutter SDK. CI runs most steps on every pull request that changes it
# (.github/workflows/flutter-ci.yml). The others need a simulator, an emulator or Flutter 3.44 on a Mac: run every step
# before a release (RELEASING.md).
#
#   scripts/verify.sh [step...]     run from anywhere
#
# Steps, in order (without arguments it runs them all and stops at the first failure):
#   format     dart format changes nothing
#   analyze    pub get and flutter analyze, in the plugin and in the example
#   test       the unit tests, covering at least 90 % of the lines of lib/src; the example's widget tests
#   pigeon     the committed generated code is what scripts/generate-pigeon.sh generates
#   api        the public Dart API is api/mobile_push.api (tool/dump_api.dart --check)
#   parity     every native symbol has a decision in tool/api-parity/mapping.json (tool/check_api_parity.dart)
#   snippets   README.md and docs/ show the code that this script builds (tool/check_readme_snippets.dart)
#   pins       every native version pin agrees (scripts/bump-native.sh --check)
#   tree       what a commit takes, in flutter/ and in the package's workflows at the repository's root: no secret,
#              credential file, personal path, team id or ticket key; the required files, the scripts executable; every
#              workflow action pinned; every Swift file of the example in its Xcode project; the example's Dart SDK
#              bound is the plugin's
#   shell      bash -n, shellcheck 0.11.0 and scripts/self-test.sh
#   pub        flutter pub publish --dry-run finds nothing to warn about, and its archive holds the package, its example,
#              LICENSE, README.md and CHANGELOG.md, without the repository's own tooling and docs (.pubignore)
#   swiftlint  SwiftLint 0.63.2, strict (.swiftlint.yml)
#   android    the plugin's unit tests and Android lint; the example's release build, shrunk by R8 as Flutter shrinks
#              every release build, with no rule of its own; its merged manifest: the init provider after Firebase's and
#              androidx.startup's, SallaPush's service at -450; and that build on an emulator, which must start and run
#              for 15 s without a crash
#   ios        the example and its extension, with Swift Package Manager; the plugin's XCTest suite on a simulator
#   ios-pods   a fresh app with Swift Package Manager disabled: the README's AppDelegate with the setup guide's
#              methods for other push SDKs, docs/snippets/Podfile and an extension that links SallaPushExtension through
#              CocoaPods
#   ios-mixed  a fresh app with Swift Package Manager and a CocoaPods-only plugin: SallaPush comes through Swift
#              Package Manager, and no SallaPush pod is installed
#   min-sdk    with FLUTTER_MIN, the oldest supported Flutter, in a worktree of HEAD: pub get, analyze, test, and the
#              example's builds for both platforms
#   smoke      the example's integration tests on a simulator and an emulator, with a made-up app id: they reach
#              SallaPush's production service, which refuses it
#   consumer   a fresh app that installs HEAD from git, in place of the pub.dev release that README.md adds, and applies
#              only what README.md shows, with the icon it links; it builds for both platforms, with the README's app ids
# The portable steps, which also run on Linux: format analyze test pigeon api parity snippets pins tree shell pub
# android; CI runs them all, android without the emulator run, and swiftlint ios ios-pods on macOS. The others need
# macOS. pub, min-sdk and consumer take the committed HEAD, so they need a clean tree in flutter/; changes elsewhere in
# the repository don't count.
#
# Environment:
#   FLUTTER                  the flutter binary (default: flutter on PATH); DART is the dart next to it
#   FLUTTER_MIN              the flutter binary of the oldest supported Flutter, 3.44.x, for min-sdk
#   VERIFY_LOG_DIR           when set, receives a <step>.log per step and summary.tsv, whose first line and rows name the
#                            commit (+dirty for a tree with changes); a folder for each commit, as runs of another
#                            commit are refused
#   VERIFY_SIMULATOR_UDID    the simulator of ios and smoke (default: a booted iPhone, else the newest)
#   VERIFY_EMULATOR_SERIAL   the emulator of android and smoke (default: the only running emulator)
#   VERIFY_ANDROID_NO_EMULATOR=1  android runs every check but the release build's 15 s on an emulator, and needs
#                            none; its summary says so (CI, whose runners have no emulator)
#   VERIFY_IOS_SDK_CHECKOUT  optional: a clone of SallaApp/mobile-push-ios-sdk in a folder named mobile-push-ios-sdk,
#                            with the pinned tag checked out and no changes (another commit, or a change, is refused).
#                            Every Swift Package Manager build then uses it instead of the remote package (Xcode
#                            replaces a remote package with a local one of the same name), for a Mac that can't fetch
#                            the repository. The summary of each such step says so.
#   SMOKE_HOT_RESTART=1      smoke also checks a hot restart on both devices
#   SWIFTLINT, SHELLCHECK    the binaries (default: on PATH); shellcheck else runs from its pinned Docker image
#   ANDROID_HOME             the Android SDK (default: ~/Library/Android/sdk), with platform-tools and cmdline-tools
# Access: Gradle resolves SallaPush Android from Maven Central, and CocoaPods and Xcode fetch
# SallaApp/mobile-push-ios-sdk over HTTPS, with no account. ./gradlew runs on JAVA_HOME, else on java on PATH: a JDK 17.
set -euo pipefail

readonly STEPS="format analyze test pigeon api parity snippets pins tree shell pub swiftlint android ios ios-pods ios-mixed min-sdk smoke consumer"
readonly PORTABLE_STEPS="format analyze test pigeon api parity snippets pins tree shell pub android"
readonly COVERAGE_MIN=90
readonly SWIFTLINT_VERSION=0.63.2
readonly SHELLCHECK_VERSION=0.11.0
# The digest of koalaman/shellcheck:v0.11.0's image index, as the native SDKs pin it.
readonly SHELLCHECK_IMAGE=koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d
readonly GENERATED_FILES="lib/src/messages.g.dart ios/mobile_push/Sources/mobile_push/Messages.g.swift
android/src/main/kotlin/sa/salla/sallapush_flutter/Messages.g.kt"
# The files a build, the checks and a release need, and the scripts that CI and the docs run directly.
readonly REQUIRED_FILES="pubspec.yaml analysis_options.yaml README.md CHANGELOG.md LICENSE .gitignore .gitattributes
docs/SETUP.md docs/REFERENCE.md docs/TROUBLESHOOTING.md CONTRIBUTING.md RELEASING.md
.swiftlint.yml ../.github/workflows/flutter-ci.yml lib/mobile_push.dart pigeons/messages.dart
pigeons/copyright_header.txt
api/mobile_push.api tool/dump_api.dart tool/check_api_parity.dart tool/check_readme_snippets.dart
tool/check_coverage.dart tool/api-parity/mapping.json tool/api-parity/native-ios-API.txt
tool/api-parity/native-android-sallapush.api docs/snippets/Podfile scripts/common.sh scripts/add-nse-target.rb
ios/mobile_push.podspec ios/mobile_push/Package.swift android/build.gradle.kts android/consumer-rules.pro
example/pubspec.yaml example/ios/Runner.xcodeproj/project.pbxproj example/ios/Runner/AppDelegate.swift"
readonly EXECUTABLE_FILES="scripts/verify.sh scripts/bump-native.sh scripts/generate-pigeon.sh scripts/self-test.sh"
# The package's workflows, at the root of the repository, whose folder flutter/ holds the package: the tree step checks
# them with the package's files.
readonly WORKFLOWS="../.github/workflows/flutter-ci.yml ../.github/workflows/flutter-publish.yml"
readonly SMOKE_APP_ID=example_smoke
readonly EXAMPLE_PACKAGE=sa.salla.sallapush.flutter.example
readonly EXAMPLE_ACTIVITY=sa.salla.sallapush_flutter_example.MainActivity

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
  echo "usage: scripts/verify.sh [step...]   steps: $STEPS" >&2
  exit 2
}

require_macos() {
  [ "$(uname -s)" = Darwin ] || fail "this step needs macOS with Xcode"
}

flutter_tools() {
  resolve_flutter || fail "this step needs Flutter"
}

# The problems of the running step (each step runs in a subshell of its own).
problems=0
report() {
  problems=$((problems + 1))
  printf '%s\n' "$*"
}

# note <text>: added to the step's result in summary.tsv.
note() {
  printf '%s\n' "$*" >>"$work/note"
}

require_clean_tree() {
  [ -z "$(git -C "$root" status --porcelain -- .)" ] ||
    fail "this step builds the committed HEAD: commit or stash the changes first (git status)"
}

# The pinned SallaPush iOS version.
ios_pin() {
  sed -nE "s/^[[:space:]]*s\.dependency 'SallaPush', '([^']+)'.*/\1/p" "$root/ios/mobile_push.podspec"
}

# local_ios_sdk <app ios folder>: with VERIFY_IOS_SDK_CHECKOUT, a clean checkout of the pinned tag (common.sh
# ios_sdk_checkout), adds that local package to the app's Xcode project, so that it replaces the remote
# mobile-push-ios-sdk package; does nothing without it.
local_ios_sdk() {
  local ios="$1" checkout pin
  [ -n "${VERIFY_IOS_SDK_CHECKOUT:-}" ] || return 0
  pin="$(ios_pin)"
  checkout="$(ios_sdk_checkout "$pin")" || fail "VERIFY_IOS_SDK_CHECKOUT can't replace SallaPush iOS $pin"
  python3 - "$ios/Runner.xcodeproj/project.pbxproj" "$checkout" <<'PY'
import re, sys

path, checkout = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    text = handle.read()
reference = "5A11A9000000000000000001"
if reference not in text:
    group = re.search(r"mainGroup = ([0-9A-F]{24})", text)
    children = group and re.search(re.escape(group.group(1)) + r"(?: /\*[^*]*\*/)? = \{\s*isa = PBXGroup;\s*children = \(\n",
                                    text)
    anchor = "/* End PBXFileReference section */"
    if not children or anchor not in text:
        sys.exit(f"cannot find the main group of {path}")
    text = (text[:children.end()] + f"\t\t\t\t{reference} /* mobile-push-ios-sdk */,\n" + text[children.end():])
    text = text.replace(anchor, f'\t\t{reference} /* mobile-push-ios-sdk */ = {{isa = PBXFileReference; lastKnownFileType = '
                                f'wrapper; name = "mobile-push-ios-sdk"; path = "{checkout}"; sourceTree = "<absolute>"; }};\n'
                                + anchor, 1)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
PY
  echo "Swift Package Manager builds use SallaPush iOS $pin from $checkout: the tag $pin, commit" \
    "$(git -C "$checkout" rev-parse HEAD), with no changes (VERIFY_IOS_SDK_CHECKOUT)"
  note "SallaPush iOS from a clean checkout of its tag"
}

# on_exit <command>: runs the command when the step ends, whether it passes or fails, after those added later. Each
# step runs in a subshell of its own, so its exit actions run when the step ends.
exit_actions=""
on_exit() {
  exit_actions="$1${exit_actions:+; $exit_actions}"
  # shellcheck disable=SC2064 # the actions are fixed when they are added
  trap "$exit_actions" EXIT
}

# keep_example_project: restores the example's Xcode project when the step ends, as local_ios_sdk changes it.
keep_example_project() {
  local project="$root/example/ios/Runner.xcodeproj/project.pbxproj"
  cp -p "$project" "$work/example.pbxproj"
  on_exit "cp -p '$work/example.pbxproj' '$project'"
}

# readme_block <source>: the block of README.md that shows that snippet source.
readme_block() {
  (cd "$root" && "$DART" run tool/check_readme_snippets.dart --readme-block "$1")
}

# doc_block <file> <source>: the block of <file>, a .md file directly in docs/, that shows that snippet source.
doc_block() {
  (cd "$root" && "$DART" run tool/check_readme_snippets.dart --doc-block "$1" "$2")
}

# snippet <source>: a snippet source, a file or a region.
snippet() {
  (cd "$root" && "$DART" run tool/check_readme_snippets.dart --print "$1")
}

# fresh_app <folder> <platforms> <project name>: a new Flutter app from this Flutter's template.
fresh_app() {
  "$FLUTTER" create --platforms="$2" --org sa.salla.verify --project-name "$3" --no-pub "$1" >/dev/null
}

# pubspec_without_swiftpm <pubspec.yaml>: disables Swift Package Manager for the app.
pubspec_without_swiftpm() {
  python3 - "$1" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    lines = handle.read().split("\n")
index = lines.index("flutter:")
lines[index + 1:index + 1] = ["  config:", "    enable-swift-package-manager: false"]
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))
PY
}

# insert <file> <anchor regex> <before|after> <indent> <text file>: inserts the lines of <text file>, indented, before
# or after the first line that matches the anchor (the last one for before).
insert() {
  python3 - "$@" <<'PY'
import re, sys

path, anchor, where, indent, source = sys.argv[1:6]
with open(path, encoding="utf-8") as handle:
    lines = handle.read().split("\n")
with open(source, encoding="utf-8") as handle:
    added = [indent + line if line else line for line in handle.read().rstrip("\n").split("\n")]
matches = [index for index, line in enumerate(lines) if re.search(anchor, line)]
if not matches:
    sys.exit(f"{path} has no line that matches {anchor}")
position = matches[-1] if where == "before" else matches[0] + 1
lines[position:position] = added
with open(path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines))
PY
}

# ruby_with_xcodeproj <arguments...>: ruby with the xcodeproj gem, from the load path, else from the gem home of a
# Homebrew CocoaPods (its pod launcher sets GEM_HOME).
ruby_with_xcodeproj() {
  local pod gem_home
  if ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
    ruby "$@"
    return
  fi
  pod="$(command -v pod)" || fail "neither ruby's gems nor CocoaPods have the xcodeproj gem: install CocoaPods"
  gem_home="$(sed -nE 's/^GEM_HOME="([^"]+)".*/\1/p' "$pod")"
  [ -n "$gem_home" ] || fail "cannot find the gems of CocoaPods ($pod) for the xcodeproj gem"
  GEM_HOME="$gem_home" GEM_PATH="$gem_home" ruby "$@"
}

# manifest_meta_data <manifest.xml> <name>: the android:value of the application's meta-data <name>.
manifest_meta_data() {
  python3 - "$1" "$2" <<'PY'
import sys
import xml.etree.ElementTree as ElementTree

android = "{http://schemas.android.com/apk/res/android}"
for element in ElementTree.parse(sys.argv[1]).getroot().iter("meta-data"):
    if element.get(android + "name") == sys.argv[2]:
        print(element.get(android + "value", ""))
PY
}

# apk_manifest <apk>: the merged AndroidManifest.xml of an APK.
apk_manifest() {
  local apkanalyzer
  apkanalyzer="$(android_tool cmdline-tools/latest/bin/apkanalyzer apkanalyzer)" || exit 1
  "$apkanalyzer" manifest print "$1"
}

# android_smoke_configuration: the example's Android builds get the smoke app id, so that the app that runs on the
# emulator never uses a real app id.
android_smoke_configuration() {
  export ORG_GRADLE_PROJECT_sallapushAppId="$SMOKE_APP_ID"
}

# launch_release <adb> <serial> <apk>: installs the example's release build on the emulator, starts it, and fails when
# it crashes or stops within 15 s. The app is removed when the step ends.
launch_release() {
  local adb="$1" serial="$2" apk="$3" since pid
  "$adb" -s "$serial" uninstall "$EXAMPLE_PACKAGE" >/dev/null 2>&1 || true
  on_exit "'$adb' -s '$serial' uninstall '$EXAMPLE_PACKAGE' >/dev/null 2>&1 || true"
  "$adb" -s "$serial" install -r "$apk" >"$work/release-install.log" 2>&1 || true
  cat "$work/release-install.log"
  grep -q '^Success' "$work/release-install.log" ||
    fail "the release build could not be installed on $serial (free space on the device?)"
  since="$("$adb" -s "$serial" shell "date +'%m-%d %H:%M:%S.000'" | tr -d '\r')"
  "$adb" -s "$serial" shell am start -W -n "$EXAMPLE_PACKAGE/$EXAMPLE_ACTIVITY" || true
  sleep 15
  pid="$("$adb" -s "$serial" shell pidof "$EXAMPLE_PACKAGE" | tr -d '\r')" || pid=""
  "$adb" -s "$serial" logcat -d -b crash -T "$since" >"$work/release-crash.log" 2>&1 || true
  if [ -z "$pid" ] || grep -qF "Process: $EXAMPLE_PACKAGE," "$work/release-crash.log"; then
    cat "$work/release-crash.log"
    fail "the release build crashed or stopped within 15 s of its start on $serial; its crash log, if any, is above"
  fi
  echo "the release build started on $serial and still runs 15 s later (process $pid), without a crash"
}

# ---------------------------------------------------------------------------------------------------------------------
# Steps

step_format() {
  flutter_tools
  # The formatter's style follows each package's language version, which it reads from the resolved packages.
  (cd "$root" && "$FLUTTER" pub get)
  (cd "$root/example" && "$FLUTTER" pub get)
  (cd "$root" && "$DART" format --output=none --set-exit-if-changed lib test tool pigeons example/lib \
    example/integration_test example/test)
}

step_analyze() {
  flutter_tools
  (cd "$root" && "$FLUTTER" pub get)
  (cd "$root/example" && "$FLUTTER" pub get)
  (cd "$root" && "$FLUTTER" analyze)
  (cd "$root/example" && "$FLUTTER" analyze)
}

step_test() {
  flutter_tools
  rm -rf "$root/coverage"
  (cd "$root" && "$FLUTTER" test --coverage)
  (cd "$root" && "$DART" run tool/check_coverage.dart --min "$COVERAGE_MIN" coverage/lcov.info)
  (cd "$root/example" && "$FLUTTER" test)
}

step_pigeon() {
  flutter_tools
  "$scripts/generate-pigeon.sh"
  # shellcheck disable=SC2086 # the list of generated files
  git -C "$root" diff --exit-code -- $GENERATED_FILES ||
    fail "the generated code differs from what pigeons/messages.dart generates: run scripts/generate-pigeon.sh and commit it"
  echo "the generated code is pigeons/messages.dart's"
}

step_api() {
  flutter_tools
  (cd "$root" && "$DART" run tool/dump_api.dart --check)
}

step_parity() {
  flutter_tools
  (cd "$root" && "$DART" run tool/check_api_parity.dart)
}

step_snippets() {
  flutter_tools
  (cd "$root" && "$DART" run tool/check_readme_snippets.dart)
}

step_pins() { "$scripts/bump-native.sh" --check; }

step_tree() {
  local path pattern what fix hit file mode project root_bound example_bound
  # shellcheck disable=SC2086 # the package's workflows
  git -C "$root" ls-files -z --cached --others --exclude-standard -- . $WORKFLOWS >"$work/files" ||
    fail "cannot list the files of $root (git ls-files failed); run the verification in a clone of the repository"

  # Credentials and signing material, by name; macOS file systems ignore case.
  shopt -s nocasematch
  while IFS= read -r -d '' path; do
    case "${path##*/}" in
      google-services.json | googleservice-info.plist | *.p8 | *.p12 | *.jks | *.keystore | .env | .env.* | \
        local.properties | key.properties | *.mobileprovision)
        report "$path: a file of credentials or app configuration; never commit it"
        ;;
    esac
  done <"$work/files"
  shopt -u nocasematch

  # Secrets, personal paths, team ids and ticket keys, in every file a commit takes. The report names the file, never
  # the secret. Each pattern is written so that this file's own text never matches it.
  while IFS=$'\t' read -r pattern what fix; do
    # The paths are relative to the package's folder, wherever the script runs from.
    (cd "$root" && xargs -0 grep -lIE -e "$pattern" -- <"$work/files") >"$work/hits" 2>/dev/null || true
    while IFS= read -r hit; do
      report "$hit: holds $what; $fix"
    done <"$work/hits"
  done <<'PATTERNS'
gh[pousr]_[A-Za-z0-9]{36}	a GitHub token	remove it, and revoke it if it was ever pushed
githu[b]_pat_[A-Za-z0-9_]{20,}	a GitHub token	remove it, and revoke it if it was ever pushed
-----BEGI[N] [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----	a private key	remove it, and revoke it if it was ever pushed
---- BEGI[N] SSH2 ENCRYPTED PRIVATE KEY ----	a private key	remove it, and revoke it if it was ever pushed
PuTT[Y]-User-Key-File-[0-9]+:	a private key	remove it, and revoke it if it was ever pushed
x-access-toke[n]:[^$]	a token in a git URL	remove it, and revoke it if it was ever pushed
/User[s]/	a personal home path	use $HOME
(DEVELOPMENT_TEA[M]|DevelopmentTea[m]) = [A-Z0-9]{10}([;[:space:]]|$)	an Apple team id	set DEVELOPMENT_TEAM in the ignored example/ios/Flutter/SallaPush.xcconfig instead
\b(T[D]|S[P]|R[I]|SA[L]|S40[D])-[0-9]+\b	a ticket key	say what the change is instead: the code and docs are written for readers outside the organization
PATTERNS

  # The required files, and the scripts that run directly: executable, also in git.
  tr '\0' '\n' <"$work/files" >"$work/file-list"
  for file in $REQUIRED_FILES $EXECUTABLE_FILES; do
    if ! grep -qxF -- "$file" "$work/file-list" || [ -L "$root/$file" ] || [ ! -f "$root/$file" ]; then
      report "$file is missing from what a commit takes (absent, ignored, or not a regular file)"
    fi
  done
  for file in $EXECUTABLE_FILES; do
    [ -f "$root/$file" ] || continue
    [ -x "$root/$file" ] || report "$file is not executable (chmod +x $file)"
    mode="$(git -C "$root" ls-files --stage -- "$file" | cut -d ' ' -f 1)"
    case "$mode" in
      '' | 100755) ;;
      *) report "$file is staged with mode $mode; stage it as executable (git update-index --chmod=+x $file)" ;;
    esac
  done

  # Workflow actions: pinned to a full commit id; only local actions (./) are exempt.
  grep -E '^\.\./\.github/workflows/[^/]+\.ya?ml$' "$work/file-list" >"$work/workflows" || true
  while IFS= read -r file; do
    grep -nE '^[[:space:]]*(-[[:space:]]+)?uses:' "$root/$file" |
      sed -E "s/^([0-9]+):[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*['\"]?([^'\" #]+).*/\1 \3/" >"$work/uses" || true
    while read -r line reference; do
      [[ "$reference" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[^@]+)?@[0-9a-f]{40}$ ]] ||
        [[ "$reference" =~ ^\./ ]] ||
        report "$file:$line: uses $reference; pin the action to a full commit id (owner/repo@<40 hex> # vX.Y.Z)"
    done <"$work/uses"
  done <"$work/workflows"

  # The example's Swift files: Xcode compiles only those that the project lists, each in a target's Sources.
  project="$root/example/ios/Runner.xcodeproj/project.pbxproj"
  grep -E '^example/ios/(Runner|RunnerTests|SallaPushNotificationService)/[^/]+\.swift$' "$work/file-list" \
    >"$work/swift-files" || true
  while IFS= read -r file; do
    [ ! -f "$project" ] || grep -qF "/* ${file##*/} in Sources */" "$project" ||
      report "$file is in no Sources phase of example/ios/Runner.xcodeproj, so it is never compiled: add it to its target"
  done <"$work/swift-files"

  # The example resolves with the plugin's Dart SDK floor.
  root_bound="$(sed -nE 's/^[[:space:]]+sdk:[[:space:]]*["'\'']?(\^|>=)([0-9][0-9.]*).*/\2/p' "$root/pubspec.yaml" | head -n 1)"
  example_bound="$(sed -nE 's/^[[:space:]]+sdk:[[:space:]]*["'\'']?(\^|>=)([0-9][0-9.]*).*/\2/p' "$root/example/pubspec.yaml" | head -n 1)"
  [ -n "$root_bound" ] && [ "$root_bound" = "$example_bound" ] ||
    report "example/pubspec.yaml's environment sdk lower bound (${example_bound:-none}) is not pubspec.yaml's (${root_bound:-none})"

  [ "$problems" -eq 0 ] || fail "$problems problem(s) in what a commit takes"
  echo "$(tr -cd '\0' <"$work/files" | wc -c | tr -d ' ') files: no secret, credential file, personal path, team id or ticket key; every required file present and every script executable; every workflow action pinned; every Swift file of the example compiled; the example's Dart SDK bound is $root_bound"
}

step_shell() {
  local script shellcheck="${SHELLCHECK:-shellcheck}"
  for script in "$root"/scripts/*.sh; do
    bash -n "$script"
  done
  if command -v "$shellcheck" >/dev/null 2>&1 &&
    [ "$("$shellcheck" --version | sed -nE 's/^version: (.+)$/\1/p')" = "$SHELLCHECK_VERSION" ]; then
    (cd "$root" && "$shellcheck" -x -S style scripts/*.sh)
  elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    (cd "$root" && docker run --rm -v "$root:/mnt:ro" -w /mnt "$SHELLCHECK_IMAGE" -x -S style scripts/*.sh)
  else
    fail "shellcheck $SHELLCHECK_VERSION not found: install it (or set SHELLCHECK), or start Docker for $SHELLCHECK_IMAGE"
  fi
  echo "bash -n and shellcheck $SHELLCHECK_VERSION: scripts/*.sh"
  "$scripts/self-test.sh"
}

# The pub.dev archive, as flutter pub publish would upload it: pub's validation finds nothing to warn about, and
# .pubignore keeps the repository's own tooling and docs out. pub wants a clean git state, as a release has.
step_pub() {
  local code=0
  flutter_tools
  require_clean_tree
  (cd "$root" && "$FLUTTER" pub publish --dry-run) >"$work/pub.log" 2>&1 || code=$?
  cat "$work/pub.log"
  if [ "$code" -ne 0 ] || ! grep -qE '^Package has 0 warnings' "$work/pub.log"; then
    fail "flutter pub publish --dry-run found a problem (exit $code): fix each warning above"
  fi
  # The archive's files, from the tree that pub prints, in Unicode or ASCII glyphs.
  python3 - "$work/pub.log" <<'PY'
import re, sys

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next((index for index, line in enumerate(lines) if re.match(r"^Publishing \S+ \S+ to ", line)), None)
end = next((index for index, line in enumerate(lines) if line.startswith("Total compressed archive size")), None)
if start is None or end is None or end < start:
    sys.exit("flutter pub publish --dry-run printed no file list of the archive")
paths, stack = set(), []
for line in lines[start + 1:end]:
    match = re.match(r"^((?:[│|]   |    )*)(?:[├└]──|[+']--) (.+?)(?: \([^()]*\))?$", line)
    if match:
        stack[len(match.group(1)) // 4:] = [match.group(2)]
        paths.add("/".join(stack))
required = ["LICENSE", "README.md", "CHANGELOG.md", "pubspec.yaml", "lib/mobile_push.dart",
            "ios/mobile_push.podspec", "android/build.gradle.kts", "example/pubspec.yaml"]
left_out = ["api", "docs", "pigeons", "scripts", "test/tool", "tool", "CONTRIBUTING.md", "RELEASING.md"]
problems = [f"the archive has no {path}" for path in required if path not in paths]
problems += [f"the archive holds {path}: .pubignore must keep it out" for path in left_out if path in paths]
if problems:
    sys.exit("\n".join(problems))
print(f"the archive: {len(paths)} files and folders; the package, its example, LICENSE, README.md and CHANGELOG.md, "
      f"without {', '.join(left_out)}")
PY
  echo "flutter pub publish --dry-run: no warning"
}

step_swiftlint() {
  local swiftlint="${SWIFTLINT:-swiftlint}" version
  command -v "$swiftlint" >/dev/null 2>&1 || fail "SwiftLint not found: install $SWIFTLINT_VERSION, or set SWIFTLINT"
  version="$("$swiftlint" version)"
  [ "$version" = "$SWIFTLINT_VERSION" ] || fail "SwiftLint $version found; the rules are pinned to $SWIFTLINT_VERSION"
  (cd "$root" && "$swiftlint" lint --strict --quiet --config .swiftlint.yml)
  echo "SwiftLint $SWIFTLINT_VERSION: no violation"
}

step_android() {
  local results="$root/example/build/mobile_push/test-results/testDebugUnitTest" adb="" serial=""
  local mapping="$root/example/build/app/outputs/mapping/release"
  local apk="$root/example/build/app/outputs/flutter-apk/app-release.apk"
  flutter_tools
  if [ "${VERIFY_ANDROID_NO_EMULATOR:-}" = 1 ]; then
    echo "VERIFY_ANDROID_NO_EMULATOR=1: every check but the release build's run on an emulator"
    note "without the emulator run (VERIFY_ANDROID_NO_EMULATOR)"
  else
    adb="$(android_tool platform-tools/adb adb)" || fail "no adb"
    serial="$(emulator_serial "$adb")" || fail "no emulator"
  fi
  (cd "$root/example" && "$FLUTTER" build apk --config-only)
  rm -rf "$results"
  (cd "$root/example/android" && ./gradlew --no-daemon :mobile_push:testDebugUnitTest :mobile_push:lintDebug)
  assert_tests_ran "$results"
  # Flutter shrinks every release build with R8. The example has no rule of its own, so the libraries' consumer rules,
  # the plugin's included, must keep everything the app needs at run time.
  android_smoke_configuration
  rm -rf "$mapping"
  (cd "$root/example" && "$FLUTTER" build apk --release)
  [ -s "$mapping/mapping.txt" ] || fail "R8 did not shrink the release build ($mapping/mapping.txt is missing)"
  apk_manifest "$apk" >"$work/manifest.xml"
  python3 - "$work/manifest.xml" <<'PY'
import sys
import xml.etree.ElementTree as ElementTree

android = "{http://schemas.android.com/apk/res/android}"
application = ElementTree.parse(sys.argv[1]).getroot().find("application")
providers = {element.get(android + "name"): int(element.get(android + "initOrder", "0"))
             for element in application.iter("provider")}
init = providers.get("sa.salla.sallapush_flutter.SallaPushInitProvider")
problems = []
if init is None:
    problems.append("SallaPushInitProvider is not in the merged manifest")
elif init != -1:
    problems.append(f"SallaPushInitProvider has initOrder {init}, not -1")
for name, label in (("com.google.firebase.provider.FirebaseInitProvider", "FirebaseInitProvider"),
                    ("androidx.startup.InitializationProvider", "androidx.startup's InitializationProvider")):
    if name in providers:
        if init is not None and providers[name] <= init:
            problems.append(f"{label} (initOrder {providers[name]}) runs after SallaPushInitProvider ({init})")
        else:
            print(f"{label}: initOrder {providers[name]}, before SallaPushInitProvider ({init})")
service = next((element for element in application.iter("service")
                if element.get(android + "name") == "com.salla.push.SallaPushFirebaseMessagingService"), None)
priorities = [filter_.get(android + "priority") for filter_ in service.iter("intent-filter")] if service is not None else []
if priorities != ["-450"]:
    problems.append(f"SallaPush's FCM service has the priorities {priorities}, not [-450]")
else:
    print("SallaPushFirebaseMessagingService: priority -450")
if problems:
    sys.exit("\n".join(problems))
print("SallaPushInitProvider: initOrder -1")
PY
  [ -z "$serial" ] || launch_release "$adb" "$serial" "$apk"
}

step_ios() {
  local udid
  require_macos
  flutter_tools
  udid="$(simulator_udid "$work")" || fail "no simulator"
  keep_example_project
  local_ios_sdk "$root/example/ios"
  (cd "$root/example" && "$FLUTTER" build ios --config-only)
  (cd "$root/example" && "$FLUTTER" build ios --simulator --no-codesign)
  # Parallel testing clones the simulator and shuts the original down.
  (cd "$root" && xcodebuild test -quiet -workspace example/ios/Runner.xcworkspace -scheme Runner \
    -destination "id=$udid" -only-testing:RunnerTests -parallel-testing-enabled NO \
    -resultBundlePath "$work/RunnerTests.xcresult")
  xcrun xcresulttool get test-results summary --path "$work/RunnerTests.xcresult" --compact >"$work/RunnerTests.json"
  python3 - "$work/RunnerTests.json" "$udid" <<'PY'
import json, sys

summary = json.load(open(sys.argv[1]))
passed, total = summary.get("passedTests", 0), summary.get("totalTestCount", 0)
if not passed:
    sys.exit(f"RunnerTests: no test passed ({total} in the results)")
print(f"the example, its extension and ReadmeSnippets.swift build; RunnerTests on {sys.argv[2]}: {passed} of {total} "
      f"passed, {summary.get('skippedTests', 0)} skipped")
PY
}

step_ios_pods() {
  local app="$work/pods_app" ios_pin_version
  require_macos
  flutter_tools
  fresh_app "$app" ios pods_app
  pubspec_without_swiftpm "$app/pubspec.yaml"
  (cd "$app" && "$FLUTTER" pub add "mobile_push:{\"path\":\"$root\"}")
  readme_block example/ios/Runner/AppDelegate.swift#appdelegate >"$app/ios/Runner/AppDelegate.swift"
  # The setup guide's AppDelegate methods for other push SDKs, in the README's AppDelegate: they reach SallaPush
  # through the plugin's re-export.
  doc_block docs/SETUP.md example/ios/Runner/ReadmeSnippets.swift#other-push-sdks >"$work/other-push-sdks"
  insert "$app/ios/Runner/AppDelegate.swift" '^}$' before "  " "$work/other-push-sdks"
  [ -f "$app/ios/Podfile" ] ||
    cp "$(dirname "$FLUTTER")/../packages/flutter_tools/templates/cocoapods/Podfile-ios" "$app/ios/Podfile"
  snippet docs/snippets/Podfile#podfile-app >"$work/podfile-app"
  snippet docs/snippets/Podfile#podfile-extension >"$work/podfile-extension"
  insert "$app/ios/Podfile" "^  use_frameworks!$" after "  " "$work/podfile-app"
  printf '\n' >>"$app/ios/Podfile"
  cat "$work/podfile-extension" >>"$app/ios/Podfile"
  ruby_with_xcodeproj "$scripts/add-nse-target.rb" "$app/ios" "$root/example/ios/SallaPushNotificationService"
  (cd "$app" && "$FLUTTER" build ios --simulator --no-codesign)
  ios_pin_version="$(ios_pin)"
  grep -qE "^  - SallaPushExtension \($ios_pin_version\)" "$app/ios/Podfile.lock" ||
    fail "Podfile.lock has no SallaPushExtension $ios_pin_version"
  [ -d "$app/build/ios/iphonesimulator/Runner.app/PlugIns/SallaPushNotificationService.appex" ] ||
    fail "Runner.app does not embed SallaPushNotificationService.appex"
  if [ -e "$app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift" ] &&
    grep -q mobile_push "$app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"; then
    fail "mobile_push came through Swift Package Manager, which pubspec.yaml disabled"
  fi
  echo "CocoaPods mode: the app, with the setup guide's methods for other push SDKs, and its extension build with the SallaPush pods $ios_pin_version"
}

step_ios_mixed() {
  local app="$work/mixed_app" plugin="$work/pods_only_plugin" package
  require_macos
  flutter_tools
  "$FLUTTER" create --template=plugin --platforms=ios --org sa.salla.verify --project-name pods_only_plugin --no-pub \
    "$plugin" >/dev/null
  rm -f "$plugin/ios/pods_only_plugin/Package.swift"
  fresh_app "$app" ios mixed_app
  (cd "$app" && "$FLUTTER" pub add "mobile_push:{\"path\":\"$root\"}" "pods_only_plugin:{\"path\":\"$plugin\"}")
  local_ios_sdk "$app/ios"
  (cd "$app" && "$FLUTTER" build ios --simulator --no-codesign)
  package="$app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
  grep -q mobile_push "$package" || fail "$package does not list mobile_push"
  grep -q pods_only_plugin "$app/ios/Podfile.lock" || fail "the CocoaPods-only plugin is not in Podfile.lock"
  ! grep -qiE 'sallapush' "$app/ios/Podfile.lock" || fail "Podfile.lock holds a SallaPush pod: SallaPush would link twice"
  echo "Swift Package Manager with a CocoaPods-only plugin: mobile_push through Swift Package Manager, no SallaPush pod"
}

step_min_sdk() {
  local tree="$work/min-sdk" folder package
  require_macos
  flutter_tools
  [ -n "${FLUTTER_MIN:-}" ] || fail "set FLUTTER_MIN to the flutter binary of Flutter 3.44.x"
  [ -x "$FLUTTER_MIN" ] || fail "FLUTTER_MIN=$FLUTTER_MIN is not executable"
  require_clean_tree
  git -C "$root" worktree add --detach "$tree" HEAD >/dev/null
  on_exit "git -C '$root' worktree remove --force '$tree'"
  # The worktree holds the whole repository: the package is its folder flutter/.
  folder="$(git -C "$root" rev-parse --show-prefix)"
  package="$tree/${folder%/}"
  "$FLUTTER_MIN" --version
  (cd "$package" && "$FLUTTER_MIN" pub get)
  (cd "$package/example" && "$FLUTTER_MIN" pub get)
  (cd "$package" && "$FLUTTER_MIN" analyze)
  (cd "$package" && "$FLUTTER_MIN" test)
  (cd "$package/example" && "$FLUTTER_MIN" test)
  (cd "$package/example" && "$FLUTTER_MIN" build apk --debug)
  local_ios_sdk "$package/example/ios"
  (cd "$package/example" && "$FLUTTER_MIN" build ios --simulator --no-codesign)
  echo "Flutter $("$FLUTTER_MIN" --version --machine | python3 -c 'import json, sys; print(json.load(sys.stdin)["frameworkVersion"])'): pub get, analyze, test and both builds of the example pass"
}

# smoke_platform <device> <name>: the example's integration tests on <device>, then, with SMOKE_HOT_RESTART=1, the
# hot-restart check. A skipped case is reported as skipped, never as passed.
smoke_platform() {
  local device="$1" name="$2" log="$work/smoke-$2.log" skipped
  (cd "$root/example" && "$FLUTTER" test integration_test -d "$device") 2>&1 | tee "$log"
  skipped="$(sed -nE 's/.*~([0-9]+): All tests passed.*/\1/p' "$log" | tail -n 1)"
  if [ -n "$skipped" ]; then
    note "$name: $skipped skipped"
    echo "SKIPPED on $name ($skipped), with the reasons the tests give:"
    grep -E '^  [^ 0-9]' "$log" || true
  fi
  [ "${SMOKE_HOT_RESTART:-}" != 1 ] || hot_restart "$device" "$name"
}

# hot_restart <device> <name>: flutter run --machine of integration_test/hot_restart_probe.dart; one will-display
# event at its start, a hot restart through the machine protocol, and exactly one will-display event after it.
hot_restart() {
  python3 -u - "$FLUTTER" "$1" "$root/example" <<'PY'
import json, queue, subprocess, sys, threading, time

flutter, device, example = sys.argv[1:4]
process = subprocess.Popen([flutter, "run", "--machine", "-d", device, "-t", "integration_test/hot_restart_probe.dart"],
                           cwd=example, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True)
lines = queue.Queue()
state = {"app": None, "started": False, "restarting": False, "restart": None, "before": 0, "after": 0}


def read():
    for line in process.stdout:
        lines.put(line)
    lines.put(None)


# The app's output: app.log messages, and plain lines for what it prints before flutter run attaches to it (iOS).
def log(text):
    print(text)
    if "SALLAPUSH_HOT_RESTART will-display" in text:
        state["after" if state["restarting"] else "before"] += 1


def handle(message):
    params = message.get("params") or {}
    if message.get("event") == "app.start":
        state["app"] = params.get("appId")
    elif message.get("event") == "app.started":
        state["started"] = True
    elif message.get("event") == "app.log":
        log(params.get("log", ""))
    elif message.get("id") == 1:
        state["restart"] = message


# Reads flutter run's messages until condition() holds; fails after <seconds> when <missing> names what is awaited.
def pump(condition, seconds, missing=None):
    deadline = time.monotonic() + seconds
    while not condition():
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            if missing:
                sys.exit(f"hot restart: no {missing} within {seconds} s")
            return
        try:
            line = lines.get(timeout=remaining)
        except queue.Empty:
            continue
        if line is None:
            sys.exit(f"hot restart: flutter run ended early ({missing or 'while collecting events'})")
        line = line.strip()
        if line.startswith("[{") and line.endswith("}]"):
            for message in json.loads(line):
                handle(message)
        elif line:
            log(line)


def send(identifier, method, params):
    process.stdin.write(json.dumps([{"id": identifier, "method": method, "params": params}]) + "\n")
    process.stdin.flush()


threading.Thread(target=read, daemon=True).start()
try:
    pump(lambda: state["started"], 900, "start of the app")
    pump(lambda: state["before"] > 0, 60, "will-display event before the restart")
    state["restarting"] = True
    send(1, "app.restart", {"appId": state["app"], "fullRestart": True, "pause": False, "reason": "verify.sh smoke"})
    pump(lambda: state["restart"] is not None, 180, "answer to the restart")
    if (state["restart"].get("result") or {}).get("code") != 0:
        sys.exit(f"hot restart: the restart failed: {state['restart']}")
    pump(lambda: state["after"] > 0, 60, "will-display event after the restart")
    # A second event within 5 s would be a doubled listener.
    pump(lambda: False, 5)
    if state["before"] != 1 or state["after"] != 1:
        sys.exit(f"hot restart: {state['before']} will-display event(s) before the restart and {state['after']} after "
                 "it, not one each")
    print("hot restart: one will-display event before the restart, and exactly one after it")
finally:
    if process.poll() is None:
        if state["app"]:
            send(2, "app.stop", {"appId": state["app"]})
        try:
            process.wait(timeout=60)
        except subprocess.TimeoutExpired:
            process.kill()
PY
  note "$2: hot restart checked"
}

step_smoke() {
  local udid serial adb abi platform apk free_kb apk_kb xcconfig="$root/example/ios/Flutter/SallaPush.smoke.xcconfig"
  require_macos
  flutter_tools
  udid="$(simulator_udid "$work")" || fail "no simulator"
  adb="$(android_tool platform-tools/adb adb)" || fail "no adb"
  serial="$(emulator_serial "$adb")" || fail "no emulator"

  # iOS: the smoke configuration, through the xcconfig that the example includes when it exists.
  keep_example_project
  on_exit "rm -f '$xcconfig'"
  cat >"$xcconfig" <<'EOF'
SALLAPUSH_APP_ID = example_smoke
EOF
  local_ios_sdk "$root/example/ios"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  if command -v applesimutils >/dev/null 2>&1; then
    applesimutils --byId "$udid" --bundle "$EXAMPLE_PACKAGE" --setPermissions notifications=YES ||
      echo "applesimutils could not allow notifications: the permission case may be skipped"
  fi
  smoke_platform "$udid" ios

  # Android: the smoke configuration, through Gradle properties. The app is installed first, built as flutter test
  # builds it for this device, so that the notification permission can be granted; flutter test's reinstall keeps it.
  # That takes room for two copies of the app above Android's storage reserve (500 MB at most). An emulator with less
  # room gets one install, from flutter test, without the grant, and the permission case reports SKIPPED.
  android_smoke_configuration
  abi="$("$adb" -s "$serial" shell getprop ro.product.cpu.abi | tr -d '\r')"
  case "$abi" in
    arm64-v8a) platform=android-arm64 ;;
    x86_64) platform=android-x64 ;;
    armeabi-v7a) platform=android-arm ;;
    *) fail "the emulator's ABI '$abi' is not one that Flutter builds for" ;;
  esac
  (cd "$root/example" && "$FLUTTER" build apk --debug --target-platform "$platform")
  apk="$root/example/build/app/outputs/flutter-apk/app-debug.apk"
  "$adb" -s "$serial" uninstall "$EXAMPLE_PACKAGE" >/dev/null 2>&1 || true
  free_kb="$("$adb" -s "$serial" shell df /data | awk 'END { print $4 }' | tr -d '\r')"
  apk_kb=$(($(wc -c <"$apk") / 1024))
  if [ "${free_kb:-0}" -ge $((2 * apk_kb + 512000)) ] 2>/dev/null; then
    "$adb" -s "$serial" install -t -r "$apk" >"$work/install.log" 2>&1 || true
    cat "$work/install.log"
    grep -q '^Success' "$work/install.log" || fail "the example could not be installed on $serial (free space on the device?)"
    "$adb" -s "$serial" shell pm grant "$EXAMPLE_PACKAGE" android.permission.POST_NOTIFICATIONS ||
      echo "the notification permission could not be granted: the permission case may be skipped"
  else
    echo "$serial has $((${free_kb:-0} / 1024)) MB free, too little for two copies of the example: flutter test installs it once, without the notification permission"
    note "android: no room to grant the notification permission beforehand"
  fi
  smoke_platform "$serial" android
}

step_consumer() {
  local app="$work/consumer_app" sha repository folder ios_id android_id built
  require_macos
  flutter_tools
  require_clean_tree
  sha="$(git -C "$root" rev-parse HEAD)"
  # As the README's git dependency: the repository, and the package's folder flutter/ in it.
  repository="$(git -C "$root" rev-parse --show-toplevel)"
  folder="$(git -C "$root" rev-parse --show-prefix)"
  fresh_app "$app" android,ios consumer_app
  (cd "$app" && "$FLUTTER" pub add \
    "mobile_push:{\"git\":{\"url\":\"file://$repository\",\"ref\":\"$sha\",\"path\":\"${folder%/}\"}}")

  # Only what the README shows, and the notification icon it links.
  readme_block example/ios/Runner/AppDelegate.swift#appdelegate >"$app/ios/Runner/AppDelegate.swift"
  grep -qF 'SallaPushFlutter.start()' "$app/ios/Runner/AppDelegate.swift" ||
    fail "the README's AppDelegate has no SallaPushFlutter.start()"
  readme_block example/ios/Runner/Info.plist#app-id >"$work/info-plist"
  insert "$app/ios/Runner/Info.plist" '^</dict>$' before $'\t' "$work/info-plist"
  readme_block docs/snippets/app-id.xcconfig >"$work/app-id.xcconfig"
  cat "$work/app-id.xcconfig" >>"$app/ios/Flutter/Debug.xcconfig"
  cat "$work/app-id.xcconfig" >>"$app/ios/Flutter/Release.xcconfig"
  readme_block example/android/app/src/main/AndroidManifest.xml#meta-data >"$work/meta-data"
  insert "$app/android/app/src/main/AndroidManifest.xml" '^    </application>$' before "        " "$work/meta-data"
  readme_block docs/snippets/build.gradle.kts#app-id >"$work/placeholder"
  insert "$app/android/app/build.gradle.kts" '^    defaultConfig \{$' after "        " "$work/placeholder"
  # The README links the example's notification icon for the app to copy.
  grep -qF '(example/android/app/src/main/res/drawable/ic_stat_sallapush.xml)' "$root/README.md" ||
    fail "the README links no notification icon"
  mkdir -p "$app/android/app/src/main/res/drawable"
  snippet example/android/app/src/main/res/drawable/ic_stat_sallapush.xml \
    >"$app/android/app/src/main/res/drawable/ic_stat_sallapush.xml"
  ios_id="$(sed -nE 's/^SALLAPUSH_APP_ID = (.+)$/\1/p' "$work/app-id.xcconfig")"
  android_id="$(sed -nE 's/.*manifestPlaceholders\["sallaPushAppId"\] = "([^"]+)".*/\1/p' "$work/placeholder")"

  (cd "$app" && "$FLUTTER" build apk --debug)
  apk_manifest "$app/build/app/outputs/flutter-apk/app-debug.apk" >"$work/consumer-manifest.xml"
  built="$(manifest_meta_data "$work/consumer-manifest.xml" com.salla.push.APP_ID)"
  [ -n "$android_id" ] && [ "$built" = "$android_id" ] ||
    fail "the Android app's com.salla.push.APP_ID is '$built', not the README's '$android_id'"
  local_ios_sdk "$app/ios"
  (cd "$app" && "$FLUTTER" build ios --simulator --no-codesign)
  built="$(/usr/libexec/PlistBuddy -c 'Print :SallaPushAppId' "$app/build/ios/iphonesimulator/Runner.app/Info.plist")"
  [ -n "$ios_id" ] && [ "$built" = "$ios_id" ] ||
    fail "the iOS app's SallaPushAppId is '$built', not the README's '$ios_id'"
  echo "a fresh app with mobile_push from git ($sha) and only the README's setup builds for Android ($android_id) and iOS ($ios_id)"
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
  case " $PORTABLE_STEPS " in
    *" $step "*) ;;
    *) require_macos ;;
  esac
done

logs="${VERIFY_LOG_DIR:-$work/logs}"
mkdir -p "$logs"
summary="$logs/summary.tsv"
# The commit this run verifies, +dirty when flutter/ has changes. summary.tsv holds the runs of one commit, named in its
# first line and in every row, so a summary can't present another commit's results.
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
  printf '# %s %s\nstep\tresult\tseconds\tcommit\n' "$commit" "$state" >"$summary"
fi
grouped=false
[ "${GITHUB_ACTIONS:-}" != true ] || [ "$steps" = "${steps%% *}" ] || grouped=true

for step in $steps; do
  function_name="step_$(printf '%s' "$step" | tr - _)"
  log="$logs/$step.log"
  rm -f "$work/note"
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
  result=passed
  [ ! -s "$work/note" ] || result="passed ($(paste -sd ';' "$work/note" | sed 's/;/; /g'))"
  if [ "$status" -ne 0 ]; then
    printf '%s\tfailed\t%s\t%s\n' "$step" "$seconds" "$revision" >>"$summary"
    # Without VERIFY_LOG_DIR the logs live in the temporary directory, which is removed on exit.
    fail "$step failed (exit $status) after ${seconds}s${VERIFY_LOG_DIR:+; log: $log}"
  fi
  printf '%s\t%s\t%s\t%s\n' "$step" "$result" "$seconds" "$revision" >>"$summary"
  echo "==> verify.sh $step: $result in ${seconds}s"
done
echo "verify.sh: all passed ($steps)"
