# ContextualEmbeddingAssetCheck

`NLContextualEmbedding(language:)` の asset availability と
`requestAssets()` の完了有無を実機で確認するための最小 SwiftUI アプリです。

## 検証内容

Run を押すと次の順でログを画面と Xcode console に出します。

1. device / OS / language を記録
2. 選択した言語で `NLContextualEmbedding(language:)` が `nil` か確認
3. `hasAvailableAssets` の初期値を記録
4. asset request 前に `load()` を試して、失敗内容を記録
5. `requestAssets()` を開始し、返った場合は result と `hasAvailableAssets` を記録
6. request 後に `load()` を再試行
7. timeout marker 秒数を超えても返らない場合は、未完了ログを記録

timeout marker は `requestAssets()` を強制終了するためのものではなく、
「指定秒数を超えても async call が戻っていない」ことを記録するための目印です。

言語は画面上の picker で切り替えられます。現在の候補は Japanese / English /
Simplified Chinese / Traditional Chinese / Korean / French / German / Spanish です。

## Apple Vision Pro での実行

Xcode で `ContextualEmbeddingAssetCheck.xcodeproj` を開き、実機の Apple Vision Pro を
destination に選んで実行します。

このプロジェクトは iOS app target なので、Apple Vision Pro では Xcode の destination に
`Designed for iPad/iPhone` variant として表示されます。投稿の論点を native visionOS app として
切り分けたい場合は、同じ `ContentView.swift` を visionOS app target に追加して同じ手順で実行してください。

## 記録するとよい項目

- Device model
- visionOS version
- Xcode version
- 実行先が native visionOS app か、Designed for iPad/iPhone variant か
- 選択した language
- `hasAvailableAssets before`
- `load() without requestAssets` の error domain / code / localized description
- `requestAssets()` が返ったか
- 返った場合の result と `hasAvailableAssets after`
- timeout marker を何秒にしたか
