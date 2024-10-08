%DEFINE endline	0x0A
%DEFINE car_ret 0x0D

;global set_videomode
;global cls
;global newline
;global print_char
;global print_string
;global clear_buf
;global cls_col
;global print_hex

cls:
	push ax
	mov ah, 0x06
	xor al, al	;Очистка экрана
	xor cx, cx	;Верхний левый угол
	mov dx, 0x184F	;Нижний правый угол (80*25, 18 - 24, 4F - 79)
	mov bh, 0x0F
	int 0x10
	mov bh, 0x00
	mov dx, 0x0000
	mov ah, 0x02
	int 0x10
	pop ax
	ret

cls_col:		;Принимает цвет в dl
	push ax
	mov ah, 0x06
	xor al, al	;Очистка экрана
	xor cx, cx	;Верхний левый угол
	mov bh, dl
	mov dx, 0x184F	;Нижний правый угол (80*25, 18 - 24, 4F - 79)
	int 0x10
	mov bh, 0x00
	mov dx, 0x0000
	mov ah, 0x02
	int 0x10
	pop ax
	ret


set_videomode:
	push ax		;Функция возвращает в AL флаги режима, нам они нужны меньше, чем содержимое аккумулятора
	xor ah, ah	;Установка режима вывода
	mov al, 0x03	;Режим вывода 80*25 символов
	int 0x10	;Прерывание на вывод
	pop ax
	ret

newline:
	push ax
	mov ah, 0x0E	;Teletype output
	mov al, endline	;\n
	int 0x10
	mov al, car_ret	;Вернуть каретку в начало строки
	int 0x10
	pop ax
	ret

print_char:		;Аргумент лежит в dx
	push ax
	mov ah, 0x0E	
	mov al, dl
	int 0x10
	pop ax
	ret

print_string:		;Аргумент (указатель на строку) в bx, возвращает в cx кол-во символов
	push ax
	mov ah, 0x0E
	xor cx, cx
.loop:
	mov al, byte[bx]
	cmp al, 0
	je .end
	int 0x10
	inc cx
	inc bx
	jmp .loop
.end:
	pop ax
	ret

print_hex:		;Принимает число в DX
	push ax
	push bx
	push cx
	push dx
	push 0xFFFF
.loop:
	mov ax, dx
	and ax, 0x000F
	push ax
	shr dx, 4
	cmp dx, 0
	je .outloop
	jmp .loop
.outloop:
	pop ax
	cmp ax, 0xFFFF
	je .end
	mov bx, hex
	add bx, ax
	mov al, byte[bx]
	mov ah, 0x0E
	int 0x10
	jmp .outloop
.end:
	pop dx
	pop cx
	pop bx
	pop ax
	ret

clear_buf:		;Принимает указатель на буфер в bx, кол-во байт в cx
	push ax
	xor ax, ax
.loop:
	cmp ax, cx
	je .end
	mov byte[bx], 0
	inc ax
	inc bx
.end:
	pop ax
	ret
