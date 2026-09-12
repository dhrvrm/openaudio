#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
preview_dir="$(mktemp -d /tmp/openaudio-preview.XXXXXX)"
preview_bundle="$preview_dir/StaticPreview.bundle"
mkdir -p "$preview_bundle/Contents/MacOS" "$preview_bundle/Contents/Resources/Moods"
cp Resources/Moods/* "$preview_bundle/Contents/Resources/Moods/"
swift build
bin_dir="$(swift build --show-bin-path)"
source_files=(${(f)"$(rg --files Sources/OpenAudio -g '*.swift' | rg -v '/OpenAudioApp.swift$')"})
swiftc "${source_files[@]}" Tests/RenderVinylWindow.swift -I "$bin_dir/AudioDSP.build" "$bin_dir/AudioDSP.build/AudioDSP.c.o" -o "$preview_bundle/Contents/MacOS/StaticPreview"
"$preview_bundle/Contents/MacOS/StaticPreview" "$preview_dir/images"
swiftc Sources/OpenAudio/UI/RecordMotion.swift Sources/OpenAudio/UI/VinylStage.swift Sources/OpenAudio/UI/VinylAtmosphere.swift Tests/RenderVinyl.swift -o "$preview_dir/stage"
"$preview_dir/stage" "$preview_dir/images" Resources/Moods/Warm.jpg
print "$preview_dir/images"
