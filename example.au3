#include <Array.au3>
#include "Facebook.au3"

Local $fbFile = "account.fb"
Local $email = "spamdang09@gmail.com"
Local $pass = "14256789a"

Local $hFB
;~ ; if file isn't exists yet, then log in
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

$Friends = $hFB.getAllFriends() ; [Friend_ID, Friend_name, Friend_img]
$Groups = $hFB.getAllGroups() ; [Group_ID, Group_name]

; Send message and post in group
;~ $hFB.sendMes($Friends[0][0], "Hello")
;~ $hFB.postGroup($Groups[0][0], "Post in group")

_ArrayDisplay($Friends)

$hFB.save($fbFile)

