#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build
bin_dir="$(swift build --show-bin-path)"
swiftc Sources/OpenAudio/Control/Models.swift Tests/OpenAudioTests/Runner.swift -I "$bin_dir/AudioDSP.build" "$bin_dir/AudioDSP.build/AudioDSP.c.o" -framework CoreAudio -framework AudioToolbox -o "$bin_dir/OpenAudioChecks"
"$bin_dir/OpenAudioChecks"

swiftc Sources/OpenAudio/Listening/MediaModels.swift Sources/OpenAudio/Listening/ArtworkLoader.swift Sources/OpenAudio/Listening/CoverLookup.swift Sources/OpenAudio/Listening/HeadlessCoverPolicy.swift Sources/OpenAudio/Listening/HeadlessCover.swift Sources/OpenAudio/UI/RecordMotion.swift Tests/ListeningChecks.swift -o "$bin_dir/ListeningChecks"
"$bin_dir/ListeningChecks"
