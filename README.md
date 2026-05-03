# ContextualEmbeddingAssetCheck

Japanese: [README.ja.md](README.ja.md)

A minimal SwiftUI app for checking `NLContextualEmbedding(language:)` asset availability
and whether `requestAssets()` completes.

The same screen can be built for macOS, iOS, and visionOS. It logs whether contextual
embedding assets are available for each language, whether the asset request completes,
and whether an embedding result can actually be generated.

## What It Checks

When you press Run, the app writes the following logs to both the screen and the Xcode console.

1. Records the device, OS, and selected language
2. Checks whether `NLContextualEmbedding(language:)` returns `nil` for the selected language
3. Records the initial `hasAvailableAssets` value
4. Calls `load()` before requesting assets and records whether it succeeds or fails
5. Starts `requestAssets()` and, if it returns, records the result and `hasAvailableAssets`
6. Tries `load()` again after the request
7. If `load()` succeeds, runs `embeddingResult(for:language:)` with a short sample sentence
8. Records the model identifier, dimension, maximum sequence length, and part of the token vectors
9. Records a pending log if the timeout marker is reached before `requestAssets()` returns

The timeout marker does not cancel `requestAssets()`. It only marks that the async call
has not returned after the selected number of seconds.

You can switch languages from the picker. The current options are Japanese, English,
Simplified Chinese, Traditional Chinese, Korean, French, German, and Spanish.

## Running

Open `ContextualEmbeddingAssetCheck.xcodeproj` in Xcode, select the device or Mac you
want to check as the destination, and run the app.

You can also verify the macOS build from the command line:

```sh
xcodebuild -project ContextualEmbeddingAssetCheck.xcodeproj \
  -scheme ContextualEmbeddingAssetCheck \
  -configuration Debug \
  -destination platform=macOS \
  -derivedDataPath .build/DerivedData \
  build
```

To check Apple Vision Pro behavior, select Apple Vision Pro as the Xcode destination
and run the app. If you need to distinguish a native visionOS app from an iPad/iPhone
compatibility variant, record the destination variant shown by Xcode.

## Useful Items To Record

- Device model
- OS name and version
- Xcode version
- Platform or destination variant
- Selected language
- `hasAvailableAssets before`
- Error domain, code, and localized description from `load() without requestAssets`
- Whether `requestAssets()` returned
- If it returned, the result and `hasAvailableAssets after`
- Result of `load() after requestAssets`
- `modelIdentifier`
- `model dimension`
- `maximumSequenceLength`
- `embeddingResult language`
- `embeddingResult sequenceLength`
- `enumerated token vectors`
- Timeout marker value
