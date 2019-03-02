#include "Facebook.au3"

Local $fbFile = "account.fb"
Local $email = "spamdang07@gmail.com"
Local $pass = "14256789"

Local $hFB
;~ ; if file isn't exists yet, then create it
If FileExists( $fbFile ) = False Then

	; create facebook from username and password
	$hFB = Facebook($email, $pass)
	$hFB.login()

Else
	; create facebook from file, this will automaticly log in
	$hFB = Facebook($fbFile)
EndIf

If $hFB.isLogin = False Then
	MsgBox(0, "", "Login failed")
	Exit
EndIf

$postID = $hFB.post("TEST POST)
$hFB.react($postID, $REACT_LOVE)
$hFB.save($fbFile)

