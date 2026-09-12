# OpenAudio visual intent

Reference: ../openloop-memory/Sources/OpenLoopApp/UI/OpenLoopVisualSystem.swift and WorkspaceChrome.swift, inspected locally. Emotional target: calm control. Audio identity comes from application icons, tiny live level indicators and explicit destination names.

Use native SwiftUI controls inside a 220-point pale sidebar, a fluid flat mixer list and an optional 320-point detail inspector. Canvas is #FEFEFE / #1E2024; sidebar #F4F5F7 / #191B1F; selection #E1E8F1 / #303A47; accent #2F78D0 / #6FA8EA; separators #ECEDEF / #343840. System type at 38-point bold titles, 15-point row labels and 12-point metadata. Spacing uses 4, 8, 12, 20 and 32 points.

The signature element is each app's destination line and thin live stereo-level mark, aligned under an unboxed application row. No decorative audio waves or fabricated activity. Keep the default window usable at 1100×740; constrain inspector width and allow vertical scrolling. The compact menu presents the same model with smaller rows.

Navigation: Applications, Devices, Profiles. Route selection opens the inspector; returning does not reset routing. Every control has a label. Empty app discovery explains that an app must open audio; capture failures expose retry and privacy settings. Missing devices remain visibly selected. Reset, undo, bypass and quit have separate meanings. Appearance follows macOS unless explicitly changed.

## Final visual check

Light and dark native renders were inspected at 1160×800 logical points. Sidebar labels stay on one line; hierarchy separates navigation, application rows, and the adjustment inspector. The title, enable action, output selection and first real app are visible without scrolling. Unsupported/idle background services are tucked behind a filter. Blue denotes interaction; actual application icons and measured meters carry the audio identity. Standard native controls provide keyboard/accessibility behavior. The inspector and list scroll independently.
