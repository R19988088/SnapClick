#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
output=${1:-"$root/build/audio-driver/SnapClickAudio.driver"}
configuration=${CONFIGURATION:-Debug}
architectures=${ARCHS:-$(uname -m)}
sdk=$(xcrun --sdk macosx --show-sdk-path)
work="$root/build/audio-driver/intermediates"

rm -rf "$output" "$work"
mkdir -p "$output/Contents/MacOS" "$work"
cp "$root/SnapClickAudioDriver/Info.plist" "$output/Contents/Info.plist"

binaries=()
for arch in $architectures; do
    arch_dir="$work/$arch"
    mkdir -p "$arch_dir"
    objects=()
    sources=("$root/SnapClickAudioDriver/Driver.cpp" "$root"/ThirdParty/libASPL/src/*.cpp)
    for source in "${sources[@]}"; do
        object="$arch_dir/$(basename "${source%.cpp}")-$(printf '%s' "$source" | shasum | cut -c1-8).o"
        xcrun clang++ -c "$source" -o "$object" \
            -arch "$arch" -std=c++17 -fPIC -O2 \
            -Wno-reorder-init-list -Wno-invalid-offsetof \
            -mmacosx-version-min=13.0 -isysroot "$sdk" \
            -I "$root/ThirdParty/libASPL/include" \
            -I "$root/ThirdParty/libASPL/src"
        objects+=("$object")
    done
    binary="$work/SnapClickAudio-$arch"
    xcrun clang++ -bundle -arch "$arch" -o "$binary" "${objects[@]}" \
        -mmacosx-version-min=13.0 -isysroot "$sdk" \
        -framework CoreAudio -framework CoreFoundation
    binaries+=("$binary")
done

if [ "${#binaries[@]}" -eq 1 ]; then
    cp "${binaries[0]}" "$output/Contents/MacOS/SnapClickAudio"
else
    xcrun lipo -create "${binaries[@]}" -output "$output/Contents/MacOS/SnapClickAudio"
fi

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp=none --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$output"
fi

echo "$output"
