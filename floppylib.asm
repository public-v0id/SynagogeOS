section .text
floppycheckstatus:
	push ax
	push dx
	mov dl, 0x00
	mov ah, 0x15
	int 0x13
	cmp ah, 0x00
	jne .ins
	pop dx
	pop ax
	ret
.ins:
	push bx
	mov bx, floppydiskin
	call print_string
	pop bx
	pop dx
	pop ax
	ret

section .data
	floppydiskin db "Matzah inserted!", 0x0A, 0x0D, 0
