section .text

delay:			;Ввод - cx:dx - время в микросекундах
	push ax
	mov ax, 0x8600
	int 0x15
	pop ax
	ret

get_date:		;Вывод - CX:DX - дата
	mov ah, 0x04
	int 0x1A	;CX:DX (0x2024:0x1007)
	ret
