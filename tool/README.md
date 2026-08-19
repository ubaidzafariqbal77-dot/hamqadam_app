# tool/

## Running on an iOS simulator (`simulator.sh`)

This app depends on `google_mlkit_text_recognition` for the CNIC card scan on the
identity step. Google publishes **no arm64-simulator slice** for the ML Kit pods
(`GoogleMLKit`, `MLImage`, `MLKitCommon`, `MLKitVision`), and Xcode 26 removed
Rosetta simulator destinations — `xcodebuild -showdestinations` lists every
simulator as `arch:arm64` only. So the real plugin cannot link for any iOS 26
simulator, and there is no newer pod to upgrade to: `GoogleMLKit 9.0.0` and
`MLImage 1.0.0-beta8` are already the latest published versions.

The failure looks like this:

```
The following target(s) do not support arm64 architecture, which is a
requirement for Apple Silicon iOS 26+ simulators:
  - GoogleMLKit (transitive dependency of google_mlkit_text_recognition)
  ...
Could not build the application for the simulator.
```

`simulator.sh` works around it by swapping the plugin for `tool/mlkit_stub`, a
package with the **same name and the same Dart API but no native side**, so
CocoaPods never installs those frameworks.

```bash
tool/simulator.sh on      # stub ML Kit  -> simulator runs; CNIC OCR does not
tool/simulator.sh off     # real ML Kit  -> device/release builds; OCR works
tool/simulator.sh status
```

Each mode rewrites `pubspec_overrides.yaml`, re-runs `flutter pub get`, and
reinstalls the pods from scratch.

### What breaks while the stub is active

Only text recognition. `TextRecognizer.processImage` throws, which
`CnicOcrService.extractCnic` already catches and reports as "no number found", so
step 14 falls back to typing the CNIC in by hand. Everything else — the whole
registration flow, uploads, login — behaves normally.

### Do not ship a stubbed build

`pubspec_overrides.yaml` is what activates the stub, and it is untracked, so it
shows up in `git status` — do not commit it. Run `tool/simulator.sh off` before
building for a device or for release. A stubbed build also prints
`⚠️ ML Kit is not in this build…` the first time a recognizer is created.

### The real fix

Either Google ships an arm64-simulator slice for MLImage/MLKitVision, or the OCR
moves to Apple's Vision framework on iOS (native, arm64-simulator ready). Until
then this toggle is the only way to run on a simulator on Apple Silicon.
