#!/usr/bin/env bash
# Tests of this repository's shell tooling, on throwaway copies in a temporary directory, with stand-ins for every
# network or build tool: Yarn's resolution in common.sh, bump-native.sh, and the tree and pack steps and the summary of
# verify.sh. It needs bash, git and python3. Scratch commits use an isolated git configuration, so they are never
# signed, and nothing is pushed.
#
#   scripts/self-test.sh
set -euo pipefail

scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd "$scripts/.." && pwd -P)"
work="$(mktemp -d "${TMPDIR:-/tmp}/sallapush-self-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

mkdir -p "$work/home"
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=self-test GIT_AUTHOR_EMAIL=self-test@example.invalid
export GIT_COMMITTER_NAME=self-test GIT_COMMITTER_EMAIL=self-test@example.invalid
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE YARN VERIFY_LOG_DIR GITHUB_ACTIONS

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

# stand_in <path>: an executable shell script, its body read from standard input.
stand_in() {
  mkdir -p "$(dirname "$1")"
  { echo '#!/bin/sh'; cat; } >"$1"
  chmod 0755 "$1"
}

# edit <file> <old> <new>: replaces the first <old>; stops the self-test when <old> is missing.
edit() {
  python3 - "$1" "$2" "$3" <<'PY'
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
# common.sh

test_yarn_resolution() {
  local with_yarn="$work/bin-with-yarn" with_corepack="$work/bin-with-corepack" none="$work/bin-none"
  section "common.sh: Yarn's resolution"
  stand_in "$with_yarn/yarn" <<'EOF'
echo "yarn on PATH: $*"
EOF
  stand_in "$with_corepack/corepack" <<'EOF'
echo "corepack: $*"
EOF
  stand_in "$work/custom-yarn" <<'EOF'
echo "YARN: $*"
EOF
  mkdir -p "$none"
  # The stand-ins are the whole PATH, so no installed Yarn or Corepack can answer.
  resolve() { env PATH="$1" ${2:+YARN="$2"} "$BASH" -c ". \"\$0\"; sp_yarn --version" "$scripts/common.sh"; }
  check "YARN wins over yarn on PATH" ok resolve "$with_yarn" "$work/custom-yarn"
  says "it runs YARN" "YARN: --version"
  check "without YARN, yarn on PATH" ok resolve "$with_yarn"
  says "it runs yarn" "yarn on PATH: --version"
  check "without yarn, Corepack's" ok resolve "$with_corepack"
  says "it runs corepack yarn" "corepack: yarn --version"
  check "without any, it fails" fails resolve "$none"
  says "it says what to install" "install Node 24 (it ships Corepack), or set YARN"
}

test_xctest_results() {
  local bin="$work/bin-xcrun"
  section "common.sh: the XCTest results"
  # Stands in for xcrun xcresulttool: prints FAKE_SUMMARY's file, and refuses any other command.
  stand_in "$bin/xcrun" <<'EOF'
[ "$1 $2 $3 $4 $5" = "xcresulttool get test-results summary --path" ] || exit 64
cat "$FAKE_SUMMARY"
EOF
  results() {
    printf '%s\n' "$1" >"$work/summary.json"
    env PATH="$bin:$PATH" FAKE_SUMMARY="$work/summary.json" \
      "$BASH" -c ". \"\$0\"; assert_xctests_ran \"\$1\"" "$scripts/common.sh" "$work/Tests.xcresult"
  }
  check "results with passed tests pass" ok results '{"passedTests": 112, "totalTestCount": 112, "failedTests": 0}'
  says "it counts them" "112 of 112 tests passed"
  check "results without a test fail" fails results '{"passedTests": 0, "totalTestCount": 0, "failedTests": 0}'
  says "it says so" "no XCTest ran"
}

# ---------------------------------------------------------------------------------------------------------------------
# A copy of this package's files (what a commit would take), in the react-native folder of a copy of the repository
# with the repository's root files and .github, every workflow included, at its root, for the cases that change files;
# each case starts from a fresh copy. The copy is a git repository without commits, so every file is untracked and not
# ignored.

pristine_top="$work/pristine"
pristine="$pristine_top/react-native"
case_top="$work/case"
case_dir="$case_top/react-native"

make_pristine() {
  local name
  mkdir -p "$pristine"
  # The root's files are listed as ../<path>, so they land at the copy's root.
  git -C "$root" ls-files -z --cached --others --exclude-standard -- . ':(top,glob)*' ':(top).github' >"$work/files"
  while IFS= read -r -d '' name; do
    [ -f "$root/$name" ] || continue
    mkdir -p "$pristine/$(dirname "$name")"
    cp -p "$root/$name" "$pristine/$name"
  done <"$work/files"
  git -C "$pristine_top" init -q
}

fresh() {
  rm -rf "${case_top:?}"
  cp -Rp "$pristine_top" "$case_top"
}

# ---------------------------------------------------------------------------------------------------------------------
# bump-native.sh

test_bump_native() {
  local bin="$work/bin-bump" served="$work/gh-served" version target missing line ios_pins android_pins
  section "bump-native.sh (verify.sh pins, and native bumps)"
  # Stands in for gh api: serves $FAKE_GH/<repository>/<tag>/<path>; anything else is GitHub's 404.
  stand_in "$bin/gh" <<'EOF'
for argument; do :; done
request="${argument#repos/SallaApp/}"
repository="${request%%/*}"
file="${request#*/contents/}"
file="${file%%\?*}"
tag="${request##*ref=}"
[ -f "$FAKE_GH/$repository/$tag/$file" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
cat "$FAKE_GH/$repository/$tag/$file"
EOF
  # Stands in for node: records the script it runs, and exits with FAKE_NODE_STATUS.
  stand_in "$bin/node" <<'EOF'
printf "%s\n" "$*" >>"$FAKE_NODE_RECORD"
exit "${FAKE_NODE_STATUS:-0}"
EOF
  # node_status: what the parity check exits with.
  bump() {
    (cd "$case_dir" && env PATH="$bin:$PATH" FAKE_GH="$served" FAKE_NODE_RECORD="$work/node.args" \
      FAKE_NODE_STATUS="${node_status:-0}" scripts/bump-native.sh "$@")
  }
  version="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["nativeVersions"]["ios"])' "$pristine/tool/api-parity/mapping.json")"
  # The next minor release after the pinned one, whose API files gh serves, and the one after it, which gh doesn't
  # serve: a bump to either always moves the pins.
  target="$(python3 -c 'import sys; v = sys.argv[1].split("-")[0].split("."); print(f"{v[0]}.{int(v[1]) + 1}.0")' "$version")"
  missing="$(python3 -c 'import sys; v = sys.argv[1].split("-")[0].split("."); print(f"{v[0]}.{int(v[1]) + 2}.0")' "$version")"
  mkdir -p "$served/mobile-push-ios-sdk/$target" "$served/mobile-push-android-sdk/$target/sallapush/api"
  printf 'SallaPush | swift.class | SallaPush | @objc(SallaPush) final class SallaPush\n' >"$served/mobile-push-ios-sdk/$target/API.txt"
  printf 'public final class com/salla/push/SallaPush {\n}\n' >"$served/mobile-push-android-sdk/$target/sallapush/api/sallapush.api"

  fresh
  check "this repository's pins agree" ok bump --check
  # The docs name the versions as often as they need to, so the counts come from this check; a bump must set them all.
  ios_pins="$(sed -nE "s/^ios $version: ([0-9]+) pins agree$/\1/p" "$out")"
  android_pins="$(sed -nE "s/^android $version: ([0-9]+) pins agree$/\1/p" "$out")"
  # The code's 7 iOS pins and 2 Android pins, and at least one of each kind the README must hold.
  check "  ... every iOS pin of the code and the README" ok test "${ios_pins:-0}" -ge 11
  check "  ... every Android pin of the code and the README" ok test "${android_pins:-0}" -ge 5
  fresh; edit "$case_dir/plugin/src/constants.ts" "SALLAPUSH_IOS_VERSION = '$version'" "SALLAPUSH_IOS_VERSION = '9.9.9'"
  line="$(grep -n "SALLAPUSH_IOS_VERSION = '9.9.9'" "$case_dir/plugin/src/constants.ts" | cut -d : -f 1)"
  check "a pin that disagrees fails" fails bump --check
  says "it names the pin" "plugin/src/constants.ts:$line 9.9.9"
  fresh; edit "$case_dir/README.md" "SallaPush Android $version" "SallaPush Android 9.9.9"
  line="$(grep -n "SallaPush Android 9.9.9" "$case_dir/README.md" | cut -d : -f 1)"
  check "a version the README names is a pin" fails bump --check
  says "it names the line" "README.md:$line 9.9.9"
  fresh; edit "$case_dir/android/build.gradle" "com.salla:mobile-push:$version" "com.salla:mobile-push:+"
  check "a file that lost its pin fails" fails bump --check
  says "it names the file" "android/build.gradle has no android pin"
  check "a version that isn't a release is refused" fails bump v1.0.3
  says "it says why" "'v1.0.3' is not a SallaPush iOS release"
  check "one platform alone is a usage error" fails bump --ios 1.0.3

  fresh
  : >"$work/node.args"
  check "a bump to a tag gh can't read stops" fails bump "$missing"
  says "it says which file and tag" "cannot read API.txt at $missing from SallaApp/mobile-push-ios-sdk"
  check "  ... and changes no pin" ok grep -qF "s.dependency \"SallaPush\", \"$version\"" "$case_dir/SallaPushReactNative.podspec"
  check "a bump to the next minor release passes" ok bump "$target"
  says "it sets every iOS pin" "ios: $ios_pins pins set to $target"
  says "it sets every Android pin" "android: $android_pins pins set to $target"
  check "  ... and they agree" ok bump --check
  says "  ... on $target" "ios $target: $ios_pins pins agree"
  check "  ... in the Podfile, four times" ok test "$(grep -cF ":tag => '$target'" "$case_dir/example/ios/Podfile")" -eq 4
  check "  ... in mapping.json" ok grep -qF "\"android\": \"$target\"" "$case_dir/tool/api-parity/mapping.json"
  check "  ... in the README's versions table" ok grep -qF "| $target | $target |" "$case_dir/README.md"
  check "  ... in the README's Podfile lines" ok grep -qF ":tag => '$target'" "$case_dir/README.md"
  check "  ... in the README's links to the native docs" ok grep -qF "mobile-push-android-sdk/blob/$target/" "$case_dir/README.md"
  check "  ... and to the iOS ones" ok grep -qF "mobile-push-ios-sdk/blob/$target/" "$case_dir/README.md"
  check "  ... in docs/REFERENCE.md's links to the native docs" ok grep -qF "mobile-push-android-sdk/blob/$target/" \
    "$case_dir/docs/REFERENCE.md"
  check "  ... and to the iOS ones" ok grep -qF "mobile-push-ios-sdk/blob/$target/" "$case_dir/docs/REFERENCE.md"
  check "  ... in docs/TROUBLESHOOTING.md's links to the native docs" ok grep -qF "mobile-push-android-sdk/blob/$target/" \
    "$case_dir/docs/TROUBLESHOOTING.md"
  check "  ... in docs/REFERENCE.md's compatibility list" ok grep -qF "SallaPush iOS $target and SallaPush Android $target" \
    "$case_dir/docs/REFERENCE.md"
  check "  ... with the API files of the new tags" ok cmp -s "$served/mobile-push-ios-sdk/$target/API.txt" \
    "$case_dir/tool/api-parity/native-ios-API.txt"
  check "  ... and the CHANGELOG line under Changed" ok python3 -c '
import sys
text = open(sys.argv[1], encoding="utf-8").read()
unreleased = text.split("## [Unreleased]", 1)[1].split("\n## ", 1)[0]
version = sys.argv[2]
changed = unreleased.split("### Changed\n\n", 1)[1].split("\n### ", 1)[0]
assert f"- SallaPush iOS {version} and SallaPush Android {version}." in changed.split("\n"), unreleased
assert "### Added" not in unreleased or unreleased.index("### Added") < unreleased.index("### Changed"), unreleased' "$case_dir/CHANGELOG.md" "$target"
  check "  ... and it ran the parity check" ok grep -q 'check-api-parity.mjs' "$work/node.args"
  check "the same bump again adds no second CHANGELOG line" ok bump "$target"
  check "  ... so the line is there once" ok test "$(grep -cF "SallaPush iOS $target and SallaPush Android $target" "$case_dir/CHANGELOG.md")" -eq 1
  fresh
  node_status=1 check "a bump whose parity check fails, fails" fails bump "$target"
  says "it says what to do" "map each native symbol named above in tool/api-parity/mapping.json"

  # gh serves no API file at the pinned version, so these pass only without fetching it.
  fresh
  check "a bump to the versions already pinned passes" ok bump "$version"
  says "it says so for iOS" "SallaPush iOS already at $version"
  says "  ... and for Android" "SallaPush Android already at $version"
  check "  ... and changes nothing" ok diff -rq --exclude=.git "$pristine" "$case_dir"
  fresh
  check "a bump that moves one of the two platforms passes" ok bump --ios "$version" --android "$target"
  says "it keeps iOS" "SallaPush iOS already at $version"
  says "  ... and sets every Android pin" "android: $android_pins pins set to $target"
  check "  ... the CHANGELOG line names Android only" ok grep -qxF -- "- SallaPush Android $target." "$case_dir/CHANGELOG.md"
  check "  ... and the iOS API file is unchanged" ok cmp -s "$pristine/tool/api-parity/native-ios-API.txt" \
    "$case_dir/tool/api-parity/native-ios-API.txt"
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh tree

test_verify_tree() {
  local checkout_pin workflows="$case_top/.github/workflows"
  section "verify.sh: steps and the tree step"
  run() { (cd "$case_dir" && scripts/verify.sh "$@"); }
  g() { git -C "$case_dir" "$@"; }

  fresh
  check "this repository's files pass" ok run tree
  check "an unknown step is refused" fails run everything
  says "it lists the steps" "steps: lint typecheck test build pack api parity snippets pins tree shell"
  fresh; printf '{}\n' >"$case_dir/example/android/app/google-services.json"; g add -f example/android/app/google-services.json
  check "a Firebase configuration added past .gitignore fails" fails run tree
  says "it names it" "example/android/app/google-services.json: a file of credentials"
  fresh; printf 'TOKEN=x\n' >"$case_dir/.env.local"; g add -f .env.local
  check "a .env file added past .gitignore fails" fails run tree
  says "it names it" ".env.local: a file of credentials"
  fresh; : >"$case_dir/Release.P12"; g add -f Release.P12
  check "a signing key fails, whatever its case" fails run tree
  says "it names it" "Release.P12: a file of credentials"
  # The secrets are assembled at run time, so that this file never holds one.
  fresh; printf 'const token = "%s%s";\n' 'ghp_' 'abcdefghijklmnopqrstuvwxyz0123456789' >"$case_dir/src/token.ts"
  check "a GitHub token in any file fails" fails run tree
  says "it names the file" "src/token.ts: holds a GitHub token"
  cp "$out" "$work/token.out"
  check "  ... and never prints the token" fails grep -q 'abcdefghijklmnopqrstuvwxyz0123456789' "$work/token.out"
  fresh; printf 'GITHUB_TOKEN=%s%s\n' 'gho_' 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij' >"$case_dir/scripts/notes.txt"
  check "a GitHub OAuth token, as gh auth token prints it, fails" fails run tree
  says "it names the file" "scripts/notes.txt: holds a GitHub token"
  fresh; printf '%s%s\n' '-----BEGIN RSA ' 'PRIVATE KEY-----' >"$case_dir/example/key.txt"
  check "a private key in any file fails" fails run tree
  says "it names the file" "example/key.txt: holds a private key"
  fresh; printf '%s%s\n' '-----BEGIN PGP ' 'PRIVATE KEY BLOCK-----' >"$case_dir/example/key.asc"
  check "a PGP private key fails" fails run tree
  says "it names the file" "example/key.asc: holds a private key"
  fresh; printf 'url = https://%s%s%s@github.com\n' 'x-access-' 'token' ':abc' >"$case_dir/notes.txt"
  check "a token in a git URL fails" fails run tree
  says "it names the file" "notes.txt: holds a token in a git URL"
  fresh; printf 'url = https://%s%s%s{TOKEN}@github.com\n' 'x-access-' 'token' ':$' >"$case_dir/notes.txt"
  check "a rewrite with a variable, not a token, passes" ok run tree
  fresh; printf 'NODE_BINARY=%s%s/someone/node\n' '/Us' 'ers' >"$case_dir/example/ios/.xcode.env"
  check "a personal home path fails" fails run tree
  says "it names the file" "example/ios/.xcode.env: holds a personal home path"
  fresh; edit "$case_dir/example/ios/SallaPushExample.xcodeproj/project.pbxproj" \
    "CODE_SIGN_ENTITLEMENTS = SallaPushExample/SallaPushExample.entitlements;" \
    "CODE_SIGN_ENTITLEMENTS = SallaPushExample/SallaPushExample.entitlements; $(printf 'DEVELOPMENT_%s = %s;' TEAM ABCDE12345)"
  check "an Apple team id fails" fails run tree
  says "it names the file and where the team goes" \
    "example/ios/SallaPushExample.xcodeproj/project.pbxproj: holds an Apple team id; set DEVELOPMENT_TEAM in the ignored"
  fresh; printf '// The fix for %s-%s.\n' TD 12345 >"$case_dir/src/notes.ts"
  check "a ticket key fails" fails run tree
  says "it names the file" "src/notes.ts: holds a ticket key"
  fresh; printf 'import XCTest\n' >"$case_dir/example/ios/SallaPushExampleTests/RegressionTests.swift"
  check "an example Swift file that no target compiles fails" fails run tree
  says "it names it" "example/ios/SallaPushExampleTests/RegressionTests.swift is in no Sources phase"
  checkout_pin="$(grep -m 1 -oE 'actions/checkout@[0-9a-f]{40}' "$pristine_top/.github/workflows/react-native-ci.yml")"
  fresh; edit "$workflows/react-native-ci.yml" "$checkout_pin" "actions/checkout@v7"
  check "an action pinned to a tag fails" fails run tree
  says "it says what to do" "uses actions/checkout@v7; pin it to a full commit id"
  says "  ... and names the workflow at the repository's root" "../.github/workflows/react-native-ci.yml:"
  # An action of another repository on a branch has no exception either.
  fresh; printf '      - uses: example-org/actions/some-action@main\n' >>"$workflows/react-native-publish.yml"
  check "an organization's action on a branch fails too" fails run tree
  says "it says what to do" "some-action@main; pin it to a full commit id"
  fresh; printf '      - uses: ./.github/actions/local\n' >>"$workflows/react-native-ci.yml"
  check "a local action of this repository passes" ok run tree
  # The tree step checks the repository's root for every package: its files, and every workflow.
  fresh; printf '      - uses: actions/checkout@v7\n' >>"$workflows/flutter-ci.yml"
  check "an action pinned to a tag in another package's workflow fails too" fails run tree
  says "it names that workflow" "../.github/workflows/flutter-ci.yml:"
  fresh; printf 'token: %s%s\n' 'ghp_' 'abcdefghijklmnopqrstuvwxyz0123456789' >>"$case_top/README.md"
  check "a GitHub token in a file at the repository's root fails" fails run tree
  says "it names the file" "../README.md: holds a GitHub token"
  fresh; printf '{}\n' >"$case_top/google-services.json"; g add -f ../google-services.json
  check "a Firebase configuration added at the repository's root fails" fails run tree
  says "it names it" "../google-services.json: a file of credentials"
  fresh; rm "$workflows/react-native-publish.yml"
  check "a missing workflow fails" fails run tree
  says "it names it" "../.github/workflows/react-native-publish.yml is missing from what a commit takes"
  fresh; rm "$case_dir/api/sallapush-react-native.api"
  check "a missing required file fails" fails run tree
  says "it names it" "api/sallapush-react-native.api is missing from what a commit takes"
  fresh; printf 'CHANGELOG.md\n' >>"$case_dir/.gitignore"
  check "a required file that .gitignore hides fails" fails run tree
  says "it names it" "CHANGELOG.md is missing from what a commit takes"
  fresh; chmod -x "$case_dir/scripts/self-test.sh"
  check "a script that lost its executable bit fails" fails run tree
  says "it names it" "scripts/self-test.sh is not executable"
  fresh; g add scripts/bump-native.sh; g update-index --chmod=-x scripts/bump-native.sh
  check "a script staged without the executable mode fails" fails run tree
  says "it names it" "scripts/bump-native.sh is staged with mode 100644"
  fresh
  check "a fresh copy passes again" ok run tree
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh pack

test_verify_pack() {
  local bin="$work/bin-pack" listing="$work/pack-listing"
  section "verify.sh pack (what npm would publish)"
  # Stands in for npm: run (the prepack build) fails when FAKE_PREPACK_FAILS is set; pack prints FAKE_PACK's paths as
  # npm pack --json lists them.
  stand_in "$bin/npm" <<'EOF'
case "$1" in
  run) [ -z "$FAKE_PREPACK_FAILS" ] ;;
  pack) python3 -c 'import json, sys; print(json.dumps([{"files": [{"path": line.strip()} for line in open(sys.argv[1]) if line.strip()]}]))' "$FAKE_PACK" ;;
  *) exit 64 ;;
esac
EOF
  pack() {
    (cd "$case_dir" && env PATH="$bin:$PATH" FAKE_PACK="$listing" FAKE_PREPACK_FAILS="${prepack_fails:-}" \
      scripts/verify.sh pack)
  }
  fresh
  # What npm packs from this tree after the prepack build: the built files, the files every app needs, and the folders
  # that files names, without tests, mocks, fixtures and dotfiles.
  (cd "$case_dir" && {
    printf '%s\n' package.json README.md LICENSE app.plugin.js SallaPushReactNative.podspec lib/module/index.js \
      lib/typescript/src/index.d.ts plugin/build/index.js
    find src ios android plugin/templates -type f ! -path '*/__tests__/*' ! -path '*/__mocks__/*' \
      ! -path 'android/src/test/*' ! -name '.*'
  }) >"$listing.good"
  cp "$listing.good" "$listing"
  check "the package of this tree passes" ok pack
  says "it counts the files" "npm pack: $(grep -c '' "$listing.good") files"
  printf 'src/__tests__/SallaPush.test.ts\n' >>"$listing"
  check "a test in the package fails" fails pack
  says "it names it" "the package holds src/__tests__/SallaPush.test.ts, a test, fixture, mock or dotfile"
  { cat "$listing.good"; printf 'ios/.DS_Store\n'; } >"$listing"
  check "a dotfile in the package fails" fails pack
  says "it names it" "the package holds ios/.DS_Store, a test, fixture, mock or dotfile"
  { cat "$listing.good"; printf 'scripts/verify.sh\n'; } >"$listing"
  check "a file outside the package's folders fails" fails pack
  says "it names it" "the package holds scripts/verify.sh, which isn't part of the package"
  # npm packs the folders that files names as they are on disk, the files .gitignore hides included.
  printf '{}\n' >"$case_dir/android/google-services.json"
  { cat "$listing.good"; printf 'android/google-services.json\n'; } >"$listing"
  check "a file that .gitignore hides, in a packed folder, fails" fails pack
  says "it names it" "the package holds android/google-services.json, which .gitignore hides"
  rm "$case_dir/android/google-services.json"
  grep -vxF lib/module/index.js "$listing.good" >"$listing"
  check "a package without the built library fails" fails pack
  says "it names the file" "the package lacks lib/module/index.js"
  grep -vxF ios/RNSallaPush.mm "$listing.good" >"$listing"
  check "a package without a committed native file fails" fails pack
  says "it names the file" "the package lacks ios/RNSallaPush.mm"
  cp "$listing.good" "$listing"
  prepack_fails=1 check "a prepack build that fails, fails" fails pack
  says "it says so" "npm run prepack failed"
}

# ---------------------------------------------------------------------------------------------------------------------
# verify.sh summary.tsv, the evidence of a run: in a copy that is committed, as a run's would be.

test_verify_summary() {
  local logs="$work/summary-logs" head next
  section "verify.sh: summary.tsv"
  logged() { (cd "$case_dir" && VERIFY_LOG_DIR="$logs" scripts/verify.sh "$@"); }
  commit_case() { git -C "$case_dir" add -A && git -C "$case_dir" commit -q -m "$1"; }
  # row <step> <commit>: the summary has a row of <step> that names <commit>.
  row() { awk -F '\t' -v step="$1" -v commit="$2" '$1 == step && $3 == commit { found = 1 } END { exit !found }' \
    "$logs/summary.tsv"; }

  fresh
  rm -rf "$logs"
  commit_case "the copy"
  head="$(git -C "$case_dir" rev-parse HEAD)"
  check "a run of a clean tree passes" ok logged tree
  check "  ... its summary names the commit and a clean tree first" ok test "$(head -n 1 "$logs/summary.tsv")" = "# $head clean"
  check "  ... and its row names the commit" ok row tree "$head"
  printf '\nA change.\n' >>"$case_dir/README.md"
  check "a run of the same commit with changes adds its row" ok logged tree
  check "  ... marked +dirty" ok row tree "$head+dirty"
  commit_case "another commit"
  next="$(git -C "$case_dir" rev-parse HEAD)"
  check "a run of another commit into the same summary is refused" fails logged tree
  says "it names both commits" "holds the runs of $head, not of $next"
  check "  ... and adds no row" fails grep -q "$next" "$logs/summary.tsv"
  # Another package's changes don't make this package's runs +dirty.
  logs="$work/outside-logs"
  mkdir -p "$case_top/flutter"
  printf 'A change.\n' >"$case_top/flutter/README.md"
  check "a run with changes outside react-native/ only passes" ok logged tree
  check "  ... its summary names a clean tree" ok test "$(head -n 1 "$logs/summary.tsv")" = "# $next clean"
  check "  ... and its row isn't +dirty" ok row tree "$next"
}

test_yarn_resolution
test_xctest_results
make_pristine
test_bump_native
test_verify_tree
test_verify_pack
test_verify_summary

printf '\nself-test: %d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
