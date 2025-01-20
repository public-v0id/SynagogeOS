date_to_hex:		;DX - аргумент, DX:AX - вывод. Использует ax, bx и cx
	push bx
	push cx
	push 0xFFFF
	mov bx, 0x000A
.loop:
	mov ax, dx
	and dx, 0x000F
	push dx
	mov dx, ax
	shr dx, 4
	cmp dx, 0
	je .conv
	jmp .loop
.conv:
	xor ax, ax
.convloop:
	pop cx
	cmp cx, 0xFFFF
	je .end
	imul bx
	add ax, cx
	adc dx, 0x0000
	jmp .convloop
.end:
	pop cx
	pop bx
	ret

day_of_week:		;Вывод в ax. Считает сегодняшний день недели
	push bx
	push cx
	push dx
	call get_date	;Получаем год  в cx
	mov dx, cx
	mov dl, dh
	mov dh, 0x00
	call date_to_hex;Шестнадцатиричный вариант последних двух цифр года
	mov [c], ax
	call get_date	;Получаем год  в cx
	and cx, 0x00FF
	mov dx, cx
	call date_to_hex;Шестнадцатиричный вариант последних двух цифр года
	mov [y], ax
	call get_date	;Получаем месяц в dh
	mov dl, dh
	mov dh, 0
	call date_to_hex;Шестнадцатиричный вариант последних двух цифр года
	mov [month], ax
	call get_date	;Получаем месяц в dl
	and dx, 0x00FF
	call date_to_hex;Шестнадцатиричный вариант последних двух цифр года
	mov [day], ax
	mov dx, ax
	xor dx, dx
	mov dx, [month]
	mov dx, [c]
	mov dx, [y]
	mov ax, [month]
	cmp ax, 2
	jle .janfeb
.cont1:
	mov cx, [day]
	add cx, [y]
	sub cx, [c]
	sub cx, [c]
	mov dx, [y]
	shr dx, 2
	add cx, dx
	mov dx, [c]
	shr dx, 2
	add cx, dx
	mov ax, [month]
	inc ax
	mov bx, 0x000D
	imul bl
	mov bx, 0x0005
	idiv bl
	and ax, 0x00FF
	add cx, ax
	mov bx, 0x0007
	mov ax, cx
	xor dx, dx
	idiv bx
	mov ax, dx
	pop dx
	pop cx
	pop bx
	ret
.janfeb:
	add ax, 12
	mov [month], ax
	mov ax, [y]
	dec ax
	cmp ax, 0xFFFF
	jne .saveyear
	mov word[y], 0x0063
	mov ax, [c]
	dec ax
	mov [c], ax
	jmp .cont1
.saveyear:
	mov [y], ax
	jmp .cont1

c: dw 0x0000
y: dw 0x0000
month: dw 0x0000
day: dw 0x0000
res: dw 0x0000
