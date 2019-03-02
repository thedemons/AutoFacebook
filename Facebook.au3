#include-once
#include <_HttpRequest.au3>
#include "AutoitObject_Internal.au3"

Global Const $cLink_FB = "https://mbasic.facebook.com/"
Global Const $cLink_FBFull = "https://www.facebook.com/"
Global Const $cLink_Login = "login/device-based/regular/login/"
Global Const $cLink_Post = "composer/mbasic/?av="
Global Const $cLink_React = "api/graphql/"

Global Const $c_Header = 1
Global Const $c_Html = 2

Global Const $PRIVACY_FRIEND = "291667064279714"

Global Const $REACT_UNLIKE = 0
Global Const $REACT_LIKE = 1
Global Const $REACT_LOVE = 2
Global Const $REACT_WOW = 3
Global Const $REACT_HAHA = 4
Global Const $REACT_SAD = 7
Global Const $REACT_ANGRY = 8

Func Facebook($userName, $userPass = "")

	$isFromFile = FileExists($userName) ; if load from user & pass or from file
	If $userPass = False And $isFromFile = False Then Return False ; if neither, then return false

	If $isFromFile Then Return FB_LoadFromFile($userName)

	Return __CreateFB($userName, $userPass)
EndFunc

Func FB_LoadFromFile($File)

	$userName = IniRead($File, "facebook", "user", -1)
	$userPass = IniRead($File, "facebook", "pass", -1)
	$name = __Decode( IniRead($File, "facebook", "name", -1) )
	$uid = IniRead($File, "facebook", "uid", -1)
	$dtsg = IniRead($File, "facebook", "dtsg", -1)
	$cookie = IniRead($File, "facebook", "cookie", -1)

	If $userName = -1 Or $userPass = -1 Or $name = -1 Or $uid = -1 Or $dtsg = -1 Or $cookie = -1 Then Return False

	; create facebook
	$hFB = __CreateFB($userName, $userPass, $name, $uid, $dtsg, $cookie)
	$hFB.isLogin = True

	; check if cookie is still useable, if not then login
	If __CheckAlive($cookie) = False Then $hFB.login()

	Return $hFB
EndFunc

Func FB_SaveToFile($this)

	If $this.arguments.length = 0 Then Return False

	$File = $this.arguments.values[0]
	$hFB = $this.parent

	FileDelete($File)
	IniWrite($File, "facebook", "user", $hFB.user)
	IniWrite($File, "facebook", "pass", $hFB.pass)
	IniWrite($File, "facebook", "name", __Encode( $hFB.name ))
	IniWrite($File, "facebook", "uid", $hFB.uid)
	IniWrite($File, "facebook", "dtsg", $hFB.dtsg)
	IniWrite($File, "facebook", "cookie", $hFB.cookie)

	Return True
EndFunc

Func FB_Login($this)

	$hFB = $this.parent
	If __CheckFB($hFB) = False Then Return False

	; assign variable
	$userName = $hFB.user
	$userPass = $hFB.pass

	; make a request to homepage to get cookie
	$Request = _HttpRequest($c_Html, $cLink_FB)
	$cookie = _GetCookie($Request)

	; username and password
	$loginData = __GetLoginPost($Request, $userName, $userPass)

	; login
	$Request = _HttpRequest($c_Html, $cLink_FB & $cLink_Login, $loginData, $cookie)
	$cookie = _GetCookie($Request)
	$name = __GetLoginName($Request)
	$dtsg = __GetLoginDTSG($Request)
	$uid = __GetUserID($cookie)

	; login failed
	If $uid = False Then
		$hFB.isLogin = False
		Return False
	EndIf

	; set data to hfb
	$hFB.name = $name
	$hFB.uid = $uid
	$hFB.dtsg = $dtsg
	$hFB.cookie = $cookie
	$hFB.isLogin = True

	Return True
EndFunc

Func FB_Post($this)

	If $this.arguments.length = 0 Then Return False

	$hFB = $this.parent
	$post = $this.arguments.values[0]
	$privacy = $this.arguments.length < 2 ? $PRIVACY_FRIEND : $this.arguments.values[1]

	If __CheckFB($hFB) = False Then Return False

	$dataPost = "fb_dtsg=" & _URIEncode($hFB.dtsg)
	$dataPost &= "&privacyx=" & $privacy
	$dataPost &= "&target=" & $hFB.uid
	$dataPost &= "&xc_message=" & _URIEncode($post)
	$dataPost &= "&c_src=feed&cwevent=composer_entry&referrer=feed&ctype=inline&cver=amber&view_post=%C4%90%C4%83ng"

	$Request = _HttpRequest(2, $cLink_FB & $cLink_Post & $hFB.uid, $dataPost, $hFB.cookie)

	$PostID = __GetPostIDRecent($Request)

	If $PostID = False Then Return False

	Return $PostID
EndFunc

Func FB_React($this)

	If $this.arguments.length = 0 Then Return False

	$hFB = $this.parent
	$PostID = $this.arguments.values[0]
	$React = $this.arguments.length = 0 ? $REACT_LIKE : $this.arguments.values[1]

	If __CheckFB($hFB) = False Then Return False

	$dataPost = "av={UID}&fb_dtsg={DTSG}&fb_api_req_friendly_name=UFI2FeedbackReactMutation&variables=%7B%22input%22%3A%7B%22client_mutation_id%22%3A%226%22%2C%22actor_id%22%3A%22{UID}%22%2C%22feedback_id%22%3A%22{POSTID}%22%2C%22feedback_reaction%22%3A{REACT}%7D%2C%22useDefaultActor%22%3Atrue%7D&doc_id=1853002534829264"
	$dataPost = StringReplace($dataPost, "{UID}", $hFB.uid)
	$dataPost = StringReplace($dataPost, "{DTSG}", _URIEncode($hFB.dtsg))
	$dataPost = StringReplace($dataPost, "{POSTID}", _B64Encode("feedback:" & $PostID))
	$dataPost = StringReplace($dataPost, "{REACT}", $React)

	$Request = _HttpRequest(2, $cLink_FBFull & $cLink_React, $dataPost, $hFB.cookie)

	; check if success
	If StringInStr($Request, "reaction_type") Then Return True
	Return False
EndFunc

Func __CreateFB($userName, $userPass, $name = False, $uid = False, $dtsg = False, $cookie = False)

	Local $hFB = IDispatch()
	$hFB.user = $userName
	$hFB.pass = $userPass
	$hFB.name = $name ; name
	$hFB.uid = $uid ; user id
	$hFB.dtsg = $dtsg ; dtsg
	$hFB.cookie = $cookie ; cookie
	$hFB.isLogin = False

	$hFB.__defineGetter('login', FB_Login)
	$hFB.__defineGetter('post', FB_Post)
	$hFB.__defineGetter('react', FB_React)
	$hFB.__defineGetter('save', FB_SaveToFile)
	Return $hFB
EndFunc

Func __CheckFB($hFB)
	If IsObj($hFB) = False Or $hFB.user = False Or $hFB.pass = False Then Return False
	Return True
EndFunc

Func __CheckAlive($cookie)

	$Request = _HttpRequest($c_Html, $cLink_FB, "", $cookie)
	If StringInStr($Request, "m_newsfeed_stream") = False Then Return False

	Return True
EndFunc

Func __GetUserID($Cookie)

	$uid = StringRegExp($cookie, "c_user=(.*?);", 1)
	If IsArray($uid) = False Then Return False ; login failed

	Return $uid[0]
EndFunc

Func __GetLoginName($Request)

	$name = StringRegExp($Request, 'img src="(.*?)\>', 3)
	If IsArray($name) = False Then Return False

	$name = StringRegExp( $name[1], 'alt="(.*?)"', 1)
	If IsArray($name) = False Then Return False

	Return __Decode($name[0])
EndFunc

Func __GetLoginDTSG($Request)
	$dtsg = StringRegExp($Request, 'name="fb_dtsg" value="(.*?)"', 1)
	If IsArray($dtsg) = False Then Return False
	Return $dtsg[0]
EndFunc

Func __GetLoginPost($Request, $userName, $userPass)

	$lsd = StringRegExp($Request, 'name="lsd" value="(.*?)"', 1)
	$jazoest = StringRegExp($Request, 'name="jazoest" value="(.*?)"', 1)
	$m_ts = StringRegExp($Request, 'name="m_ts" value="(.*?)"', 1)
	$li = StringRegExp($Request, 'name="li" value="(.*?)"', 1)

	; check
	If IsArray($lsd) = False Or IsArray($jazoest) = False Or IsArray($m_ts) = False Or IsArray($li) = False Then Return False

	Return "lsd=" & $lsd[0] & "&jazoest=" & $jazoest[0] & "&m_ts=" & $m_ts[0] & "&li=" & $li[0] &"&try_number=0&unrecognized_tries=0&email=" & _URIEncode($userName) & "&pass=" & _URIEncode($userPass)
EndFunc

Func __GetPostIDRecent($Request)
	$id = StringRegExp($Request, "&quot;top_level_post_id&quot;:&quot;(.*?)&quot;", 1)
	If IsArray($id) = False Then Return False
	Return $id[0]
EndFunc

Func __Decode($str)

	$chars = StringRegExp($str, "&#x(.*?);", 3)
	If IsArray($chars) = False Then Return False

	For $iChr = 0 To UBound($chars) - 1
		If $chars[$iChr] = "" Then ContinueLoop
		$chr = ChrW( "0x" & $chars[$iChr] )
		$str = StringRegExpReplace($str, "&#x" & $chars[$iChr] & ";", $chr)
	Next

	Return $str
EndFunc

Func __Encode($str)

	$len = StringLen($str)

	For $i = $len To 1 Step - 1

		$chr = StringMid($str, $i, 1)
		$asc = Asc($chr)

		; if unicode
		If Chr($asc) = $chr Then ContinueLoop

		$str = StringReplace($str, $i, @LF)
		$str = StringReplace($str, @LF, "&#x" & Hex(AscW($chr), 4) & ";")
	Next

	Return $str
EndFunc