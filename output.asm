.stack

.model flat

.data
x SDWORD 0

.code
; add 2 and 2
; store into x
add eax, 2
add eax, 2
mov x, eax

; print x
mov ah, 9
mov edx, x
int 21h

