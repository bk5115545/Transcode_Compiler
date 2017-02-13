.stack 64
.data
x SDWORD 0
.code
add eax, 2
add eax, 2
mov x, eax
mov ah, 9
mov edx, x
int 21h
