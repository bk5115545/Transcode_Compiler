
section .data
x DB 5

global _start
section .text
_start:

; add 2 and 4
; store into x
mov eax, 2
add eax, 4
mov [rel x], eax

mov eax, [rel x]
add eax, 5
mov [rel x], eax

ret
