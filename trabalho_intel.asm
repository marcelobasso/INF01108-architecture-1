
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
		FLAG_O			equ 	'o'			
		DEFAULT_OUT		equ		'a.out'
		FLAG_V			equ 	'v'			; 127 ou 220
		DEFAULT_TENSION	equ		127
		FLAG_ERROR		DB		'Opcao [] sem parametro', LF, 0
		
		; buffers
		CMDLINE			DB 	240 DUP (?) 	; usado na funcao GetCMDLine
		BufferWRWORD	DB  80 	DUP (?)		; usado na funcao WriteWord
	
		; variables
		CMDLINE_SIZE	DB	0
		file_in			DB	80	DUP (?)		; string: arquivo de entrada
		file_out		DB	80 	DUP (?)		; string: arquivo de saida
		tension			DB  0 				; int: valor de tensao
		
	.code
	.startup
		call	GetCMDLine					; le linha do CMD	
		mov		CMDLINE_SIZE, ax
		lea		bx, CMDLINE
		call 	WriteString					; escreve a linha lida na tela (debugging)
		
		; validar flags
		call 	InspectFlags
		
	.exit

;--------------------------------------------------------------------
; FUNÇÕES AUXILIARES
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; InspectFlags: valida as flags e salva seus valores nas variaveis
;				adequadas. Caso nao houver, salva valor padrao.
;--------------------------------------------------------------------
InspectFlags	proc	near
; 1 - encontra espaco
; 2 - espaco seguido de hyphen
; 3 - hyphen seguido de alguma flag
; 4 - seta valor da flag/informa erro na tela
; erros: sem parametros; tensao diferentes de 127 ou 220
		
		lea		bx, CMDLINE
		
IF_2:		
		mov		dl, [bx]
		cmp		dl, 0
		jnz		WS_1
		ret

IF_1:
		cmp		dl, SPACE
		jnz		IF_continue
		
		; caso achou espaço
		inc 	bx
		mov		dl, [bx]
		cmp		dl, 0
		je		IF_2
		cmp		dl, HYPHEN
		jnz		IF_continue
		
		; achou hífen
		inc 	bx
		mov		dl, [bx]
		cmp		dl, 0
		je		IF_2
IF_I:
		cmp		dl, FLAG_I
		jne		IF_O
		inc		bx
		mov		dl, [bx]
		cmp		dl, SPACE
		jne		IF_invalid
		
IF_O:
		cmp		dl, FLAG_O
		jne		IF_V
		inc		bx
		mov		dl, [bx]
		cmp		dl, SPACE
		jne		IF_invalid
		
IF_V:	
		cmp 	dl, FLAG_V
		jne		IF_invalid
		inc		bx
		mov		dl, [bx]
		cmp		dl, SPACE
		jne		IF_invalid
		
IF_invalid:
		mov		ax, 1
		ret
		
IF_continue:
		inc 	bx
		jmp		IF_2

InspectFlags	endp


;
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
	