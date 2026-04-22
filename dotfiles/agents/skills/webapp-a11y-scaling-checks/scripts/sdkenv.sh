#!/usr/bin/env bash
# Source this file from other scripts to put the Android SDK + a JDK on
# PATH. Resolution order (per dependency):
#
# Android SDK (covers adb, emulator, avdmanager, build-tools, platforms):
#   1. $ANDROID_HOME / $ANDROID_SDK_ROOT (env)        — standard install
#   2. ~/Library/Android/sdk (macOS)                  — Android Studio default
#      ~/Android/Sdk (Linux)
#   3. ~/.local/share/android                         — android-nixpkgs
#   4. none → instruct user to install Android Studio + complete setup
#
# JDK (javac, keytool):
#   1. javac on PATH                                  — system / standard
#   2. /Applications/Android Studio.app/.../jbr       — Android Studio JBR
#      ~/Android/android-studio/jbr (Linux)
#   3. `nix build nixpkgs#jdk21`                      — nix fallback
#   4. none → instruct user to install Android Studio (bundles a JBR)
#
# After sourcing, ANDROID_HOME / ANDROID_SDK_ROOT / JAVA_HOME are
# exported, and adb / emulator / avdmanager / javac / keytool are
# resolvable via PATH.
#
# Auto-detected from the resolved SDK (each respects an env override):
#   ANDROID_HOST_ABI          arm64-v8a / x86_64        — uname -m
#   ANDROID_SYSTEM_IMAGE      sdkmanager package id     — newest matching
#                                                         google_apis_playstore
#                                                         install for the host
#                                                         ABI (else empty)
#   ANDROID_PLATFORM_API      e.g. 36                   — newest installed
#   ANDROID_PLATFORM_JAR      $SDK/platforms/android-NN/android.jar
#   ANDROID_BUILD_TOOLS_DIR   $SDK/build-tools/M.M.M    — newest installed
# Empty when no candidate is installed; consumers (boot_emulator.sh,
# build_apk.sh) assert presence at point of use.

_sdkenv_die() { echo "sdkenv: $*" >&2; exit 1; }

# --- Android SDK ---
_sdkenv_resolve_sdk() {
  local p
  for p in \
    "${ANDROID_HOME:-}" \
    "${ANDROID_SDK_ROOT:-}" \
    "$HOME/Library/Android/sdk" \
    "$HOME/Android/Sdk" \
    "$HOME/.local/share/android"; do
    if [ -n "$p" ] && [ -x "$p/platform-tools/adb" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

if _sdkenv_sdk=$(_sdkenv_resolve_sdk); then
  export ANDROID_HOME="$_sdkenv_sdk"
  export ANDROID_SDK_ROOT="$_sdkenv_sdk"
  for _sdkenv_d in platform-tools emulator cmdline-tools/latest/bin; do
    [ -d "$_sdkenv_sdk/$_sdkenv_d" ] && PATH="$_sdkenv_sdk/$_sdkenv_d:$PATH"
  done
  export PATH
  unset _sdkenv_sdk _sdkenv_d
else
  cat >&2 <<'MSG'
sdkenv: no Android SDK found. Looked in:
  $ANDROID_HOME / $ANDROID_SDK_ROOT
  ~/Library/Android/sdk     (Android Studio macOS default)
  ~/Android/Sdk             (Android Studio Linux default)
  ~/.local/share/android    (android-nixpkgs)

Install Android Studio (https://developer.android.com/studio) and run
its setup wizard. The wizard places the SDK at the default path above
and bundles a JBR that satisfies the JDK requirement.
MSG
  exit 1
fi

# --- JDK (javac / keytool) ---
_sdkenv_resolve_jdk_dir() {
  # `javac -version` (not `command -v`) — macOS ships a /usr/bin/javac
  # stub that resolves but fails at runtime when no JDK is installed.
  if javac -version >/dev/null 2>&1; then
    return 0  # works on PATH; printf nothing → no JAVA_HOME export
  fi
  local p
  for p in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    "$HOME/Android/android-studio/jbr" \
    "$HOME/Android/Sdk/jbr"; do
    if [ -x "$p/bin/javac" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

if _sdkenv_jdk=$(_sdkenv_resolve_jdk_dir); then
  if [ -n "$_sdkenv_jdk" ]; then
    export JAVA_HOME="$_sdkenv_jdk"
    export PATH="$_sdkenv_jdk/bin:$PATH"
  fi
  unset _sdkenv_jdk
elif command -v nix >/dev/null 2>&1; then
  _sdkenv_jdk=$(nix build --print-out-paths --no-link nixpkgs#jdk21 2>/dev/null) \
    || _sdkenv_die "nix build nixpkgs#jdk21 failed"
  export JAVA_HOME="$_sdkenv_jdk"
  export PATH="$_sdkenv_jdk/bin:$PATH"
  unset _sdkenv_jdk
else
  _sdkenv_die "no JDK (javac) found and nix is not installed.
  Install Android Studio (which bundles a JBR) or any JDK 17+ on PATH."
fi

# --- Host ABI ---
if [ -z "${ANDROID_HOST_ABI:-}" ]; then
  case "$(uname -m)" in
    arm64|aarch64) ANDROID_HOST_ABI="arm64-v8a" ;;
    x86_64|amd64)  ANDROID_HOST_ABI="x86_64" ;;
    *)             ANDROID_HOST_ABI="" ;;
  esac
fi
export ANDROID_HOST_ABI

# --- Newest installed system-image (google_apis_playstore + host ABI) ---
_sdkenv_pick_system_image() {
  local abi="$1" sdk="$2" dir api best=""
  [ -n "$abi" ] || return 1
  for dir in "$sdk"/system-images/android-*/google_apis_playstore/"$abi"; do
    [ -d "$dir" ] || continue
    api=$(basename "$(dirname "$(dirname "$dir")")" | sed 's/^android-//')
    [ "$api" -eq "$api" ] 2>/dev/null || continue
    if [ -z "$best" ] || [ "$api" -gt "$best" ]; then best="$api"; fi
  done
  [ -n "$best" ] || return 1
  printf 'system-images;android-%s;google_apis_playstore;%s\n' "$best" "$abi"
}

if [ -z "${ANDROID_SYSTEM_IMAGE:-}" ]; then
  ANDROID_SYSTEM_IMAGE=$(_sdkenv_pick_system_image "$ANDROID_HOST_ABI" "$ANDROID_SDK_ROOT") || ANDROID_SYSTEM_IMAGE=""
fi
export ANDROID_SYSTEM_IMAGE

# --- Newest installed platform (android-NN) ---
_sdkenv_pick_platform() {
  local sdk="$1" dir api best=""
  for dir in "$sdk"/platforms/android-*; do
    [ -f "$dir/android.jar" ] || continue
    api=$(basename "$dir" | sed 's/^android-//')
    [ "$api" -eq "$api" ] 2>/dev/null || continue
    if [ -z "$best" ] || [ "$api" -gt "$best" ]; then best="$api"; fi
  done
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}

if [ -z "${ANDROID_PLATFORM_API:-}" ]; then
  ANDROID_PLATFORM_API=$(_sdkenv_pick_platform "$ANDROID_SDK_ROOT") || ANDROID_PLATFORM_API=""
fi
if [ -z "${ANDROID_PLATFORM_JAR:-}" ] && [ -n "$ANDROID_PLATFORM_API" ]; then
  ANDROID_PLATFORM_JAR="$ANDROID_SDK_ROOT/platforms/android-$ANDROID_PLATFORM_API/android.jar"
fi
export ANDROID_PLATFORM_API ANDROID_PLATFORM_JAR

# --- Newest installed build-tools ---
_sdkenv_pick_build_tools() {
  local sdk="$1" v
  v=$(ls -1 "$sdk/build-tools" 2>/dev/null | sort -V | tail -1)
  [ -n "$v" ] || return 1
  printf '%s\n' "$sdk/build-tools/$v"
}

if [ -z "${ANDROID_BUILD_TOOLS_DIR:-}" ]; then
  ANDROID_BUILD_TOOLS_DIR=$(_sdkenv_pick_build_tools "$ANDROID_SDK_ROOT") || ANDROID_BUILD_TOOLS_DIR=""
fi
export ANDROID_BUILD_TOOLS_DIR

unset -f _sdkenv_die _sdkenv_resolve_sdk _sdkenv_resolve_jdk_dir \
         _sdkenv_pick_system_image _sdkenv_pick_platform _sdkenv_pick_build_tools
