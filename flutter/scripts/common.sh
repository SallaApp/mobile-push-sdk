# shellcheck shell=bash disable=SC2034 # the constants are read by the scripts that source this file
# Definitions shared by scripts/verify.sh, scripts/bump-native.sh and scripts/self-test.sh. Sourced, never run. The
# functions never exit: they print what is wrong to stderr and return 1, so they also work inside $(...).

# A native SallaPush version, as the native SDKs tag their releases: X.Y.Z or X.Y.Z-<pre-release>.
readonly NATIVE_VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'

# Every place that names a native SallaPush version, as <file>|<regex>|<platform>|<count>. Group 1 of the regex (a
# Python regular expression) is the version; <count> is how many matches the file must hold, or + for at least one.
# scripts/bump-native.sh rewrites them all and checks that they agree (the pins step of scripts/verify.sh); a file
# that starts naming a native version gets a line here.
readonly NATIVE_PINS=(
  "ios/mobile_push.podspec|s\.dependency 'SallaPush', '([^']+)'|ios|1"
  "ios/mobile_push/Package.swift|/mobile-push-ios-sdk\.git\", exact: \"([^\"]+)\"|ios|1"
  "docs/snippets/Podfile|:tag => '([^']+)'|ios|4"
  "docs/SETUP.md|/mobile-push-ios-sdk\.git', :tag => '([^']+)'|ios|4"
  "example/ios/Runner.xcodeproj/project.pbxproj|^[ \t]*version = ([0-9][^;]*);$|ios|1"
  "android/build.gradle.kts|\"com\.salla:mobile-push:([^\"]+)\"|android|1"
  "tool/api-parity/mapping.json|^    \"ios\": \"([^\"]+)\",?$|ios|1"
  "tool/api-parity/mapping.json|^    \"android\": \"([^\"]+)\",?$|android|1"
  "README.md|^[|] Flutter [^|]+ [|] ([^ |]+) [|]|ios|1"
  "README.md|^[|] Flutter [^|]+ [|] [^|]+ [|] ([^ |]+) [|]|android|1"
  "docs/SETUP.md|SallaPush iOS ([0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?)|ios|+"
  # The links to the native docs, at the pinned tags.
  "docs/REFERENCE.md|github\.com/SallaApp/mobile-push-ios-sdk/blob/([^/]+)/|ios|+"
  "docs/REFERENCE.md|github\.com/SallaApp/mobile-push-android-sdk/blob/([^/]+)/|android|+"
)

# The native SDKs' repositories, whose API files scripts/bump-native.sh fetches at a tag.
readonly NATIVE_IOS_REPOSITORY=SallaApp/mobile-push-ios-sdk
readonly NATIVE_ANDROID_REPOSITORY=SallaApp/mobile-push-android-sdk

# Sets FLUTTER to the Flutter binary, from the environment or else flutter on PATH, and DART to the dart next to it.
# FLUTTER_MIN, the oldest supported Flutter, stays optional.
#   resolve_flutter
resolve_flutter() {
  local flutter="${FLUTTER:-}"
  [ -n "$flutter" ] || flutter="$(command -v flutter || true)"
  if [ -z "$flutter" ]; then
    echo "Flutter not found: set FLUTTER to the bin/flutter of Flutter 3.47, or put flutter on PATH" >&2
    return 1
  fi
  case "$flutter" in
    */*) ;;
    *) flutter="$(command -v "$flutter" || true)" ;;
  esac
  if [ -z "$flutter" ] || [ ! -x "$flutter" ]; then
    echo "FLUTTER=${FLUTTER:-flutter} is not an executable flutter binary" >&2
    return 1
  fi
  if [ ! -x "$(dirname "$flutter")/dart" ]; then
    echo "$(dirname "$flutter")/dart not found: FLUTTER must be the bin/flutter of a Flutter SDK" >&2
    return 1
  fi
  FLUTTER="$flutter"
  DART="$(dirname "$flutter")/dart"
  FLUTTER_MIN="${FLUTTER_MIN:-}"
  export FLUTTER DART FLUTTER_MIN
}

# Prints the UDID of the iPhone simulator to use: VERIFY_SIMULATOR_UDID when set (it must be an available simulator),
# else a booted iPhone, else an iPhone of the newest iOS runtime.
#   simulator_udid <work dir>
simulator_udid() {
  local work="$1"
  xcrun simctl list devices available -j >"$work/simulators.json" || {
    echo "xcrun simctl cannot list the simulators: install Xcode and an iOS simulator runtime" >&2
    return 1
  }
  python3 - "$work/simulators.json" "${VERIFY_SIMULATOR_UDID:-}" <<'PY'
import json, re, sys

devices = json.load(open(sys.argv[1]))["devices"]
wanted = sys.argv[2]

def version(runtime):
    return tuple(int(part) for part in re.findall(r"(\d+)", runtime.split("iOS-")[-1]))

phones = [(version(runtime), device) for runtime, entries in devices.items() if ".iOS-" in runtime
          for device in entries if device.get("name", "").startswith("iPhone")]
if wanted:
    if not any(device["udid"] == wanted for entries in devices.values() for device in entries):
        sys.exit(f"VERIFY_SIMULATOR_UDID={wanted} is not an available simulator")
    print(wanted)
elif not phones:
    sys.exit("no available iPhone simulator: install an iOS simulator runtime, or set VERIFY_SIMULATOR_UDID")
else:
    booted = [phone for phone in phones if phone[1].get("state") == "Booted"]
    print(max(booted or phones, key=lambda phone: phone[0])[1]["udid"])
PY
}

# Prints the absolute path of VERIFY_IOS_SDK_CHECKOUT, a clone of SallaApp/mobile-push-ios-sdk that Swift Package
# Manager builds use in place of the remote package pinned at <version>. It must be SallaPush iOS <version> exactly: a
# git clone of its own in a folder named mobile-push-ios-sdk, with the tag <version> checked out and no changes.
#   ios_sdk_checkout <version>
ios_sdk_checkout() {
  local version="$1" checkout="${VERIFY_IOS_SDK_CHECKOUT:-}" tag changes
  if [ -z "$checkout" ] || ! checkout="$(cd "$checkout" 2>/dev/null && pwd -P)"; then
    echo "VERIFY_IOS_SDK_CHECKOUT=${VERIFY_IOS_SDK_CHECKOUT:-} does not exist" >&2
    return 1
  fi
  if [ "${checkout##*/}" != mobile-push-ios-sdk ]; then
    echo "VERIFY_IOS_SDK_CHECKOUT must be a folder named mobile-push-ios-sdk, the remote package's name" >&2
    return 1
  fi
  if [ "$(git -C "$checkout" rev-parse --show-toplevel 2>/dev/null)" != "$checkout" ]; then
    echo "VERIFY_IOS_SDK_CHECKOUT is not a git clone of SallaApp/mobile-push-ios-sdk" >&2
    return 1
  fi
  if ! tag="$(git -C "$checkout" rev-parse --verify --quiet "refs/tags/$version^{commit}")"; then
    echo "VERIFY_IOS_SDK_CHECKOUT has no tag $version, the pinned version" >&2
    return 1
  fi
  if [ "$(git -C "$checkout" rev-parse --verify --quiet HEAD)" != "$tag" ]; then
    echo "VERIFY_IOS_SDK_CHECKOUT is not at the tag $version: check the tag out (git checkout $version)" >&2
    return 1
  fi
  if ! changes="$(git -C "$checkout" status --porcelain --untracked-files=normal)" || [ -n "$changes" ]; then
    echo "VERIFY_IOS_SDK_CHECKOUT has changes, so it is not SallaPush iOS $version exactly (git status)" >&2
    return 1
  fi
  if ! grep -qxF "package let sallaPushSDKVersion = \"$version\"" \
    "$checkout/Sources/SallaPushCore/SallaPushVersion.swift"; then
    echo "VERIFY_IOS_SDK_CHECKOUT is not SallaPush iOS $version, the pinned version" >&2
    return 1
  fi
  echo "$checkout"
}

# Prints the path of an Android SDK tool: <relative path> under ANDROID_HOME, ANDROID_SDK_ROOT or the default SDK
# location of macOS, else <name> on PATH.
#   android_tool <relative path> <name>
android_tool() {
  local sdk
  for sdk in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
    if [ -n "$sdk" ] && [ -x "$sdk/$1" ]; then
      echo "$sdk/$1"
      return 0
    fi
  done
  command -v "$2" || {
    echo "$2 not found: set ANDROID_HOME to an Android SDK that has $1" >&2
    return 1
  }
}

# Prints the serial of the Android emulator to use: VERIFY_EMULATOR_SERIAL when set (it must be running), else the
# only running emulator.
#   emulator_serial <adb>
emulator_serial() {
  local adb="$1" serials count
  if [ -n "${VERIFY_EMULATOR_SERIAL:-}" ]; then
    [ "$("$adb" -s "$VERIFY_EMULATOR_SERIAL" get-state 2>/dev/null || true)" = device ] || {
      echo "VERIFY_EMULATOR_SERIAL=$VERIFY_EMULATOR_SERIAL is not a running device" >&2
      return 1
    }
    echo "$VERIFY_EMULATOR_SERIAL"
    return 0
  fi
  serials="$("$adb" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1 }')"
  count="$(printf '%s' "$serials" | grep -c '' || true)"
  [ "$count" -eq 1 ] || {
    echo "$count running emulators: start one, or set VERIFY_EMULATOR_SERIAL" >&2
    return 1
  }
  echo "$serials"
}

# Fails unless the JUnit XML results under <dir> hold at least one test; prints how many ran.
#   assert_tests_ran <dir>
assert_tests_ran() {
  local dir="$1" total
  [ -d "$dir" ] || {
    echo "$dir does not exist: no test ran" >&2
    return 1
  }
  total="$(find "$dir" -name '*.xml' -exec sed -nE 's/.*<testsuite [^>]*tests="([0-9]+)".*/\1/p' {} + |
    awk '{ total += $1 } END { print total + 0 }')"
  [ "$total" -gt 0 ] || {
    echo "the JUnit results under $dir hold no test" >&2
    return 1
  }
  echo "$total tests ran ($dir)"
}
