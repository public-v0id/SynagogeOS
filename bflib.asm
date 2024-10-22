%DEFINE bfbufsize 256

section .text
bfinter:		;Принимает в bx указатель на буфер с программой
	push bx
	cmp byte[bx], 0b0001
	jne .dirorex
	push cx
	push dx
	push si
	push di
	mov di, bx
	mov bx, si
	mov dx, bfbufsize
	call clear_buf
	mov si, bx
	mov bx, di
	mov [stpos], sp
	add bx, 15
	mov si, bfbuf
	xor dx, dx
	xor cx, cx
.loop:
	cmp cx, 495
	jae .end
	cmp byte[bx], 0x00
	je .end
	cmp byte[bx], '+'
	je .plus
	cmp byte[bx], '-'
	je .minus
	cmp byte[bx], '.'
	je .out
	cmp byte[bx], '>'
	je .next
	cmp byte[bx], '<'
	je .prev
	cmp byte[bx], '['
	je .beginloop
	cmp byte[bx], ']'
	je .endloop
.inc:
	inc bx
	inc cx
	jmp .loop
.plus:
	mov dl, byte[si]
	inc dl
	mov byte[si], dl
	jmp .inc
.minus:
	mov dl, byte[si]
	dec dl
	mov byte[si], dl
	jmp .inc
.out:
	mov dh, 0
	mov dl, byte[si]
	call print_char
	jmp .inc
.next:
	lea dx, [bfbuf+bfbufsize]
	cmp si, dx
	jl .nextend
	sub si, bfbufsize
.nextend:
	inc si
	mov dx, si
	jmp .inc
.prev:
	mov dx, bfbuf
	cmp si, dx
	ja .prevend
	add si, bfbufsize
.prevend:
	dec si
	mov dx, si
	jmp .inc
.beginloop:
	push bx
	push cx
	jmp .inc
.endloop:
;	mov dh, 0
;	mov dl, byte[si]
;	call print_hex
;	call newline
	cmp byte[si], 0
	je .finishloop
	mov di, sp
	mov bx, word[di+2]
	mov cx, word[di]
	jmp .inc
.finishloop:
	pop dx
	pop dx
	jmp .inc
.end:
	mov sp, [stpos]
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	call newline
	ret
.dirorex:
	mov bx, bfdirorexerror
	call print_string
	pop bx
	ret

section .data
	bfdirorexerror db "ERROR! Interpreter only works with text files!", 0x0A, 0x0D, 0
	stpos dw 0x0000

section .bss
	bfbuf: resb bfbufsize
