# ContextualEmbeddingAssetCheck

`NLContextualEmbedding(language:)` の asset availability と
`requestAssets()` の完了有無を確認するための最小 SwiftUI アプリです。

macOS / iOS / visionOS 向けに同じ画面をビルドし、言語ごとの contextual embedding
asset が利用可能か、asset request が完了するか、実際に embedding result を生成できるかを
画面上のログと Xcode console で確認できます。

## 検証内容

Run を押すと次の順でログを画面と Xcode console に出します。

1. device / OS / language を記録
2. 選択した言語で `NLContextualEmbedding(language:)` が `nil` か確認
3. `hasAvailableAssets` の初期値を記録
4. asset request 前に `load()` を試し、成功または失敗内容を記録
5. `requestAssets()` を開始し、返った場合は result と `hasAvailableAssets` を記録
6. request 後に `load()` を再試行
7. `load()` が成功した場合、短いサンプル文で `embeddingResult(for:language:)` を実行
8. model identifier / dimension / maximum sequence length / token vector の一部を記録
9. timeout marker 秒数を超えても返らない場合は、未完了ログを記録

timeout marker は `requestAssets()` を強制終了するためのものではなく、
「指定秒数を超えても async call が戻っていない」ことを記録するための目印です。

言語は画面上の picker で切り替えられます。現在の候補は Japanese / English /
Simplified Chinese / Traditional Chinese / Korean / French / German / Spanish です。

## 実行方法

Xcode で `ContextualEmbeddingAssetCheck.xcodeproj` を開き、確認したい実機または Mac を
destination に選んで実行します。

Mac 向けのビルド確認は次のコマンドでも実行できます。

```sh
xcodebuild -project ContextualEmbeddingAssetCheck.xcodeproj \
  -scheme ContextualEmbeddingAssetCheck \
  -configuration Debug \
  -destination platform=macOS \
  -derivedDataPath .build/DerivedData \
  build
```

Apple Vision Pro で確認する場合は、Xcode の destination で Apple Vision Pro を選んで実行します。
native visionOS app と iPad/iPhone 互換 variant を切り分けたい場合は、Xcode の表示される
destination variant を記録してください。

## 記録するとよい項目

- Device model
- OS name / version
- Xcode version
- 実行先の platform または destination variant
- 選択した language
- `hasAvailableAssets before`
- `load() without requestAssets` の error domain / code / localized description
- `requestAssets()` が返ったか
- 返った場合の result と `hasAvailableAssets after`
- `load() after requestAssets` の結果
- `modelIdentifier`
- `model dimension`
- `maximumSequenceLength`
- `embeddingResult language`
- `embeddingResult sequenceLength`
- `enumerated token vectors`
- timeout marker を何秒にしたか
