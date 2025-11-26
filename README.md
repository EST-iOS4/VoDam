# VoDam

This repository contains the VoDam iOS application. Use the steps below to open and run the app so you can try any recent changes locally.

## Requirements
- Xcode 15 or later on macOS.
- An iOS simulator or device that meets the project's deployment target (set in the Xcode project settings).

## Run the app
1. Open the project: `open Vodam.xcodeproj` (or double-click `Vodam.xcodeproj` in Finder).
2. Let Xcode resolve the Swift Package Manager dependencies.
3. In the toolbar, select the **Vodam** scheme and choose your target device/simulator.
4. Press **Cmd+R** to build and run. This launches the latest version of the app so you can verify the modified files.

## Copy the modified files
Use any of the options below to copy the files or changes you made:

- **Copy an entire file to your clipboard (macOS):**
  ```bash
  pbcopy < Vodam/Feature/Record/RecordingView.swift
  pbcopy < Vodam/Feature/Record/RecordingFeature.swift
  ```
  Replace the paths with the files you want. You can then paste the file contents wherever you need.

- **Copy only the diff:**
  ```bash
  git diff > changes.patch    # saves all uncommitted changes into a patch file
  pbcopy < changes.patch      # optional: copy the patch to your clipboard (macOS)
  ```
  The `changes.patch` file contains only your modifications. Send or apply it with `git apply changes.patch` on another machine.

- **Copy from Finder:** In Xcode's Project navigator, right-click the file you modified and choose **Show in Finder**. You can then copy the file directly from the Finder window.

## Running from the command line
If you prefer `xcodebuild`, the example below launches the app in the simulator. Adjust the device name to one installed in your environment:

```bash
xcodebuild \
  -scheme Vodam \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  run
```
