
	.model small
	.stack

	.data
		; constantes
		CR		equ		13					; Carriage Return (Enter)
		LF		equ		10  				; Line Feed ('\n')
		SPACE	equ		' '
		HYPHEN	equ		'-'
		FLAG_I			equ 	'i'			
		DEFAULT_IN		equ		'a.in'
		I_ERROR			DB		'Opcao [-i] sem parametro', LF, 0
		FLAG_O			equ 	'o'			
		DEFAULT_OUT		equ		'a.out'
		O_ERROR			DB		'Opcao [-o] sem parametro', LF, 0
		FLAG_V			equ 	'v'			; 127 ou 220
		DEFAULT_TENSION	equ		127
		V_ERROR			DB		'Opcao [-v] sem parametro', LF, 0
		
		
		; buffers
		CMDLINE			DB 	240 DUP (?) 	; usado na funcao GetCMDLine
		BufferWRWORD	DB  80 	DUP (?)		; usado na funcao WriteWord
	
		; variables
		cmdline_size	DW	0
		file_in			DB	80	DUP (?)		; string: arquivo de entrada
		file_out		DB	80 	DUP (?)		; string: arquivo de saida
		tension			DB  0 				; int: valor de tensao
		
	.code
	.startup
		call	GetCMDLine					; le linha do CMD	
		mov		cmdline_size, ax
		lea		bx, CMDLINE
		call 	WriteString					; escreve a linha lida na tela (debugging)
		
		; validar flags
		;mov		ah, FLAG_I
		;mov		al, DEFAULT_IN
		;mov		cl, file_in
		;call 		FindFlag
		;mov		ah, 4CH
		;pop		bx
		;mov		al, bl
		;int		21H
		
	.exit

;--------------------------------------------------------------------
; FUNÇÕES AUXILIARES
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; FindFlag: procura uma flag no buffer CMDLINE e seta seu valor ou exibe mensagem.
; entra: ah: flag a ser encontrada
;		 al: valor padrao caso nao encontrar
;		 bx: Usada internamente como ponteiro para CMDLINE
;		 cl: ponteiro para variavel a ser settada
; retorna:
;		 empilha 1 caso deu erro (flag sem parametro), 0 caso achou a flag ou setou padrao
;--------------------------------------------------------------------
; FindFlag	proc	near
		; mov		bx, CMDLINE
	
	; FF_1:
		; mov		dl, byte [bx]		; While (*S!='\0') {
		; cmp		dl, 0
		; jnz		FF_2
		; ; nao encontrou a flag (setta padrao apontado por al)
		; push	0
		; cmp		byte [ah], FLAG_V
		; jnz		FF_string
		; mov		cl, byte DEFAULT_TENSION
		; ret
		
	; FF_string:
		; mov		ah, al
		; mov		al, cl
		; call	Strcpy
		; ret
		
	; FF_2:
		; cmp		dl, SPACE		; procura a sequencia " -FLAG " onde flag pode ser i, o ou v
		; jnz		FF_3
		
		; call 	GetNextChar
		; cmp		dl, HYPHEN
		; jnz		FF_3
		
		; call	GetNextChar
		; cmp		dl, byte [ah]
		; jnz		FF_3
		
		; call	GetNextChar
		; cmp		dl, SPACE
		; jnz		FF_3
		
		; ; --- encontrou a flag desejada ---
		
		; ; flag sem parametro (erro 1)
		; call	GetNextChar
		; cmp		dl, HYPHEN
		; jz		FF_error
		; cmp		dl, 0
		; jz		FF_error
		; jmp		FF_found
		
	; FF_error:
		; ; escreve mensagem de erro 'Opcao [- ] sem parametro',
		; mov		bx,	cx
		; call	WriteString
		; push 	1
		; ret
		
		
	; FF_found:
		; ; setta valor na variavel (sem erro)
		; mov		ah, bx
		; mov		al,	cl
		; call	Strcpy
		; push 	0
		; ret
		
	; FF_3:	
		; inc		bx
		; jmp		FF_1

; FindFlag 	endp

; ;--------------------------------------------------------------------
; ; GetNextChar: dl <- [++bx]
; ; Entra: bx: ponteiro para string a ser percorrida
; ; Retorna: dl: char lido
; ;--------------------------------------------------------------------
GetNextChar	proc	near
	inc		bx
	mov		dl,	[bx]
	ret
GetNextChar	endp

; ;--------------------------------------------------------------------
; ; Strcpy: dados dois ponteiros de string, copia uma para a outra
; ;		  até encontrar um espaço
; ; Entra: bx: string origem
; ;		   bp: string destino
; ;--------------------------------------------------------------------
Strcpy		proc 	near
	CP_repeat:
		mov 	al, [bx]    	; Load character from source string
		cmp 	al, SPACE      	; Compare with space character
		jne 	CP_1			; If not a space, exit loop
		inc 	bx           	; Move to the next character
		jmp 	CP_repeat       ; Repeat until non-space character is found

	CP_1:
		; copia ate encontra espaco, final da string, cr ou lf
		cmp		[bx], 0
		jz		CP_end
		cmp		[bx], SPACE
		jz		CP_end
		cmp		[bx], CR
		jz		CP_end
		cmp		[bx], LF
		jz		CP_end

	CP_2:		
		mov		ax, [bx]
		mov		[bp], ax
		inc		bp
		inc		bx
		jmp		CP_1
		
	CP_end:
		inc		bp
		mov		byte [bp], 0
		ret

Strcpy		endp

;--------------------------------------------------------------------
;Função: Escreve o valor de AX na tela
;--------------------------------------------------------------------
WriteWord	proc	near
		lea		bx, BufferWRWORD
		call	HexToDecAscii
		
		lea		bx, BufferWRWORD
		call	WriteString
		
		ret
WriteWord	endp


;--------------------------------------------------------------------
;Função: Escrever um string na tela
;Entra: DS:BX -> Ponteiro para o string
;--------------------------------------------------------------------
WriteString	proc	near

WS_2:
		mov		dl, [bx]		; While (*S!='\0') {
		cmp		dl, 0
		jnz		WS_1
		ret

WS_1:
		mov		ah, 2		; 	Int21(2)
		int		21H

		inc		bx			; 	++S
		jmp		WS_2		; }

WriteString	endp

;--------------------------------------------------------------------
; Função: copiar o string digitado na linha de comando para um buffer 
;         no segmento de dados do programa (tamanho em AX)
; Entra: 
;--------------------------------------------------------------------
GetCMDLine	proc	near
	push ds ; Salva as informações de segmentos
	push es

	mov ax, ds ; Troca DS com ES para poder usa o REP MOVSB
	mov bx, es
	mov ds, bx
	mov es, ax
	mov si, 80h ; Obtém o tamanho do string da linha de comando e coloca em CX
	mov ch, 0
	mov cl, [si]
	mov ax, cx ; Salva o tamanho do string em AX, para uso futuro
	mov si, 81h ; Inicializa o ponteiro de origem
	lea di, CMDLINE ; Inicializa o ponteiro de destino
	rep movsb
	pop es ; retorna as informações dos registradores de segmentos 
	pop ds
	
GetCMDLine endp

;
;--------------------------------------------------------------------
;Função: Converte um valor HEXA para ASCII-DECIMAL
;Entra:  (A) -> AX -> Valor "Hex" a ser convertido
;        (S) -> DS:BX -> Ponteiro para o string de destino
;--------------------------------------------------------------------
HexToDecAscii	proc near

		mov	cx,0			;N = 0;
H2DA_2:
		or	ax,ax			;while (A!=0) {
		jnz	H2DA_0
		or	cx,cx
		jnz	H2DA_1

H2DA_0:
		mov	dx,0			;A = A / 10
		mov	si,10			;dl = A % 10 + '0'
		div	si
		add	dl,'0'

		mov	si,cx			;S[N] = dl
		mov	[bx+si],dl

		inc	cx				;++N
		jmp	H2DA_2

H2DA_1:
		mov	si,cx			;S[N] = '\0'
		mov	byte ptr[bx+si],0

		mov	si,bx			;i = 0

		add	bx,cx			;j = N-1
		dec	bx

			sar	cx,1			;N = N / 2

H2DA_4:
		or	cx,cx			;while (N!=0) {
		jz	H2DA_3


		mov	al,[si]			;S[i] <-> S[j]
		mov	ah,[bx]
		mov	[si],ah
		mov	[bx],al

		dec	cx				;	--N

		inc	si				;	++i

		dec	bx				;	--j
		jmp	H2DA_4

H2DA_3:
		ret

HexToDecAscii	endp

		
;--------------------------------------------------------------------
	end
;--------------------------------------------------------------------
	