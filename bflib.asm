%DEFINE bfbufsize 256

section .text
bfclr:
	push bx
	push dx
	mov bx, bfbuf
	mov dx, bfbufsize
	call clear_buf
	pop dx
	pop bx
	ret
bfinter:		;Принимает в bx указатель на буфер с программой
	push bx
	cmp byte[bx], 0b0001
	jne .dirorex
	push ax
	push cx
	push dx
	push si
	push di
;	mov di, bx
;	mov bx, si
	mov di, bx
	mov bx, bfbuf
	mov dx, bfbufsize
	call clear_buf
;	mov si, bx
	mov bx, di
	mov word[stpos], sp
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
	cmp byte[bx], ','
	je .in
	cmp byte[bx], '>'
	je .next
	cmp byte[bx], '<'
	je .prev
	cmp byte[bx], '['
	je .beginloop
	cmp byte[bx], ']'
	je .endloop
	cmp byte[bx], 0x0A
	je .inc
	cmp byte[bx], 0x0D
	je .inc
	cmp byte[bx], ' '
	je .inc
	jmp .unknwn
.inc:
	inc bx
	inc cx
	jmp .loop
.in:
	call readbyte
	mov byte[si], al
	call newline
	jmp .inc
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
	cmp sp, [stpos]
	jle .brackerr
	cmp byte[si], 0
	je .finishloop
	mov di, sp
	mov bx, word[di+2]
	mov cx, word[di]
	jmp .inc
.unknwn:
	mov sp, word[stpos]
	mov bx, bfunknwnsmberror
	call print_string
	pop di
	pop si
	pop dx
	pop cx
	pop ax
	pop bx
	ret
.finishloop:
	pop dx
	pop dx
	jmp .inc
.end:
	cmp sp, word[stpos]
	je .ok
.brackerr:
	mov bx, bfbrackerror
	call print_string
.ok:
	mov sp, word[stpos]
	pop di
	pop si
	pop dx
	pop cx
	pop ax
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
	bfunknwnsmberror db "ERROR! Unknown symbol in program! Can use only +-.,[]<>!", 0x0A, 0x0D, 0
;	bfstackerror db "ERROR! Stack not empty after program interpretation!", 0
	bfbrackerror db "ERROR! Open and close brackets number doesn't match!", 0
section .bss
	bfbuf: resb bfbufsize
	stpos: resb 2
