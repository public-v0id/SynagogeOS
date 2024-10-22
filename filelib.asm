%DEFINE fnamelength 12

section .text
setfilename:		;Принимает в bx указатель на файл, в si - указатель на название
	push ax
	push bx
	push dx
	push si
	xor ax, ax
	add bx, 1
	xor dx, dx
;	call newline
.loop:
	cmp ax, fnamelength+1
	je .end
	mov dl, byte[si]
;	call print_hex
	mov byte[bx], dl
	inc ax
	inc bx
	inc si
	jmp .loop
.end:
	pop si
	pop dx
	pop bx
	pop ax
;	call newline
	ret
