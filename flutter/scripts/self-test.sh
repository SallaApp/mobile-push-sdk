#!/usr/bin/env bash
# Tests of this repository's own tooling, each in a throwaway copy under a temporary directory:
#   - scripts/common.sh's tool resolution, with FLUTTER set and unset;
#   - scripts/common.sh's check of VERIFY_IOS_SDK_CHECKOUT, on a scratch clone of a SallaPush iOS release;
#   - scripts/bump-native.sh: --check, each refusal, and a bump against a stand-in for gh;
#   - scripts/verify.sh tree, with each refusal, on copies of the package's files and workflows;
#   - scripts/verify.sh pub, against a stand-in for flutter pub publish --dry-run;
#   - scripts/verify.sh android without an emulator, against stand-ins for flutter, Gradle, apkanalyzer and adb;
#   - scripts/verify.sh's summary.tsv: the commit it names, and its refusal of another commit's runs.
# It needs bash, git and python3, no Flutter, and never touches this repository. The scratch repositories use an
# isolated git configuration (HOME, no global or system config) and are never signed or pushed; only the summary and pub
# cases and the scratch SallaPush iOS clone commit, each in a scratch repository of its own.
#
#   scripts/self-test.sh
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$scripts/.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/sallapush-self-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

# Scratch git: no global or system configuration (git before 2.32 ignores GIT_CONFIG_GLOBAL, hence HOME).
mkdir -p "$work/home"
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE FLUTTER DART FLUTTER_MIN
# The runs of verify.sh in the scratch copies keep their logs to themselves.
unset VERIFY_LOG_DIR VERIFY_SIMULATOR_UDID VERIFY_EMULATOR_SERIAL VERIFY_IOS_SDK_CHECKOUT VERIFY_ANDROID_NO_EMULATOR

# PATH without any Flutter, so that no case reaches a real one.
clean_path=""
IFS=: read -r -a entries <<<"$PATH"
for entry in "${entries[@]}"; do
  [ -n "$entry" ] && [ ! -x "$entry/flutter" ] || continue
  clean_path="${clean_path:+$clean_path:}$entry"
done

passed=0
failed=0
out="$work/out"

section() { printf '\n== %s\n' "$1"; }

# check <label> <ok|fails> <command...>: runs the command, its output into $out, and expects it to pass or fail.
check() {
  local label="$1" want="$2" status=0
  shift 2
  "$@" >"$out" 2>&1 || status=$?
  if { [ "$want" = ok ] && [ "$status" -eq 0 ]; } || { [ "$want" = fails ] && [ "$status" -ne 0 ]; }; then
    passed=$((passed + 1))
    echo "ok   $label"
  else
    failed=$((failed + 1))
    echo "FAIL $label (exit $status, expected $want)"
    sed 's/^/       /' "$out"
  fi
}

# says <label> <text>: a line of the last check's output holds the text.
says() {
  if grep -qF -- "$2" "$out"; then
    passed=$((passed + 1))
    echo "ok   $1"
  else
    failed=$((failed + 1))
    echo "FAIL $1: the output does not say '$2'"
    sed 's/^/       /' "$out"
  fi
}

# ---------------------------------------------------------------------------------------------------------------------
# common.sh: resolve_flutter

test_resolve_flutter() {
  local sdk="$work/flutter-sdk/bin" lonely="$work/lonely/bin" resolve="$work/resolve.sh"
  section "common.sh resolve_flutter"
  mkdir -p "$sdk" "$lonely"
  printf '#!/bin/sh\n' >"$sdk/flutter"
  printf '#!/bin/sh\n' >"$sdk/dart"
  printf '#!/bin/sh\n' >"$lonely/flutter"
  chmod +x "$sdk/flutter" "$sdk/dart" "$lonely/flutter"
  # Sources common.sh as the scripts do, and prints what resolve_flutter set.
  cat >"$resolve" <<EOF
#!/usr/bin/env bash
set -euo pipefail
. "$scripts/common.sh"
resolve_flutter
echo "FLUTTER=\$FLUTTER DART=\$DART"
EOF

  check "FLUTTER set: that flutter, and the dart next to it" ok env PATH="$clean_path" FLUTTER="$sdk/flutter" bash "$resolve"
  says "it names both" "FLUTTER=$sdk/flutter DART=$sdk/dart"
  check "FLUTTER unset: flutter on PATH" ok env PATH="$sdk:$clean_path" bash "$resolve"
  says "it finds it" "FLUTTER=$sdk/flutter DART=$sdk/dart"
  check "FLUTTER=flutter: the flutter that PATH finds" ok env PATH="$sdk:$clean_path" FLUTTER=flutter bash "$resolve"
  says "it resolves the name" "FLUTTER=$sdk/flutter"
  check "FLUTTER unset and none on PATH: refused" fails env PATH="$clean_path" bash "$resolve"
  says "it says what to set" "Flutter not found: set FLUTTER"
  check "a flutter without dart next to it: refused" fails env PATH="$clean_path" FLUTTER="$lonely/flutter" bash "$resolve"
  says "it says why" "FLUTTER must be the bin/flutter of a Flutter SDK"
  check "a FLUTTER that is no executable: refused" fails env PATH="$clean_path" FLUTTER="$work/missing/flutter" bash "$resolve"
  says "it names it" "is not an executable flutter binary"
}

# ---------------------------------------------------------------------------------------------------------------------
# common.sh: ios_sdk_checkout, the check before a local clone replaces the remote SallaPush iOS package

test_ios_sdk_checkout() {
  local clone="$work/ios-sdk/mobile-push-ios-sdk" copy="$work/ios-sdk/copy/mobile-push-ios-sdk" version
  local file=Sources/SallaPushCore/SallaPushVersion.swift script="$work/ios-sdk-checkout.sh"
  section "common.sh ios_sdk_checkout (VERIFY_IOS_SDK_CHECKOUT)"
  version="$(sed -nE "s/^[[:space:]]*s\.dependency 'SallaPush', '([^']+)'.*/\1/p" "$root/ios/mobile_push.podspec")"
  cat >"$script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
. "$scripts/common.sh"
ios_sdk_checkout "$version"
EOF
  checkout_of() { env VERIFY_IOS_SDK_CHECKOUT="$1" bash "$script"; }
  in_clone() { git -C "$clone" -c user.name=self-test -c user.email=self-test@example.invalid "$@"; }
  # A scratch SallaPush iOS: its version file, committed and tagged as the native SDK tags a release.
  mkdir -p "$clone/${file%/*}"
  printf 'package let sallaPushSDKVersion = "%s"\n' "$version" >"$clone/$file"
  in_clone init -q
  in_clone add -A
  in_clone commit -q -m "SallaPush iOS $version"
  in_clone tag -a -m "SallaPush iOS $version" "$version"

  check "a clean clone at the pinned tag passes" ok checkout_of "$clone"
  says "it prints the clone's path" "$(cd "$clone" && pwd -P)"
  printf '// A local change.\n' >>"$clone/$file"
  check "a change to a file of the tag is refused" fails checkout_of "$clone"
  says "it says why" "VERIFY_IOS_SDK_CHECKOUT has changes, so it is not SallaPush iOS $version exactly"
  in_clone checkout -q -- "$file"
  printf 'let added = 1\n' >"$clone/${file%/*}/Added.swift"
  check "a file that the tag does not have is refused" fails checkout_of "$clone"
  says "it says why" "VERIFY_IOS_SDK_CHECKOUT has changes"
  in_clone add -A
  in_clone commit -q -m "a commit after the release, at the same version"
  check "a later commit with the same version is refused" fails checkout_of "$clone"
  says "it says which tag to check out" "VERIFY_IOS_SDK_CHECKOUT is not at the tag $version"
  in_clone checkout -q "$version"
  check "  ... and passes once the tag is checked out" ok checkout_of "$clone"
  mkdir -p "${copy%/*}"
  cp -R "$clone" "$copy"
  rm -rf "${copy:?}/.git"
  check "a copy of the release that is no git clone is refused" fails checkout_of "$copy"
  says "it says why" "VERIFY_IOS_SDK_CHECKOUT is not a git clone"
  in_clone tag -d "$version" >/dev/null
  check "a clone without the pinned tag is refused" fails checkout_of "$clone"
  says "it names the tag" "VERIFY_IOS_SDK_CHECKOUT has no tag $version"
  printf 'package let sallaPushSDKVersion = "0.0.0"\n' >"$clone/$file"
  in_clone commit -q -a -m "another version"
  in_clone tag -a -m "SallaPush iOS $version" "$version"
  check "a tag of another version is refused" fails checkout_of "$clone"
  says "it names the version" "VERIFY_IOS_SDK_CHECKOUT is not SallaPush iOS $version"
  mv "$clone" "$work/ios-sdk/mobile-push"
  check "a folder with another name is refused" fails checkout_of "$work/ios-sdk/mobile-push"
  says "it says why" "VERIFY_IOS_SDK_CHECKOUT must be a folder named mobile-push-ios-sdk"
  check "a folder that does not exist is refused" fails checkout_of "$clone"
  says "it names it" "VERIFY_IOS_SDK_CHECKOUT=$clone does not exist"
}

# ---------------------------------------------------------------------------------------------------------------------
# A copy of the package's files (what a commit would take) and of its workflows, laid out as in this repository: the
# package in the folder flutter/ of a scratch repository with everything staged, the workflows at its root. Each case
# changes a fresh copy, in its flutter/.

pristine="$work/pristine"
repository="$work/repository"
case="$repository/flutter"
make_pristine() {
  local name
  mkdir -p "$pristine/flutter"
  git -C "$root" ls-files -z --cached --others --exclude-standard -- . ../.github/workflows/flutter-ci.yml \
    ../.github/workflows/flutter-publish.yml >"$work/files"
  while IFS= read -r -d '' name; do
    [ -e "$root/$name" ] || continue
    mkdir -p "$pristine/flutter/$(dirname "$name")"
    cp -p "$root/$name" "$pristine/flutter/$name"
  done <"$work/files"
  git -C "$pristine" init -q
  git -C "$pristine" add -A
}

fresh() {
  rm -rf "${repository:?}"
  cp -Rp "$pristine" "$repository"
}

# edit <file> <old> <new>: replaces the first <old> in the copy's <file>; stops the self-test when <old> is missing.
edit() {
  python3 - "$case/$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1:4]
with open(path, encoding="utf-8") as handle:
    text = handle.read()
if old not in text:
    sys.exit(f"self-test.sh: {path} does not contain {old!r}; update the case")
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------------------------------------------------
# bump-native.sh

test_bump_native() {
  local bin="$work/bin-gh" version pinned target later
  section "bump-native.sh"
  mkdir -p "$bin"
  # Stands in for gh api: repos/<owner>/<repo> answers for SallaApp's native repositories; git/ref/tags/<tag> for the
  # tags in FAKE_TAGS; contents/<path>?ref=<tag> serves a stand-in API file that names the repository and the tag.
  cat >"$bin/gh" <<'EOF'
#!/usr/bin/env bash
path=""
for argument; do
  case "$argument" in repos/*) path="$argument" ;; esac
done
case "$path" in
  repos/SallaApp/mobile-push-ios-sdk | repos/SallaApp/mobile-push-android-sdk) echo "${path#repos/}" ;;
  */git/ref/tags/*) case " $FAKE_TAGS " in *" ${path##*/} "*) echo '{}' ;; *) echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;; esac ;;
  */contents/*) printf 'the API of %s at %s\n' "$(printf '%s' "$path" | cut -d/ -f2-3)" "${path##*ref=}" ;;
  *) echo "gh: unexpected call $*" >&2; exit 1 ;;
esac
EOF
  chmod 0755 "$bin/gh"
  version="$(sed -nE "s/^[[:space:]]*s\.dependency 'SallaPush', '([^']+)'.*/\1/p" "$root/ios/mobile_push.podspec")"
  pinned="$version"
  # The next two minor releases after the pinned one, as tags of the stand-in gh: a bump to them always moves the pins.
  target="$(python3 -c 'import sys; v = sys.argv[1].split("-")[0].split("."); print(f"{v[0]}.{int(v[1]) + 1}.0")' "$pinned")"
  later="$(python3 -c 'import sys; v = sys.argv[1].split("-")[0].split("."); print(f"{v[0]}.{int(v[1]) + 2}.0")' "$pinned")"
  bump() { (cd "$case" && env PATH="$bin:$clean_path" FAKE_TAGS="$pinned $target $later" scripts/bump-native.sh "$@"); }

  fresh
  check "this repository's pins agree" ok bump --check
  says "it counts the iOS pins" "SallaPush iOS $version: "
  says "and the Android pins" "SallaPush Android $version: "
  fresh
  edit android/build.gradle.kts "com.salla:mobile-push:$version" "com.salla:mobile-push:9.9.9"
  check "a pin that disagrees fails" fails bump --check
  says "it names the file and the version" "android/build.gradle.kts: 9.9.9"
  fresh
  edit docs/snippets/Podfile ":tag => '$version'" ":tag => 'v$version'"
  check "a pin in a file that holds several fails" fails bump --check
  says "it names the file" "docs/snippets/Podfile: v$version"
  fresh
  edit README.md "| Flutter " "| Wrapper version "
  check "a file with another number of pins than its count fails" fails bump --check
  says "it says how many" "README.md names SallaPush ios 0 time(s), not 1"

  for version in v1.0.3 1.0 1.0.3.4 1.0.3-; do
    check "the version '$version' is refused" fails bump "$version"
    says "it says why ($version)" "is not a native release version"
  done
  check "an option without a version is a usage error" fails bump --ios
  says "it shows the usage" "usage: scripts/bump-native.sh"

  fresh
  check "a tag that does not exist stops the bump" fails bump 9.9.9
  says "it names the repository and the tag" "SallaApp/mobile-push-ios-sdk has no tag 9.9.9"
  check "  ... and changes nothing" ok git -C "$case" diff --quiet

  fresh
  check "a bump of both platforms passes" ok bump "$target"
  says "every iOS pin is the new version" "SallaPush iOS $target: "
  says "every Android pin is the new version" "SallaPush Android $target: "
  says "without Flutter it says how to run the parity check" "run scripts/verify.sh parity"
  check "  ... the iOS API file is the tag's" ok grep -qx "the API of SallaApp/mobile-push-ios-sdk at $target" \
    "$case/tool/api-parity/native-ios-API.txt"
  check "  ... the Android API file is the tag's" ok grep -qx "the API of SallaApp/mobile-push-android-sdk at $target" \
    "$case/tool/api-parity/native-android-sallapush.api"
  check "  ... the README's versions table" ok grep -q "^| Flutter [^|]* | $target | $target |" "$case/README.md"
  check "  ... docs/SETUP.md's Podfile lines" ok grep -qF ":tag => '$target'" "$case/docs/SETUP.md"
  check "  ... docs/REFERENCE.md's links to the native docs" ok grep -qF "mobile-push-android-sdk/blob/$target/" \
    "$case/docs/REFERENCE.md"
  check "  ... and to the iOS ones" ok grep -qF "mobile-push-ios-sdk/blob/$target/" "$case/docs/REFERENCE.md"
  # The snippets step wants every "SallaPush iOS <version>" and "SallaPush Android <version>" of README.md and
  # docs/*.md at the pin (tool/check_readme_snippets.dart), so the bump moves each one.
  check "  ... every native version that README.md and docs/ name" ok python3 -c '
import glob, os, re, sys
root, target = sys.argv[1], sys.argv[2]
named = re.compile(r"SallaPush (iOS|Android) ([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?)")
stale = []
for path in [os.path.join(root, "README.md")] + sorted(glob.glob(os.path.join(root, "docs", "*.md"))):
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            stale += [f"{os.path.relpath(path, root)}:{number}: SallaPush {match[1]} {match[2]}"
                      for match in named.finditer(line) if match[2] != target]
print("\n".join(stale))
sys.exit(1 if stale else 0)' "$case" "$target"
  check "  ... the CHANGELOG line under Unreleased, Changed" ok python3 -c '
import sys
text = open(sys.argv[1]).read()
unreleased = text.split("## [Unreleased]", 1)[1].split("\n## [", 1)[0]
changed = unreleased.split("### Changed\n\n", 1)[1].split("\n### ", 1)[0] if "### Changed\n\n" in unreleased else ""
line = f"- SallaPush iOS {sys.argv[2]} and SallaPush Android {sys.argv[2]}."
sys.exit(0 if line in changed.splitlines() else 1)' "$case/CHANGELOG.md" "$target"
  check "a second bump adds no second CHANGELOG line" ok bump "$target"
  check "  ... one line" ok test "$(grep -cxF -- "- SallaPush iOS $target and SallaPush Android $target." "$case/CHANGELOG.md")" -eq 1
  check "a bump of one platform passes" ok bump --android "$later"
  says "it moves Android only" "SallaPush Android $later: "
  says "  ... and keeps iOS" "SallaPush iOS $target: "
  check "  ... with its own CHANGELOG line" ok grep -qxF -- "- SallaPush Android $later." "$case/CHANGELOG.md"

  fresh
  check "a bump to the versions already pinned passes" ok bump "$pinned"
  says "it says so for iOS" "SallaPush iOS already at $pinned"
  says "  ... and for Android" "SallaPush Android already at $pinned"
  check "  ... and changes nothing" ok git -C "$case" diff --quiet
  fresh
  check "a bump that moves one of the two platforms passes" ok bump --ios "$pinned" --android "$later"
  says "it keeps iOS" "SallaPush iOS already at $pinned"
  check "  ... the CHANGELOG line names Android only" ok grep -qxF -- "- SallaPush Android $later." "$case/CHANGELOG.md"
  check "  ... and the iOS API file is unchanged" ok git -C "$case" diff --quiet -- tool/api-parity/native-ios-API.txt
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh tree

test_verify_tree() {
  local secret_file org_action
  section "verify.sh tree"
  run() { (cd "$case" && scripts/verify.sh "$@"); }
  run_elsewhere() { (cd "$work" && "$case/scripts/verify.sh" "$@"); }

  fresh
  check "this repository's files pass" ok run tree
  check "an unknown step is refused" fails run lint-everything
  says "it lists the steps" "steps: format analyze test pigeon api parity snippets pins tree shell"

  fresh
  touch "$case/google-services.json"
  git -C "$case" add -f google-services.json
  check "a credentials file forced into git fails" fails run tree
  says "it names it" "google-services.json: a file of credentials or app configuration"
  fresh
  mkdir -p "$case/config"
  touch "$case/config/Local.Properties"
  check "a credentials file name in another case fails" fails run tree
  says "it names it" "config/Local.Properties: a file of credentials"

  # The secrets are made at run time: this file must hold none of them.
  secret_file=example/lib/leak.dart
  fresh
  printf "const token = 'gh%s_%s';\n" p "$(printf 'a%.0s' $(seq 1 36))" >"$case/$secret_file"
  check "a GitHub token fails" fails run tree
  says "it names the file, never the token" "$secret_file: holds a GitHub token"
  check "  ... also when verify.sh runs from another folder" fails run_elsewhere tree
  says "it names the file" "$secret_file: holds a GitHub token"
  fresh
  printf -- '-----%s RSA %s-----\n' BEGIN 'PRIVATE KEY' >"$case/$secret_file"
  check "a private key fails" fails run tree
  says "it names it" "$secret_file: holds a private key"
  fresh
  printf -- '-----%s PGP %s-----\n' BEGIN 'PRIVATE KEY BLOCK' >"$case/$secret_file"
  check "a PGP private key fails" fails run tree
  says "it names it" "$secret_file: holds a private key"
  fresh
  printf -- '---- %s SSH2 ENCRYPTED %s ----\n' BEGIN 'PRIVATE KEY' >"$case/$secret_file"
  check "an SSH2 private key fails" fails run tree
  says "it names it" "$secret_file: holds a private key"
  fresh
  printf '%s-User-Key-File-3: ssh-ed25519\n' PuTTY >"$case/$secret_file"
  check "a PuTTY private key fails" fails run tree
  says "it names it" "$secret_file: holds a private key"
  fresh
  printf 'https://x-access-%s:abc@github.com/SallaApp/\n' token >"$case/$secret_file"
  check "a token in a git URL fails" fails run tree
  says "it names it" "$secret_file: holds a token in a git URL"
  fresh
  printf 'path = "/%s/someone/flutter"\n' Users >"$case/$secret_file"
  check "a personal home path fails" fails run tree
  says "it names it" "$secret_file: holds a personal home path"
  fresh
  # shellcheck disable=SC2016 # the variable is written as it is, unexpanded
  printf 'https://x-access-%s:${TOKEN}@github.com/SallaApp/\n' token >"$case/$secret_file"
  check "a token variable in a git URL passes" ok run tree
  fresh
  edit example/ios/Runner.xcodeproj/project.pbxproj "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" \
    "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements; $(printf 'DEVELOPMENT_%s = %s;' TEAM ABCDE12345)"
  check "an Apple team id fails" fails run tree
  says "it names the file and where the team goes" \
    "example/ios/Runner.xcodeproj/project.pbxproj: holds an Apple team id; set DEVELOPMENT_TEAM in the ignored"
  fresh
  printf '// The fix for %s-%s.\n' TD 12345 >"$case/$secret_file"
  check "a ticket key fails" fails run tree
  says "it names the file" "$secret_file: holds a ticket key"
  fresh
  printf 'import XCTest\n' >"$case/example/ios/RunnerTests/RegressionTests.swift"
  check "an example Swift file that no target compiles fails" fails run tree
  says "it names it" "example/ios/RunnerTests/RegressionTests.swift is in no Sources phase"

  fresh
  edit ../.github/workflows/flutter-ci.yml "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1" \
    "actions/checkout@v7"
  check "an action pinned to a tag fails" fails run tree
  says "it names the line" "../.github/workflows/flutter-ci.yml:"
  says "  ... and the reference" "uses actions/checkout@v7; pin the action to a full commit id"
  fresh
  # A made-up organization's action on a branch, in the other workflow.
  org_action="example-org/actions/some-action@main"
  edit ../.github/workflows/flutter-publish.yml "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1" \
    "$org_action"
  check "an organization's action on a branch fails too" fails run tree
  says "it names it" "uses $org_action; pin the action to a full commit id"
  says "  ... in the publish workflow" "../.github/workflows/flutter-publish.yml:"
  fresh
  rm "$case/docs/snippets/Podfile"
  check "a missing required file fails" fails run tree
  says "it names it" "docs/snippets/Podfile is missing"
  fresh
  rm "$repository/.github/workflows/flutter-ci.yml"
  check "a missing workflow at the repository's root fails" fails run tree
  says "it names it" "../.github/workflows/flutter-ci.yml is missing"
  fresh
  chmod -x "$case/scripts/bump-native.sh"
  git -C "$case" update-index --chmod=-x scripts/bump-native.sh
  check "a script that is not executable fails" fails run tree
  says "it says so" "scripts/bump-native.sh is not executable"
  says "  ... also in git" "scripts/bump-native.sh is staged with mode 100644"
  fresh
  edit example/pubspec.yaml "sdk: ^3.12.0" "sdk: ^3.13.0"
  check "an example SDK bound that differs from the plugin's fails" fails run tree
  says "it names both" "lower bound (3.13.0) is not pubspec.yaml's (3.12.0)"
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh pub, against a stand-in for flutter pub publish --dry-run: in a copy that is committed, as pub wants.

test_verify_pub() {
  local sdk="$work/pub-sdk/bin" output="$work/pub-output"
  local -a package=(LICENSE README.md CHANGELOG.md pubspec.yaml lib/mobile_push.dart lib/src/sallapush.dart
    ios/mobile_push.podspec android/build.gradle.kts example/pubspec.yaml example/lib/main.dart test/user_test.dart)
  section "verify.sh pub"
  mkdir -p "$sdk"
  # Stands in for flutter: pub publish --dry-run prints $FAKE_PUB_OUTPUT and exits with $FAKE_PUB_EXIT.
  cat >"$sdk/flutter" <<'EOF'
#!/usr/bin/env bash
[ "$*" = "pub publish --dry-run" ] || { echo "flutter stand-in: unexpected call: $*" >&2; exit 2; }
cat "$FAKE_PUB_OUTPUT"
exit "${FAKE_PUB_EXIT:-0}"
EOF
  printf '#!/bin/sh\n' >"$sdk/dart"
  chmod +x "$sdk/flutter" "$sdk/dart"
  # dry_run <unicode|ascii> <summary line> <archive path...>: the output of a dry run whose archive holds those files,
  # drawn as pub draws its tree.
  dry_run() {
    python3 - "$@" >"$output" <<'PY'
import sys

glyphs, summary, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
tee, corner, line = ("├── ", "└── ", "│   ") if glyphs == "unicode" else ("+-- ", "'-- ", "|   ")
tree = {}
for path in paths:
    node = tree
    for part in path.split("/"):
        node = node.setdefault(part, {})
def draw(node, prefix):
    for index, name in enumerate(sorted(node)):
        last = index == len(node) - 1
        print(f"{prefix}{corner if last else tee}{name}{'' if node[name] else ' (1 KB)'}")
        draw(node[name], prefix + ("    " if last else line))
print("Publishing mobile_push 1.0.0 to https://pub.dev:")
draw(tree, "")
print("\nTotal compressed archive size: 179 KB.\nValidating package...\n" + summary)
PY
  }
  pub_run() {
    (cd "$case" && env PATH="$clean_path" FLUTTER="$sdk/flutter" FAKE_PUB_OUTPUT="$output" FAKE_PUB_EXIT="$1" \
      scripts/verify.sh pub)
  }

  fresh
  git -C "$case" -c user.name=self-test -c user.email=self-test@example.invalid commit -q -m "the copy"
  dry_run unicode "Package has 0 warnings." "${package[@]}"
  check "a dry run without warnings, of the package alone, passes" ok pub_run 0
  says "it describes the archive" "the archive: "
  dry_run ascii "Package has 0 warnings and 1 hint." "${package[@]}"
  check "  ... also with hints, and a tree in ASCII glyphs" ok pub_run 0
  dry_run unicode "Package has 1 warning." "${package[@]}"
  check "a dry run with a warning fails" fails pub_run 65
  says "it says what to do" "flutter pub publish --dry-run found a problem (exit 65): fix each warning above"
  dry_run unicode "Package has 0 warnings." "${package[@]}" scripts/verify.sh test/tool/dump_api_test.dart
  check "an archive with the repository's tooling fails" fails pub_run 0
  says "it names scripts/" "the archive holds scripts: .pubignore must keep it out"
  says "  ... and test/tool/" "the archive holds test/tool: .pubignore must keep it out"
  dry_run unicode "Package has 0 warnings." "${package[@]:1}"
  check "an archive without the license fails" fails pub_run 0
  says "it names it" "the archive has no LICENSE"
  printf 'Package has 0 warnings.\n' >"$output"
  check "a dry run that lists no files fails" fails pub_run 0
  says "it says so" "printed no file list of the archive"
  dry_run unicode "Package has 0 warnings." "${package[@]}"
  printf '\nA change.\n' >>"$repository/.github/workflows/flutter-ci.yml"
  check "a change outside the package's folder is no change of the package" ok pub_run 0
  printf '\nA change.\n' >>"$case/README.md"
  check "a tree with changes is refused" fails pub_run 0
  says "it says why" "commit or stash the changes first"
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh android without an emulator (VERIFY_ANDROID_NO_EMULATOR), against stand-ins for flutter, the example's
# Gradle wrapper, apkanalyzer and adb: no device, SDK or network is touched.

test_verify_android() {
  local sdk="$work/android-flutter/bin" android="$work/android-sdk" calls="$work/adb-calls"
  section "verify.sh android (VERIFY_ANDROID_NO_EMULATOR)"
  mkdir -p "$sdk" "$android/cmdline-tools/latest/bin" "$android/platform-tools"
  # flutter: build apk --config-only does nothing; build apk --release writes the build and R8's mapping where Flutter
  # writes them.
  cat >"$sdk/flutter" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "build apk --config-only") ;;
  "build apk --release")
    mkdir -p build/app/outputs/mapping/release build/app/outputs/flutter-apk
    echo mapping >build/app/outputs/mapping/release/mapping.txt
    echo apk >build/app/outputs/flutter-apk/app-release.apk
    ;;
  *) echo "flutter stand-in: unexpected call: $*" >&2; exit 2 ;;
esac
EOF
  printf '#!/bin/sh\n' >"$sdk/dart"
  # apkanalyzer: the merged manifest the step expects, or one without the init provider with FAKE_MANIFEST_BROKEN=1.
  cat >"$android/cmdline-tools/latest/bin/apkanalyzer" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "manifest print" ] || { echo "apkanalyzer stand-in: unexpected call: $*" >&2; exit 2; }
init='<provider android:name="sa.salla.sallapush_flutter.SallaPushInitProvider" android:initOrder="-1" />'
[ "${FAKE_MANIFEST_BROKEN:-}" != 1 ] || init=""
cat <<XML
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <provider android:name="com.google.firebase.provider.FirebaseInitProvider" android:initOrder="100" />
    $init
    <service android:name="com.salla.push.SallaPushFirebaseMessagingService">
      <intent-filter android:priority="-450" />
    </service>
  </application>
</manifest>
XML
EOF
  # adb: no device attached; every call is recorded.
  cat >"$android/platform-tools/adb" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_ADB_CALLS"
[ "$1" = devices ] || exit 1
echo "List of devices attached"
EOF
  chmod +x "$sdk/flutter" "$sdk/dart" "$android/cmdline-tools/latest/bin/apkanalyzer" "$android/platform-tools/adb"
  # android_run [VARIABLE=value...]: verify.sh android in the copy, with the stand-ins and the variables given.
  android_run() {
    (cd "$case" && env PATH="$clean_path" FLUTTER="$sdk/flutter" ANDROID_HOME="$android" ANDROID_SDK_ROOT= \
      FAKE_ADB_CALLS="$calls" "$@" scripts/verify.sh android)
  }

  fresh
  # The example's Gradle wrapper, which Flutter writes: the plugin's unit tests leave one JUnit result.
  cat >"$case/example/android/gradlew" <<'EOF'
#!/usr/bin/env bash
[ "$*" = "--no-daemon :mobile_push:testDebugUnitTest :mobile_push:lintDebug" ] ||
  { echo "gradlew stand-in: unexpected call: $*" >&2; exit 2; }
mkdir -p ../build/mobile_push/test-results/testDebugUnitTest
printf '<testsuite name="stand-in" tests="2" failures="0">\n</testsuite>\n' \
  >../build/mobile_push/test-results/testDebugUnitTest/TEST-stand-in.xml
EOF
  chmod +x "$case/example/android/gradlew"
  rm -f "$calls"
  check "with VERIFY_ANDROID_NO_EMULATOR=1, every other check runs without an emulator" ok \
    android_run VERIFY_ANDROID_NO_EMULATOR=1
  says "it says so" "VERIFY_ANDROID_NO_EMULATOR=1: every check but the release build's run on an emulator"
  says "  ... and its summary too" "passed (without the emulator run (VERIFY_ANDROID_NO_EMULATOR))"
  says "the merged manifest is checked" "SallaPushInitProvider: initOrder -1"
  check "  ... and adb is never called" fails test -e "$calls"
  check "the merged manifest still fails without the init provider" fails \
    android_run VERIFY_ANDROID_NO_EMULATOR=1 FAKE_MANIFEST_BROKEN=1
  says "it says why" "SallaPushInitProvider is not in the merged manifest"
  check "without the variable, no emulator fails the step" fails android_run
  says "it says why" "0 running emulators: start one, or set VERIFY_EMULATOR_SERIAL"
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh summary.tsv, the evidence of a run: in a copy that is committed, as a run's would be.

test_verify_summary() {
  local logs="$work/summary-logs" head next
  section "verify.sh summary.tsv"
  logged() { (cd "$case" && VERIFY_LOG_DIR="$logs" scripts/verify.sh "$@"); }
  commit_case() {
    git -C "$case" -c user.name=self-test -c user.email=self-test@example.invalid commit -q --allow-empty -m "$1"
  }
  # row <step> <commit>: the summary has a row of <step> that names <commit>.
  row() { awk -F '\t' -v step="$1" -v commit="$2" '$1 == step && $4 == commit { found = 1 } END { exit !found }' \
    "$logs/summary.tsv"; }

  fresh
  rm -rf "$logs"
  commit_case "the copy"
  head="$(git -C "$case" rev-parse HEAD)"
  check "a run of a clean tree passes" ok logged tree
  check "  ... its summary names the commit and a clean tree first" ok test "$(head -n 1 "$logs/summary.tsv")" = "# $head clean"
  check "  ... and its row names the commit" ok row tree "$head"
  printf '\nA change.\n' >>"$repository/.github/workflows/flutter-ci.yml"
  check "a run with a change outside the package's folder adds its row" ok logged tree
  check "  ... not marked +dirty" fails row tree "$head+dirty"
  printf '\nA change.\n' >>"$case/README.md"
  check "a run of the same commit with changes adds its row" ok logged tree
  check "  ... marked +dirty" ok row tree "$head+dirty"
  commit_case "another commit"
  next="$(git -C "$case" rev-parse HEAD)"
  check "a run of another commit into the same summary is refused" fails logged tree
  says "it names both commits" "holds the runs of $head, not of $next"
  check "  ... and adds no row" fails grep -q "$next" "$logs/summary.tsv"
}

test_resolve_flutter
test_ios_sdk_checkout
make_pristine
test_bump_native
test_verify_tree
test_verify_pub
test_verify_android
test_verify_summary

printf '\nself-test.sh: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
