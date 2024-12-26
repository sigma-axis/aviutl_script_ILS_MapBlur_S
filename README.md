# Inline Scene Mapped Blur_S AviUtl スクリプト

[Inline Scene S](https://github.com/sigma-axis/aviutl_script_InlineScene_S) で保存したキャッシュ画像で，位置ごとに大きさや方向の違うぼかし効果，マップブラーを適用するスクリプト．

被写界深度のような効果や風で流れるようなぼかしが可能です．

[ダウンロードはこちら．](https://github.com/sigma-axis/aviutl_script_ILS_MapBlur_S/releases) \[紹介動画準備中...\]

![マップブラーのデモ1](https://github.com/user-attachments/assets/5642a14b-f5c4-483b-8d8b-769f49b799e0) ![マップブラーのデモ2](https://github.com/user-attachments/assets/fc1c579d-dc93-4947-b4ba-726b6280cb23)

## 動作要件

- AviUtl 1.10 (1.00 など他バージョンでは動作不可)

  http://spring-fragrance.mints.ne.jp/aviutl

- 拡張編集 0.92

  - 0.93rc1 など他バージョンでは動作不可．

- patch.aul (謎さうなフォーク版)

  https://github.com/nazonoSAUNA/patch.aul

- [LuaJIT](https://luajit.org/)

  バイナリのダウンロードは[こちら](https://github.com/Per-Terra/LuaJIT-Auto-Builds/releases)からできます．

  - 拡張編集 0.93rc1 同梱の `lua51jit.dll` は***バージョンが古く既知のバグもあるため非推奨***です．
  - AviUtl のフォルダにある `lua51.dll` と置き換えてください．

- GLShaderKit

  https://github.com/karoterra/aviutl-GLShaderKit

- Inline Scene S の導入

  https://github.com/sigma-axis/aviutl_script_InlineScene_S

## 導入方法

以下のフォルダに `@ILS_MapBlur_S.anm` と `ILS_MapBlur_S.lua` の 2 つのファイルをコピーしてください．

- `InlineScene_S.lua` のあるフォルダ

  [Inline Scene S](https://github.com/sigma-axis/aviutl_script_InlineScene_S) の導入先のフォルダです．

> [!TIP]
> 正確には「`require "InlineScene_S` の構文で `InlineScene_S.lua` が見つかること」が条件なので，例えば `InlineScene_S.lua` が `script` フォルダに配置されているなどの場合は，`script` フォルダ内の任意の名前のフォルダでも可能です．
>
> `patch.aul.json` で `"switch"` 以下の `"lua.path"` を `true` にすることで，`module` フォルダに `InlineScene_S.lua` を配置する方法も可能です（ただし一部 rikky_module.dll を使うスクリプトなどが動かなくなる報告もあります）．
>
> 詳しくは [Lua 5.1 の `require` の仕様](https://www.lua.org/manual/5.1/manual.html#5.3)と拡張編集のスクリプトの仕様を参照してください．

## 使い方

[`Inline Sceneここまで`](https://github.com/sigma-axis/aviutl_script_InlineScene_S?tab=readme-ov-file#inline-scene%E3%81%93%E3%81%93%E3%81%BE%E3%81%A7) や [`Inline Scene単品保存`](https://github.com/sigma-axis/aviutl_script_InlineScene_S?tab=readme-ov-file#inline-scene%E5%8D%98%E5%93%81%E4%BF%9D%E5%AD%98) などでキャッシュが保存されている状態で，オブジェクトに [`Mapped Blur`](#mapped-blur) のアニメーション効果を適用すると，キャッシュ画像の色に応じた方向に沿って現在オブジェクトにぼかし効果がかかります．

マップ元画像の R(赤), G(緑), B(青) の各チャンネルのうち，R が X 軸方向，G が Y 軸方向のぼかしに寄与します．通常は $(R, G) = (128, 128)$ が基準色になり，ぼかしのない「無風」に相当します．この基準色から離れるほど強いぼかしになります．B のチャンネルは直交方向への寄与に影響します([`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) での調整が必要).

![各色チャンネルと方向との対応](https://github.com/user-attachments/assets/a35ad537-9997-4ea2-ba7f-890af22a0425)

通常はマップ元画像が対象画像に合わせて拡縮されて適用されます．マップ元画像の位置や回転角度，サイズなどを変更・調整する場合は，[`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) や [`Mapped Blur設定(サイズ指定)`](#mapped-blur設定サイズ指定) を `Mapped Blur` の直前に適用してください．

また，マップ元画像の基準色を調整したり，マップ元画像にぼかしを加えたい場合は [`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) を `Mapped Blur` の直前に適用してください．

![設定は連続して配置](https://github.com/user-attachments/assets/31bfc3c2-cbb4-4c01-9053-80c85b0f42ff)

各アニメーション効果の「設定」にある `PI` は parameter injection です．初期値は `nil`. テーブル型を指定すると `obj.check0` や `obj.track0` などの代替値として使用されます．また，任意のスクリプトコードを実行する記述領域にもなります．

```lua
_0 = {
  [0] = check0, -- boolean または number (~= 0 で true 扱い). obj.check0 の代替値．それ以外の型だと無視．
  [1] = track0, -- number 型．obj.track0 の代替値．tonumber() して nil な場合は無視．
  [2] = track1, -- obj.track1 の代替値．その他は [1] と同様．
  [3] = track2, -- obj.track2 の代替値．その他は [1] と同様．
  [4] = track3, -- obj.track3 の代替値．その他は [1] と同様．
}
```

### `Mapped Blur`

マップブラーを適用するアニメーション効果です．

この直前に [`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) や [`Mapped Blur設定(サイズ指定)`](#mapped-blur設定サイズ指定) がかけられていた場合，そこで指定された位置や回転角度，サイズ等の設定も適用されます．これらがない場合は，マップ元画像を対象画像のサイズに合わせて拡縮して適用します．

#### 設定値
1.  `順方向`

    マップ元画像の色で指定された方向へのぼかし量をピクセル単位で指定します．最小値は `-2000`, 最大値は `2000`, 初期値は `16`.

    マップ元画像の色が基準色から離れるほど強いぼかしに，基準色に近いほど弱いぼかしなります．

1.  `直交方向`

    「マップ元画像の色で指定された方向」と直交する方向へのぼかし量をピクセル単位で指定します．最小値は `0`, 最大値は `2000`, 初期値は `0`.

    直交方向へのぼかし量も，マップ元画像の色が基準色から離れるほど強いぼかしに，基準色に近いほど弱いぼかしなります．また [`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) で `B直交` を調整していると，元画像の B 成分の大きさにも影響します．

1.  `角度`

    通常はマップ元画像の R(赤), G(緑), B(青) の各チャンネルのうち，R が X 軸方向，G が Y 軸方向へのぼかしに寄与しますが，その方向を回転します．単位は度数法で時計回りに正．最小値は `-720`, 最大値は `720`, 初期値は `0`.

1.  `相対位置`

    ぼかしが広がる範囲の起点を指定します．

    `0` で順方向の前後に同じ量だけ広がります．`+100` で順方向の前方向にだけ広がります．`-100` で順方向の後ろ方向にだけ広がります．

    ![相対位置の影響](https://github.com/user-attachments/assets/70d02fa8-b22d-4844-ab7e-df09915d7f57)

    最小値は `-100`, 最大値は `100`, 初期値は `0`.

1.  `サイズ固定`

    ぼかし効果によって画像サイズが大きくならないようにします．初期値は ON.

1.  `ILシーン名`

    マップ用のキャッシュ画像を表す，`Inline Scene単品保存` などで指定した `ILシーン名` を指定します．初期値は `scn1`.

1.  `現在フレーム`

    ON の場合，inline scene がそのフレーム描画中に保存されたものでないときにはマップブラーを適用しません．初期値は OFF.

1.  `枠外延伸`

    マップ元画像の外側の解釈方法を選択します:

    1.  OFF だとマップ元画像の外側は完全透明ピクセルと同等（「無風」状態）に扱われます．
    1.  ON だとマップ元画像の外側は，最も近い内側にあるピクセルと同じ色で埋められているものとして扱われます．

    ![枠外延伸の効果](https://github.com/user-attachments/assets/a438b8c1-e3ce-4285-aa9f-33299a71cedb)

1.  `精度`

    計算手順の回数を指定します．大きいほどなめらかな計算結果になりますが，`順方向` や `直交方向` を超えているならそれ以上上げても大きな変化にはなりません．(描画回数 - 1) の値を指定．最小値は `1`, 初期値は `256`.

### `Mapped Blur設定(拡大率指定)`
[`Mapped Blur`](#mapped-blur) のマップ元画像の位置，回転角度，拡大率を指定します．`Mapped Blur` または [`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) の直前に配置してください．

#### 設定値
1.  `X` / `Y`

    マップ元画像の位置を指定します．アンカーをマウス移動でも調整可能です．最小値は `-2000`, 最大値は `2000`, 初期値は原点 $(0, 0)$.

1.  `回転`

    マップ元画像の回転角度を指定します．度数法で時計回りが正．最小値は `-720`, 最大値は `720`, 初期値は `0`.

1.  `拡大率`

    マップ元画像の拡大率を % 単位で指定します．最小値は `0`, 最大値は `1600`, 初期値は `100`.

1.  `回転に角度を追従`

    `回転` に応じてぼかしの方向も回転するようになります．初期値は ON.

### `Mapped Blur設定(サイズ指定)`
[`Mapped Blur`](#mapped-blur) のマップ元画像の位置，回転角度，サイズを指定します．`Mapped Blur` または [`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) の直前に配置してください．

[`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) とは `拡大率` と `サイズ` 以外の項目は同等です．

#### 設定値
1.  `サイズ`

    マップ元画像のサイズの長辺をピクセル単位で指定します．最小値は `0`, 最大値は `4000`, 初期値は `200`.

1.  その他の設定値

    [`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) と同等です．

### `Mapped Blur設定(基準色指定)`
[`Mapped Blur`](#mapped-blur) のマップ元画像の基準色や B(青) 成分の取り扱い，ぼかしの設定をします．`Mapped Blur`, [`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) または [`Mapped Blur設定(サイズ指定)`](#mapped-blur設定サイズ指定) の直前に配置してください．

#### 設定値
1.  `R基準` / `G基準`

    基準色の R(赤), G(緑) 成分をそれぞれ指定します．R, G 成分が基準色の色はぼかしなしとして取り扱われ，この色から離れるほどぼかしが強くなります．最小値は `-255`, 最大値は `510`, 初期値は $(R, G) = (128, 128)$.

1.  `B直交`

    `Mapped Blur` の設定の `直交方向` のぼかしに対して，B(青) 成分の寄与量を % 単位で指定します．

    - `0` だと B 成分によらず `直交方向` だけのぼかし量になります．
    - `100` だと B 成分に比例する量だけ直交方向のぼかしがかかるようになります $B = 255$ で `直交方向` と同量になります．
    - `0` から `100` の間は，上記 2 つのぼかし量を線形に補間した値になります．

    最小値は `0`, 最大値は `100`, 初期値は `0`.

1.  `ぼかし`

    マップ元画像にぼかしを設定します．ピクセル単位．最小値は `0`, 最大値は `200`, 初期値は `5`.

1.  `RG均一化(Rのみで指定)`

    ON の場合 `G基準` は無視され，代わりに `R基準` が `G基準` の値として振舞うようになります．この 2 つの値を同期したい場合に有効です．初期値は OFF.

## TIPS

1.  [`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定) と [`Mapped Blur設定(サイズ指定)`](#mapped-blur設定サイズ指定) を同時に指定した場合は，最後に指定したものの効果が優先されます．

1.  [`Mapped Blur設定(拡大率指定)`](#mapped-blur設定拡大率指定), [`Mapped Blur設定(サイズ指定)`](#mapped-blur設定サイズ指定), [`Mapped Blur設定(基準色指定)`](#mapped-blur設定基準色指定) の 3 つは，[`Mapped Blur`](#mapped-blur) と別々のオブジェクトに配置されていた場合は機能しません (例: オブジェクトに `Mapped Blur設定(拡大率指定)`, グループ制御に `Mapped Blur`).

1.  `順方向` と `直交方向` を同じ値に指定すると，方向のない，位置で強さの変わるぼかしになります．マップ元画像を，奥行きを明るさで記録したものとして用意し基準色を調整することで，被写界深度のような表現ができます．

1.  テキストエディタで `@ILS_MapBlur_S.anm`, `ILS_MapBlur_S.lua` を開くと冒頭付近にファイルバージョンが付記されています．

    ```lua
    --
    -- VERSION: v1.00
    --
    ```

    ファイル間でバージョンが異なる場合，更新漏れの可能性があるためご確認ください．


## 改版履歴

- **v1.00** (2024-12-??)

  - 初版．


## ライセンス

このプログラムの利用・改変・再頒布等に関しては MIT ライセンスに従うものとします．

---

The MIT License (MIT)

Copyright (C) 2024 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://mit-license.org/


# Special Thanks

このスクリプトの実装やパラメタ配分に当たっては Mr-Ojii 様のスクリプト RotBlur_M を参考にさせていただきました．この場を借りて感謝申し上げます．

https://github.com/Mr-Ojii/AviUtl-RotBlur_M-Script


#  連絡・バグ報告

- GitHub: https://github.com/sigma-axis
- Twitter: https://x.com/sigma_axis
- nicovideo: https://www.nicovideo.jp/user/51492481
- Misskey.io: https://misskey.io/@sigma_axis
- Bluesky: https://bsky.app/profile/sigma-axis.bsky.social
