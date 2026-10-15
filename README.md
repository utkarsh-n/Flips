# Flips

A native SwiftUI number playground for iPhone and iPad. Requires iOS 26 or later.

## Play

- **Bits:** flip weighted switches to build a byte. Decimal, binary, and hexadecimal stay in sync. Four-bit groups show how each hex digit forms. Scrub, step, or count automatically to watch carrying.
- **Bases:** compare binary, octal, decimal, and hexadecimal. Inspect each digit's contribution, enter your own number, and follow carry/borrow transitions.
- **Discover:** solve ten hands-on missions, save progress, and send a solution to the switchboard. Mix RGB channels to see what a six-digit hex color means.
- **Logic:** compare AND, OR, XOR, and NOT with one-bit truth tables, then use the result on the switchboard. Try logical shifts.

The toy uses **unsigned 8-bit integers, 0–255**. Counting wraps at the boundary, and explains why 256 needs another bit. Negative numbers and fractions are outside this toy's scope. Binary and hex readouts use leading zeroes to show the full byte; the Bases lab shows minimal digits.

Turn on **Slow motion** in Bits, then tap **+1** or **−1**. A carry or borrow moves from bit 0 toward the higher places with a quiet haptic tick. The speed slider ranges from **0.25×** (2.4 seconds per bit) to **3×** (0.2 seconds per bit); the default **1×** uses 0.6 seconds per bit. Your pace saves locally and can change during playback without restarting the operation. Pause holds the working pattern, Next step advances one place, and Stop restores the starting number. Count repeats these sequences with a short rest between numbers.

Tap the compact **15 + 1** or **16 − 1** example chips in Bits to load and play a five-bit carry or borrow at your saved speed. These buttons turn on Slow motion automatically and can replay or switch examples during playback. They stop automatic counting and replace any unfinished trace.

**255 + 1** and **0 − 1** show all eight bits changing, followed by a final step explaining the carry or borrow beyond the byte. They settle at **0** and **255**, respectively, with the same saved pace and a stronger optional haptic cue when the wrap resolves.

The trace labels each temporary pattern as **working bits** and shows the pending carry or borrow debt. For example, 7 + 1 passes through working values 6, 4, and 0 with pending carries 2, 4, and 8 before finishing at 8. These temporary values are not completed arithmetic results. The saved number changes only when the operation finishes. Wraps have an extra step explaining the carry or debt beyond the eighth bit. Leaving Bits or backgrounding cancels an unfinished trace.

No accounts, networking, tracking, or dependencies. The current byte, haptics preference, and mission progress save locally. Counting pauses when switching tabs or leaving the app.

Optional haptics distinguish switches turning on or off, manual steps, carries, wraps, input validation, and mission completion. Byte and RGB scrubs use throttled ticks. Ordinary automatic counting is silent; Slow motion supplies one small tick per trace step. Disable touch feedback in How to play.

## Build

Open `Flips.xcodeproj` and run the `Flips` scheme. The supplied signing team matches the existing local apps; choose another team if necessary. `project.yml` is the XcodeGen source of the project. The core is an Xcode framework for the app and a standalone Swift package for tests.

```sh
xcodegen generate
swift test
```

If this Mac's Documents folder causes Xcode to wait in file coordination, copy this entire directory into a temporary local directory and build that copy. Source changes belong in the original project. The QA record includes the exact verification setup.

## Design and verification

`Design/concepts.png` contains three generated interface directions. The chosen dark instrument uses mint for binary, amber for hex, and lilac for decimal. `Design/concept-prompt.txt` records the exact built-in Imagegen prompt. The app renders its interface with native SwiftUI, and `Design/app-icon.swift` generates its simple icon.

Interactive controls and weighted switches use native Liquid Glass while number readouts, place-value tiles, and content cards stay solid. Switches respond with a brief press spring, a small change in scale, and a single native symbol bounce. Numeric transitions and custom motion respect Reduce Motion. Reduce Transparency gives the switches an explicit opaque surface.

`Tests/RadixCoreTests` checks all byte values in all supported bases, place sums, carry reconstruction, all 512 increment/decrement traces, input validation, logic, shifts, and mission validation. `UITests` exercises conversion, switchboard, mission, logic, and slow-motion playback flows. See `design-qa.md` for results.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
