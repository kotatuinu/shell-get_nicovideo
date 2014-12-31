# shellを使ったクッキーを使用するWebページの操作（Linux版）
ぶっちゃけ、PowerShellで作ったニコニコ動画から動画を取得するツールをshellで作ってみた。
あと、ニコニコ動画のマイリストURLから動画ページのURLを抽出するツールも作ってみた。
組み合わせればマイリストURLから動画を取得できます。

## 使い方
### 動画を取得するツール [get-nicovideo.sh]
ダウンロードしたい動画番号を指定して、出力先ディレクトリに出力します。
 出力ファイル名は、&lt;動画番号&gt;.mp4 となります。
`$ get-nicovideo.sh -u &lt;UserID&gt; -p &lt;Password&gt; &lt;Movie No&gt;[,&lt;Movie No&gt;...]`

* -u &lt;UserID&gt; : ニコニコ動画のユーザID
* -p &lt;Password&gt; : ニコニコ動画のユーザIDに対応するパスワード
* &lt;Movie No&gt; : ダウンロードしたい動画番号。カンマで区切ることで複数指定可能  標準入力も可

### マイリスト番号から動画URLを取得するツール [get_nicomylist.sh]
マイリスト番号からダウンロードしたい動画番号を指定して、出力先ディレクトリに出力します。
 出力ファイル名は、&lt;動画番号&gt;.mp4 となります。

`$ get_nicomylist.sh &lt;MyList No&gt;[,&lt;MyList No&gt;...]`
* &lt;MyList No&gt; : 動画番号を取得するマイリスト番号。カンマで区切ることで複数指定可能  標準入力も可


## 技術的覚書
shellで一通りのことをやってみた。
* shellプログラムの引数の処理（標準入力もできるようにする）
* 引数（標準入力）の値を配列に格納する方法
* 配列の要素数の判定
* 一時ファイルの作成・削除
* HTTPでデータを取得する方法（POST Requestの方法、Cookieを使う方法）
* 配列の要素ごとのループ
* 判定の方法（数値、文字列、ファイルのサイズ）

### ■引数の処理
以下、引数の処理部分の切りだし  
註）bashで実行する必要がある。

```shell
while getopts u:p: OPT
do
  case $OPT in
  "u" ) uid="${OPTARG}" ;;
  "p" ) passwd="${OPTARG}" ;;
  *   ) echo "Usage: $CMDNAME -u USERID -p PASSWORD [MOVIE_NO[,...]]"
    exit 1 ;;
  esac
done

shift `expr $OPTIND - 1`

#Movie No. from stdin OR Argument
if [ -p /dev/stdin ] ; then
  mlist=(`cat -`)
else
  mlist=(`echo $@ | tr -s ',' ' '`)
fi
if [ ${#mlist[@]} -eq 0 ] ; then
  echo "no entries."
  exit 1
fi
```

#### ●値を伴うオプション-oと-uの取得と判定を行う。
```shell
while getopts u:p: OPT
do
	case $OPT in
	"u" ) uid="${OPTARG}" ;;
	"p" ) passwd="${OPTARG}" ;;
	*   ) echo "Usage: $CMDNAME -u USERID -p PASSWORD [MOVIE_NO[,...]]"
		exit 1 ;;
	esac
done
```

#### ●オプションではない引数の取得（カンマ区切りを配列に格納）
オプション引数の後に、動画番号をカンマ区切りで渡されるので、配列に変換してmlist変数に入れる。  
丸括弧で括った中の文字列（空白で区切られている）は配列として扱われる。なのでカンマを空白に置き換えることで実現している。
```shell
shift `expr $OPTIND - 1`
mlist=(`echo $@ | tr -s ',' ' '`)
```

#### ●標準出力の取得（配列に格納）
標準入力はがあるかは、/dev/stdinのパイプ有無判定で分かる。  
標準入力の取得は、cat - で行う。配列化は上位と同じく、丸括弧で括ることで行える。
```shell
if [ -p /dev/stdin ] ; then
  mlist=(`cat -`)
fi
```
### ■配列の要素数の判定
配列変数の前に#を付ける。$mlist[@]もしくは、$mlist[*]で配列全体を示している。
```shell
if [ ${#mlist[@]} -eq 0 ] ; then
 echo "no entries."
 exit 1
fi
```

### ■一時ファイルの作成・削除
PIDをファイル名に入れることでユニークな一時ファイル名とする。"$$"がPIDとなる。  
trapコマンドで、第二引数に指定したシグナルが発行されたら、第一引数のコマンドを実行する。  
```shell
trap "rm /tmp/tmp_getnico.$$; rm /tmp/tmp_getnico2.$$; exit 1" 1 2 3 15
```
シグナルの意味は、以下。  
　 1:ターミナルクローズ  
　 2:Ctrl+c押下時の割込シグナル  
　 3:Ctrl+\押下時のクイットシグナル  
　15:プロセス終了シグナル（killコマンドデフォルトのシグナル）  

### ■HTTPでデータを取得する方法（POST Requestの方法、Cookieを使う方法）
ニコニコ動画から動画を取得するには以下の手順を行う。（重要なのはCookieの受け渡しとURLアクセス順）

1. ログイン状態にする（接続情報はCookieに保存）  
  https://secure.nicovideo.jp/secure/login?site=niconico に対して、POST Requestで以下のパラメタを渡す。  
    ・以下はユーザごとに可変  
      mail_tel=<ユーザID>  
      password=<パスワード>  
    ・以下は固定  
      next_url=
      show_button_facebook=0  
      show_button_twitter=0  
      nolinks=0  
      _use_valid_error_code=0  

2. ログインしているか確認：[必須ではない]
  http://www.nicovideo.jp/ にアクセスして、
  文字列'&lt; a href="http://www.nicovideo.jp/login"&gt;&lt;span&gt;ログイン&lt;/span&gt;&lt;/a &gt;'が無ければログイン成功  
3. 動画画面にアクセス（１の接続情報のあるCookieを渡して、もどってきたCookieを保存）  
  http://www.nicovideo.jp/watch/＜動画番号(sm|mn|)[0-9]+＞ にアクセス。

4. 動画情報を取得（２のCookieを渡す）  
  http://flapi.nicovideo.jp/api/getflv に対して、POST Requestで以下のパラメタを渡す。  
    v=＜動画番号(sm|mn|)[0-9]+＞

  GET Requestでも可能。
  http://flapi.nicovideo.jp/api/getflv?v=＜動画番号(sm|mn|)[0-9]+＞。

5. 動画情報にあるURLにアクセス（２のCookieを渡す）  
4で取得した内容から``url= ・・・ &``の間の文字列をURLエンコードしたURLにアクセスすると動画ファイルを取得できる。
URLエンコードすると言っても、以下のコードしか使われない（と思われる）。  
    * %2F → /  
    * %3A → :  
    * %3D → =  
    * %3F → &  

  なお、動画情報の内容は変化する。ユーザごとに変わるだろうし、同じユーザでも短時間に取得したときには変わらないみたいだけれど、何時までも同じとは限らない。

#### HTTPでデータを取得するにはcurlコマンドを使用。
cookieを取得するにはcurlコマンドの-cオプション（出力ファイル名を指定）を使用する。  
cookieを渡すにはcurlコマンドの-bオプション（入力ファイル名を指定）を使用する。  
POST Requestを渡すには、curlコマンドの-Fオプション（"&lt;key&gt;=&lt;value&gt;"形式で渡すデータを指定する。複数渡すときは、複数-Fオプションを指定する。）

+ 例：ログイン（POST Requestでユーザ名、パスワードなどを投げる）  
```shell
curl -s -F 'next_url=' -F 'show_button_facebook=0' -F 'show_button_twitter=0' -F 'nolinks=0' -F '_use_valid_error_code=0' -F "mail_tel=${uid}" -F "password=${passwd}" -c /tmp/tmp_getnico.$$ https://secure.nicovideo.jp/secure/login?site=niconico > /dev/null 2&gt;&1`
```

+ 例：動画画面にアクセスする
```shell
curl -s -b /tmp/tmp_getnico.$$ -c /tmp/tmp_getnico2.$$ "http://www.nicovideo.jp/watch/${movieno}" &gt; /dev/null 2>&1`
```

### 配列の要素ごとのループ
いわゆるforeach文を使う。for文の右辺には配列全体を示すため$mlist[@]とする。  
```shell
for movieno in "${mlist[@]}" ;
do
	echo ${movieno}
done
```

### 判定の方法（数値、文字列、ファイルのサイズ）
ここら辺は、他に詳しく説明しているサイトがあるので、そちらを見たほうがいい。:-p  
* 数値の判定は、  
 * 等しい：-eq  
```shell
if [ ${#mlist[@]} -eq 0 ] ; then  
```
 * 等しくない：-ne  
 * より大きい：-gt  
 * 以上： -ge  
 * より小さい：-lt  
 * 以下：-le  
* 文字列の判定は、  
 * 等しい：=  
  ↓これはcrulコマンドで取得した動画が削除されてファイルが取得できないとき、内容に403 Forbiddenとなるので、ファイルの中身を見て判定している。
```shell
if [ "`head -1 ${movieno}.mp4`" = "403 Forbidden" ] ; then
```
 * 等しくない：!=
* ファイルの判定は、
 * 0サイズより大：-s
 ↓これは取得したファイルが空（0バイト）の場合の判定。0バイトより大の判定に”!”を付けて否定にして、0バイトならファイルを消す処理とする判定。
```shell
if [ ! -s ${movieno}.mp4 ] ; then
```
 * ファイルがある：-f
 * ディレクトリがある：-d
 * パイプの有りか（標準入力されているか）：-p
```shell
if [ -p /dev/stdin ] ; then
```
