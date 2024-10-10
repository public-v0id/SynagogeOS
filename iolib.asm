%DEFINE endline	0x0A
%DEFINE car_ret 0x0D
%DEFINE tab 0x09
%DEFINE space 0x20
%DEFINE inpend 0x00
%DEFINE tty 0x0E
%DEFINE video_int 0x10
%DEFINE keyserv_int 0x16
%DEFINE readchar 0x00
%DEFINE backspace 0x08

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

read_char:		;Возвращает в ax введенный символ
	mov ah, 0x00
	int 0x16
	and ax, 0x00FF
	ret

read_cmd:		;Принимает на вход указатель на буфер в bx, размер буфера в dx. Возвращает в ax результат ввода (0 - ошибка)
	push bx
	push cx
	xor cx, cx
.firstletter:
	mov ah, readchar
	int keyserv_int
	cmp al, backspace
	je .firstletter
	mov ah, tty
	int video_int
	cmp al, tab
	je .firstletter
	cmp al, space
	je .firstletter
	cmp al, inpend
	je .end
	cmp al, endline
	je .end
	cmp al, car_ret
	je .end
	mov byte[bx], al
	inc bx
	inc cx
.inploop:
	cmp cx, 0x00
	je .firstletter
	cmp cx, dx
	jae .error
	mov ah, readchar
	int keyserv_int
	cmp al, backspace
	je .inpbsp
	mov ah, tty
	int video_int
	cmp al, endline
	je .end
	cmp al, inpend
	je .end
	cmp al, car_ret
	je .end
	mov byte[bx], al
	inc bx
	inc cx
	jmp .inploop
.inpbsp:
	cmp cx, 0x00
	je .firstletter
	mov ah, tty
	mov al, backspace
	int video_int
	mov al, space
	int video_int
	mov al, backspace
	int video_int
	dec bx
	dec cx
	jmp .inploop
.error:
	pop cx
	pop bx
	xor ax, ax
	ret
.end:
	mov byte[bx], 0x00
	pop cx
	pop bx
	ret
