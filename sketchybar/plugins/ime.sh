#!/bin/sh

NAME=${NAME:-ime}

LABEL=$(swift -e 'import Carbon
let s = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
let p = TISGetInputSourceProperty(s, kTISPropertyLocalizedName)!
print(Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String)')

sketchybar --set "$NAME" label="$LABEL"
