global delay

section .text
delay:			;cx:dx - время в микросекундах
	push ax
	mov ax, 0x8600
	int 0x15
	pop ax
	ret
