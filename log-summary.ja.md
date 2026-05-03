# log.txt 整理メモ

## 検証環境

- Device: Apple Vision Pro
- OS: visionOS 26.4 (Build 23O247)
- Beta OS: visionOS 26.5 (Build 23O5468a)
- Comparison device: iPhone
- Comparison OS: iOS 26.4.2 (Build 23E261)
- 対象 API: `NLContextualEmbedding(language:)`
- ログ対象: asset availability、`load()`、`requestAssets()`、`embeddingResult(for:language:)`

## 結論

現在のログでは、Apple Vision Pro 上で Latin 系の contextual embedding asset は取得・利用できている一方で、Hani 系の asset は取得できていません。この挙動は visionOS 26.4 だけでなく visionOS 26.5 beta (Build 23O5468a) でも再現している。

- English は初回 `hasAvailableAssets == false` から `requestAssets()` 後に利用可能になった。
- English はその後の再実行とプロセス再起動後も `hasAvailableAssets == true` で、`load()` が即成功している。
- French も同じ Latin 系モデルを使っており、English の asset 取得後は `load()` が即成功している。
- Japanese と Simplified Chinese は同じ Hani 系モデルを使っており、`requestAssets()` が `NLNaturalLanguageErrorDomain 7: Asset download request timed out` で失敗している。
- `load()` 前に asset がない場合の `NLNaturalLanguageErrorDomain 8: Failed to locate embedding model` は、asset 未取得時の期待される失敗として扱える。
- visionOS 26.5 beta では English の `hasAvailableAssets` は `true` だったが、初回 `load()` は `Embedding model requires compilation` で失敗し、`requestAssets()` 後に成功した。Latin 系では compilation / cache 更新経路は動いているように見える。

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

## visionOS 26.5 beta での結果

| 時刻 | Device / OS | Language | 初期 asset | requestAssets | load / smoke test | modelIdentifier |
| --- | --- | --- | --- | --- | --- | --- |
| 22:04 | Apple Vision Pro / visionOS 26.5 (23O5468a) | Japanese (`ja`) | `false` | 約305秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 22:09 | Apple Vision Pro / visionOS 26.5 (23O5468a) | Simplified Chinese (`zh-Hans`) | `false` | 約306秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 22:17 | Apple Vision Pro / visionOS 26.5 (23O5468a) | Japanese (`ja`) | `false` | user cancel | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 22:18 | Apple Vision Pro / visionOS 26.5 (23O5468a) | English (`en`) | `true` | 約1秒で返却、`rawValue: 0` | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 22:19 | Apple Vision Pro / visionOS 26.5 (23O5468a) | French (`fr`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 22:19 | Apple Vision Pro / visionOS 26.5 (23O5468a) | German (`de`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 22:19 | Apple Vision Pro / visionOS 26.5 (23O5468a) | Spanish (`es`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |
| 22:20 | Apple Vision Pro / visionOS 26.5 (23O5468a), process restarted | Japanese (`ja`) | `false` | 約306秒で timeout | 未実施 | `12784592-5D67-4F4C-83D6-A346519146AE` |
| 22:27 | Apple Vision Pro / visionOS 26.5 (23O5468a), process restarted | English (`en`) | `true` | 不要 | 成功 | `5C45D94E-BAB4-4927-94B6-8B5745C46289` |

## モデル単位で見た挙動

### Latin 系モデル

- 該当ログ: English / French
- Asset key: `mul_Latn`
- modelIdentifier: `5C45D94E-BAB4-4927-94B6-8B5745C46289`
- dimension: `512`
- maximumSequenceLength: `256`
- English の初回 request 後に `hasAvailableAssets` が `true` になり、French でも同じ asset が使われているように見える。
- プロセス再起動後も English が即成功しているため、少なくとも同じ OS セッション内では asset が永続化または再利用されている。
- visionOS 26.5 beta 更新後、English は `hasAvailableAssets == true` でも `Embedding model requires compilation` で一度 `load()` が失敗し、`requestAssets()` 後に成功している。OS build ごとの compile cache 更新が発生している可能性がある。

### Hani 系モデル

- 該当ログ: Japanese / Simplified Chinese
- Asset key: `mul_Hani`
- modelIdentifier: `12784592-5D67-4F4C-83D6-A346519146AE`
- Japanese と Simplified Chinese は同じ asset を要求しているように見える。
- visionOS 26.4 ではどちらも `hasAvailableAssets == false` で、`requestAssets()` が timeout している。
- visionOS 26.5 beta でも Japanese / Simplified Chinese は `hasAvailableAssets == false` で、`requestAssets()` が約5分後に timeout している。
- visionOS 26.5 beta でプロセス再起動後に Japanese を再実行しても、`hasAvailableAssets == false` かつ timeout のまま。
- iOS 26.4.2 の iPhone 実機では Japanese / Simplified Chinese / Traditional Chinese / Korean が同じ modelIdentifier で成功している。
- ただし iPhone 実機では初期状態で `hasAvailableAssets == true` だったため、`requestAssets()` は呼ばれていない。
- 1回目 Japanese は約36秒、2回目 Japanese は約174秒、Simplified Chinese は約105秒で失敗しており、失敗までの時間は一定ではない。

## 気になるログ

English 初回 request 中に次のログが出ている。

```text
filesystem error: in create_directories: Operation not permitted ["/var/db/com.apple.naturallanguaged/com.apple.e5rt.e5bundlecache"]
```

ただし、その直後に English の `requestAssets()` は成功し、`load()` と smoke test も成功している。現時点では fatal error ではなく、NaturalLanguage daemon 側の内部ログとして扱うのが妥当。

visionOS 26.5 beta の English 初回 load では、build 番号付き cache path に対して同系統の permission error が出ている。

```text
Failed to load embedding from MIL representation: filesystem error: in create_directories: Operation not permitted ["/var/db/com.apple.naturallanguaged/com.apple.e5rt.e5bundlecache/23O5468a"]
Embedding model requires compilation
```

この後 `requestAssets()` は約1秒で成功し、English の smoke test も成功している。Latin 系ではこの cache / compilation 経路は回復可能だが、Hani 系は asset 自体を取得できていない。

プロセス再起動後の以下のログは、今回の embedding asset 判定とは直接関係が薄そう。

```text
nw_socket_copy_info ... Operation not supported on socket
FigAudioSession(AV) ... err=-19224
Called -[UIContextMenuInteraction updateVisibleMenuWithBlock:] while no context menu is visible.
```

## 次に確認したいこと

visionOS 26.5 beta でも Hani 系の結果は変わらなかった。次は追加検証よりも Feedback Assistant に出すための再現条件整理に寄せる。

おすすめの実行順:

1. 本体再起動後、Japanese を1回だけ再実行する。
2. 同じネットワークで English を実行し、Latin 系が成功することを併記する。
3. 可能なら別ネットワークで Japanese を1回だけ再実行する。
4. Xcode version / build と destination variant を記録する。
5. その結果を添えて Feedback Assistant に提出する。

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

visionOS 26.4 (Build 23O247) と visionOS 26.5 beta (Build 23O5468a) では、少なくともこの Apple Vision Pro 環境において、Latin 系 `mul_Latn` asset は取得・利用可能だが、Hani 系 `mul_Hani` asset の download request が timeout している。

iOS 26.4.2 の iPhone 実機では、同じ Hani 系 modelIdentifier が Japanese / Chinese / Korean で即利用できている。ただし iPhone 側では asset が既に available だったため、download request の成否は確認できていない。

このため、問題は `NLContextualEmbedding` 全体の利用不可でも、Hani 系モデルそのものの欠落でもなく、visionOS / Apple Vision Pro 上での Hani 系 asset download request、配布、権限、キャッシュまわりに寄っている可能性が高い。26.5 beta でも改善していないため、OS 更新で解消済みの問題とは言いにくい。
