# log.txt 整理メモ

## 検証環境

- Device: Apple Vision Pro
- OS: visionOS 26.4 (Build 23O247)
- Comparison device: iPhone
- Comparison OS: iOS 26.4.2 (Build 23E261)
- 対象 API: `NLContextualEmbedding(language:)`
- ログ対象: asset availability、`load()`、`requestAssets()`、`embeddingResult(for:language:)`

## 結論

現在のログでは、Latin 系の contextual embedding asset は取得・利用できている一方で、Hani 系の asset は取得できていません。

- English は初回 `hasAvailableAssets == false` から `requestAssets()` 後に利用可能になった。
- English はその後の再実行とプロセス再起動後も `hasAvailableAssets == true` で、`load()` が即成功している。
- French も同じ Latin 系モデルを使っており、English の asset 取得後は `load()` が即成功している。
- Japanese と Simplified Chinese は同じ Hani 系モデルを使っており、`requestAssets()` が `NLNaturalLanguageErrorDomain 7: Asset download request timed out` で失敗している。
- `load()` 前に asset がない場合の `NLNaturalLanguageErrorDomain 8: Failed to locate embedding model` は、asset 未取得時の期待される失敗として扱える。

iPhone 実機では、Japanese / Simplified Chinese / Traditional Chinese / Korean を含む全言語が `hasAvailableAssets == true` で即 `load()` に成功している。Hani 系モデルの `modelIdentifier` は visionOS 側で失敗していたものと同じ `12784592-5D67-4F4C-83D6-A346519146AE` だった。

ただし iPhone 側では asset が最初から利用可能だったため、`requestAssets()` による asset download 経路は実行されていない。この比較で確認できたのは「iPhone 上では同じ Hani 系モデルが利用可能」という点であり、「iPhone 上で Hani 系 asset download が成功する」という点ではない。

そのため、Hani 系 asset や `NLContextualEmbedding` API 自体が汎用的に利用不能という線は弱くなった。一方で、visionOS 26.4 / Apple Vision Pro 上の asset download request、配布、権限、キャッシュ、または daemon 側の問題という可能性は残る。

## 実行結果サマリ

| 時刻 | Language | 初期 asset | requestAssets | load / smoke test | modelIdentifier |
| --- | --- | --- | --- | --- | --- |
| 21:09 | English (`en`) | `false` | 約13秒で返却、`rawValue: 0` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:12 | Japanese (`ja`) | `false` | 約36秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:13 | English (`en`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:14 | Japanese (`ja`) | `false` | 約174秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:18 | Simplified Chinese (`zh-Hans`) | `false` | 約105秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:20 | French (`fr`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:22 | English (`en`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |

## iPhone 実機での比較結果

| 時刻 | Device / OS | Language | 初期 asset | load / smoke test | modelIdentifier |
| --- | --- | --- | --- | --- | --- |
| 21:49 | iPhone / iOS 26.4.2 (23E261) | Japanese (`ja`) | `true` | 成功 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:49 | iPhone / iOS 26.4.2 (23E261) | English (`en`) | `true` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:49 | iPhone / iOS 26.4.2 (23E261) | Simplified Chinese (`zh-Hans`) | `true` | 成功 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:49 | iPhone / iOS 26.4.2 (23E261) | Traditional Chinese (`zh-Hant`) | `true` | 成功 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:50 | iPhone / iOS 26.4.2 (23E261) | Korean (`ko`) | `true` | 成功 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 21:50 | iPhone / iOS 26.4.2 (23E261) | French (`fr`) | `true` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:50 | iPhone / iOS 26.4.2 (23E261) | German (`de`) | `true` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 21:50 | iPhone / iOS 26.4.2 (23E261) | Spanish (`es`) | `true` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |

## モデル単位で見た挙動

### Latin 系モデル

- 該当ログ: English / French
- Asset key: `mul_Latn`
- modelIdentifier: `5C45D94E-BAB4-4927-94B6-8B5745C46289`
- dimension: `512`
- maximumSequenceLength: `256`
- English の初回 request 後に `hasAvailableAssets` が `true` になり、French でも同じ asset が使われているように見える。
- プロセス再起動後も English が即成功しているため、少なくとも同じ OS セッション内では asset が永続化または再利用されている。

### Hani 系モデル

- 該当ログ: Japanese / Simplified Chinese
- Asset key: `mul_Hani`
- modelIdentifier: `12784592-5D67-4F4C-83D6-A346519146AE`
- Japanese と Simplified Chinese は同じ asset を要求しているように見える。
- visionOS 26.4 ではどちらも `hasAvailableAssets == false` で、`requestAssets()` が timeout している。
- iOS 26.4.2 の iPhone 実機では Japanese / Simplified Chinese / Traditional Chinese / Korean が同じ modelIdentifier で成功している。
- ただし iPhone 実機では初期状態で `hasAvailableAssets == true` だったため、`requestAssets()` は呼ばれていない。
- 1回目 Japanese は約36秒、2回目 Japanese は約174秒、Simplified Chinese は約105秒で失敗しており、失敗までの時間は一定ではない。

## 気になるログ

English 初回 request 中に次のログが出ている。

```text
filesystem error: in create_directories: Operation not permitted ["/var/db/com.apple.naturallanguaged/com.apple.e5rt.e5bundlecache"]
```

ただし、その直後に English の `requestAssets()` は成功し、`load()` と smoke test も成功している。現時点では fatal error ではなく、NaturalLanguage daemon 側の内部ログとして扱うのが妥当。

プロセス再起動後の以下のログは、今回の embedding asset 判定とは直接関係が薄そう。

```text
nw_socket_copy_info ... Operation not supported on socket
FigAudioSession(AV) ... err=-19224
Called -[UIContextMenuInteraction updateVisibleMenuWithBlock:] while no context menu is visible.
```

## 次に visionOS beta で確認したいこと

Apple Developer の release notes 上では、次に試す候補は visionOS 26.5 beta 系。beta 版では NaturalLanguage 固有の修正が明示されていないため、実機で Hani 系 asset の挙動が変わるかを確認する。

iPhone 実機では Hani 系が利用可能だったため、visionOS beta で確認したい主眼は「Apple Vision Pro 上でも `mul_Hani` の `requestAssets()` が成功し、利用可能になるか」に絞れる。

おすすめの実行順:

1. OS 更新後、最初に Japanese を実行する。
2. Japanese が失敗した場合、すぐ Simplified Chinese を実行する。
3. English と French を実行し、Latin 系 asset が引き続き成功するか確認する。
4. アプリを終了して再起動し、Japanese / English を再実行する。
5. 可能なら本体再起動後にも Japanese を再実行する。

記録したい追加項目:

- visionOS の正確な version / build
- Xcode の version / build
- destination が native visionOS app か iPad/iPhone compatible app か
- ネットワーク種別と VPN / proxy / firewall の有無
- `requestAssets()` の開始から失敗または成功までの秒数
- Japanese と Simplified Chinese の `modelIdentifier` が変わるか
- Hani 系で `hasAvailableAssets after` が `true` になるか
- 成功した場合の dimension / maximumSequenceLength / sequenceLength

## 現時点の仮説

visionOS 26.4 (Build 23O247) では、少なくともこの Apple Vision Pro 環境において、Latin 系 `mul_Latn` asset は取得・利用可能だが、Hani 系 `mul_Hani` asset の download request が timeout している。

iOS 26.4.2 の iPhone 実機では、同じ Hani 系 modelIdentifier が Japanese / Chinese / Korean で即利用できている。ただし iPhone 側では asset が既に available だったため、download request の成否は確認できていない。

このため、問題は `NLContextualEmbedding` 全体の利用不可でも、Hani 系モデルそのものの欠落でもなく、visionOS / Apple Vision Pro 上での Hani 系 asset download request、配布、権限、キャッシュまわりに寄っている可能性が高い。
