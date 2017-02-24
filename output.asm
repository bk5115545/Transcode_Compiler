.data
x SDWORD 5

.code
main PROC
    ; add 2 and 4
    ; store into x
    mov eax, 2
    add eax, 4
    mov x, eax

    mov eax, x
    add eax, 5
    mov x, eax
main ENDP

END
