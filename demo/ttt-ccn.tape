# Regenerate docs/demo.gif with VHS:
#   vhs demo/ttt-ccn.tape
#
# Requires: ttt, ccn, and this repo copied to <workspace>/plugins/ccn.
Output demo/ttt-ccn.gif

Set Shell "powershell"
Set Width 120
Set Height 34
Set FontSize 16
Set Padding 12
Set TypingSpeed 35ms

Type "ttt . demo/demo.c"
Enter
Sleep 4s
Sleep 2s
# Click the first function in the right drawer if needed; the drawer opens
# automatically for the first supported file.
Sleep 4s
Escape
Sleep 500ms
Ctrl+P
Type "CCN: Open inspector"
Enter
Sleep 2s
Sleep 3s
