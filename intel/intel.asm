
	.model small
	.stack

	.data
		; constantes e strings
		CR				equ		13					; Carriage Return (Enter)
		LF				equ		10  				; Line Feed ('\n')
		TAB				equ		9
		SPACE			equ		' '					; caracteres uteis no programa
		HYPHEN			equ		'-'
		COMMA			equ		','
		FLAG_I			DB 		'i'
		FLAG_O			DB 		'o'
		FLAG_V			DB 		'v'
		
		I_INFO			DB 		'-i: ', 0			; string usadas na funcao GenerateReport
		O_INFO			DB 		'-o: ', 0
		V_INFO			DB 		'-v: ', 0
		
		DEFAULT_IN		DB		'a.in', 0			; valores padrao para as variaveis de entrada
		DEFAULT_OUT		DB		'a.out', 0
		DEFAULT_TENSION	DB 		'127', 0
		
		I_ERROR			DB		'Opcao [-i] sem parametro', CR, LF, 0
		I_ERROR_2		DB		'Arquivo de entrada nao existente', CR, LF, 0			
		O_ERROR			DB		'Opcao [-o] sem parametro', CR, LF, 0
		V_ERROR			DB		'Opcao [-v] sem parametro', CR, LF, 0
		V_ERROR_2		DB		'Parametro da opcao [-v] deve ser 127 ou 220', CR, LF, 0
		INV_LINE_1		DB		'Linha ', 0
		INV_LINE_2		DB		' invalida: ', 0
		TOTAL_TIME		DB		'Tempo total: ', 0
		ADEQUATE_TIME	DB		'Tempo tensao adequada (qualidade): ', 0
		NOT_TIME		DB		'Tempo sem tensao: ', 0
		
		; buffers
		CMDLINE			DB 		240 DUP (?) 	; usado na funcao GetCMDLine
		BufferWRWORD	DB  	80 	DUP (?)		; usado na funcao WriteWord
		FileBuffer		DB		240 DUP (?)		; usado em funcoes de arquivos 
		LineBuffer		DB		480 DUP (?)		; usado em funcao de leitura de linha (GetLine)
		TensionBuffer	DB		8	DUP (?)		; usado para validar tensoes (ProcessTension)
	
		; variables
		sw_m			DW		0
		sw_n			DW		0
		sw_f			DW		0				; variaveis usadas em sprintf_w
		cmdline_size	DW		0
		file_in			DB		80	DUP (?)		; string: arquivo de entrada
		file_in_handle	DW		0
		file_out		DB		80 	DUP (?)		; string: arquivo de saida
		file_out_handle	DW		0
		tension_str		DB  	80	DUP (?) 	; string: valor de tensao
		tension_int		DB 		0				; int: tensao convertida para inteiro
		tension_line	DW		0				; int: valor de tensao lida do arquivo
		flag_error		DB 		0				; int: indica se há erro nas flags
		tension_error	DB		0				; int: indica se tensão é válida
		atoi_error		DB		0				; int: indica se conversao foi bem sucedida
		line_count		DW		0				; int: contador de linhas
		invalid_reading			DB		0		; int: indica se houve alguma leitura invalida no arquivo
		tension_counter			DW		0		; int: contador de tensoes validas (para validacao de linha)
		adq_tension_counter		DW		0
		time_adq_tension		DW		0
		time_no_tension			DW		0
		
	.code
	.startup
		call	GetCMDLine					; le linha do CMD	
		mov		cmdline_size, ax
		
		mov		flag_error, 0
		call	ValidateFlags				; valida linha de comando e flags
		cmp		flag_error, 1				; caso houver flag sem parametro, finaliza
		jz		fim
		cmp		tension_error, 1			; caso houver tensao inválida, finaliza
		jz		fim
		
		call	OpenFileIn
		cmp		ax,	1						; caso o arquivo de entrada nao existir, finaliza
		jz		fim

		call	ProcessFile					; processa arquivo de entrada e gera saidas
		mov		bx, file_in_handle
		call	fclose
		cmp		invalid_reading, 1			; caso houve alguma leitura invalida no arquivo de entrada, finaliza
		jz		fim
		
		; caso nao ocorreu nenhum erro na linha de comando, nem há nenhuma linha inválida no arquivo de entrada
		call	OpenFileOut					; escreve informacoes no arquivo de relatorio
		call	GenerateReport				; exibe informacoes recebidas/settadas pelo programa na tela
		call	fclose
		
	fim:
	.exit

;--------------------------------------------------------------------
; FUNÇÕES AUXILIARES
;--------------------------------------------------------------------

;--------------------------------------------------------------------
; ProcessFile: processa arquivo de entrada e gera relatorio na tela
;	e em arquivo de saida.
; Entrada:
; Saida:
; 	arquivo de saida gerado com informacoes
;	prints na tela com as informacoes de linhas invalidas
;--------------------------------------------------------------------
ProcessFile		proc	near
		mov		bx, file_in_handle

	PF_loop:
		call	GetLine				; le linha do arquivo
		cmp		ax, 1				; caso chegou ao final do arquivo, finaliza
		jz		PF_end
		inc		line_count			; incrementa contador de linhas
		push	bx					; salva bx
		call	ProcessLine			; chamar processLine
		pop		bx					; devolve valor de bx
		jmp		PF_loop				; volta ao inicio
		
	PF_end:
		ret
ProcessFile		endp

;--------------------------------------------------------------------
; ProcessLine: checa se linha é valida (0 <= tensao <= 499)
; Entrada:
; 	LineBuffer: linha a ser validada
; Saida:
; 	ax:	0 linha valida, 1 linha invalida 
;--------------------------------------------------------------------
ProcessLine		proc	near
		mov		dx, 0					; conta n de tensoes abaixo de 10
		mov		tension_counter, 0		; conta n de tensoes valid existentes na linha
		mov		adq_tension_counter, 0	; conta n de tensoes adequadas existes na linha
		lea		bx,	LineBuffer		
		
	PL_loop:
		push	dx
		lea		bp,	TensionBuffer
		mov		cx, 1
		call	Strcpy				
		push	bx
		call	ProcessTension			; valida tensao
		pop		bx
		pop		dx
		
		cmp		ax, 1					; caso for linha invalida, fora do intervalo 0-499
		jz		PL_invalid
		cmp		ax, 2					; caso for linha com interrupcao de tensao
		jz		PL_noT
		cmp		ax, 3					; caso tensao nao é adequada
		jz		PL_next
		inc		adq_tension_counter
		
	PL_next:
		inc		bx
		cmp		[bx], LF
		jz		PL_verify
		cmp		[bx], CR
		jz		PL_verify
		cmp		[bx], 0
		jz		PL_verify
		jmp 	PL_loop
		
	PL_verify:							
		cmp		adq_tension_counter, 3	; se houver menos de 3 tensoes adequadas, linha inadequada
		jnz		PL_IT
		inc		time_adq_tension
		
	PL_IT:
		cmp		tension_counter, 3		; se houver menos de 3 tensoes validas, linha invalida
		jz		PL_end
		jmp		PL_invalid
		
	PL_noT:
		inc		dx						; caso nao tiver tensao (ax = 2)	
		cmp		dx, 3
		jne		PL_next
		inc		time_no_tension			; caso os 3 fios esteverem com tensaoo abaixo de 10, inc time_no_tension
		jmp		PL_end
		
	PL_invalid:
		push	bx
		lea		bx, INV_LINE_1
		call	WriteString
		mov		ax, line_count
		lea		bx, BufferWRWORD
		call	sprintf_w
		lea		bx, BufferWRWORD
		call	WriteString
		lea		bx, INV_LINE_2
		call	WriteString
		lea		bx, LineBuffer
		call	WriteString
		call	BreakLine
		mov		ax, 1
		mov		invalid_reading, 1
		pop		bx
		
	PL_end:
		ret
ProcessLine		endp

;--------------------------------------------------------------------
; ProcessTension: valida uma das tensoes de uma linha do arquivo
; Saida:
;	ax = 0 - valido | 1 - invalido | 2 - sem tensao | 3 - inadequado
;--------------------------------------------------------------------
ProcessTension	proc	near
		inc		tension_counter
		lea		bx, TensionBuffer		; converte primeira tensao para inteiro
		call	atoi
		cmp		atoi_error, 1			; caso atoi retornar erro
		jz		PT_invalid
		
		mov		tension_line, ax
		mov		ax, 0
		
		cmp		tension_line, 10
		jl		PT_noT
		
		cmp		tension_line, 0
		jl		PT_invalid
		cmp		tension_line, 499
		jg		PT_invalid
		
		cmp		tension_int, 127 		; adequada quando estiver entre 117 e 137, inclusive estes valores
		jne		PT_220
		cmp 	tension_line, 117
		jl		PT_inadequate
		cmp		tension_line, 137
		jg		PT_inadequate
		jmp		PT_end
	
	PT_220:	
		cmp 	tension_line, 210		; adequada quando estiver entre 210 e 230, inclusive estes valores
		jl		PT_inadequate
		cmp		tension_line, 230
		jg		PT_inadequate
		jmp		PT_end
		
	PT_invalid:
		dec 	tension_counter
		mov		ax, 1
		jmp		PT_end
		
	PT_noT:
		mov		ax, 2
		jmp		PT_end
		
	PT_inadequate:	
		mov		ax, 3
		
	PT_end:
		ret
ProcessTension	endp

;--------------------------------------------------------------------
; GenerateReport: função para exibir na tela os parametros recebidos/
;	settados pelo programa e escrever no arquivo de saida
;--------------------------------------------------------------------
GenerateReport		proc	near
		lea		bx, I_INFO				; exibe informacoes da flag i
		call	WriteString
		lea		bx, file_in
		call	WriteString
		call 	BreakLine
		mov		bx, file_out_handle		; escreve -i no arquivo de saida
		lea		bp, I_INFO
		lea		ax, file_in
		call	WriteToFile
		
		lea		bx, O_INFO				; exibe informacoes da flag o
		call	WriteString
		lea		bx, file_out
		call    WriteString
		call	BreakLine
		mov		bx, file_out_handle		; escreve -o no arquivo de saida
		lea		bp, O_INFO
		lea		ax, file_out
		call	WriteToFile
		
		lea		bx, V_INFO				; exibe informacoes da flag v
		call	WriteString
		lea		bx, tension_str
		call	WriteString
		call 	BreakLine
		mov		bx, file_out_handle		; escreve -v no arquivo de saida
		lea		bp, V_INFO
		lea		ax, tension_str
		call	WriteToFile
		call	BreakLineF
		
		lea		bx, TOTAL_TIME
		call	WriteString
		mov		ax, line_count			; exibe numero de linhas lidas
		lea		bx, BufferWRWORD
		call	sprintf_w
		lea		bx, BufferWRWORD
		call	WriteString
		mov		bx, file_out_handle
		lea		bp, TOTAL_TIME
		lea		ax, BufferWRWORD
		call	WriteToFile
		
		mov		ax, time_adq_tension	; exibe tempo com tensao adequada (qualidade de tensao)
		lea		bx, BufferWRWORD
		call	sprintf_w
		mov		bx, file_out_handle
		lea		bp, ADEQUATE_TIME
		lea		ax, BufferWRWORD
		call	WriteToFile
		
		mov		ax, time_no_tension		; exibe tempo sem tensao
		lea		bx, BufferWRWORD
		call	sprintf_w
		mov		bx, file_out_handle
		lea		bp, NOT_TIME
		lea		ax, BufferWRWORD
		call	WriteToFile
		
		ret
GenerateReport		endp

WriteToFile		proc	near
		push 	ax
		call	setLine
		call	SpaceF
		pop		ax
		mov		bp, ax
		call	setLine
		call	BreakLineF
		
		ret
WriteToFile		endp

;--------------------------------------------------------------------
; ValidateFlags: verifica se as flags são válida na linha de comando
; Saida: 
;	flag_error = 1: se houver opcao sem parametro
;--------------------------------------------------------------------
ValidateFlags	proc	near
		lea		ax, FLAG_I			; procura flag i
		lea 	cx, file_in
		lea		dx, I_ERROR
		lea		bp, DEFAULT_IN
		call 	ValidateFlag
		
		lea		ax, FLAG_O			; procura flag o
		lea 	cx, file_out
		lea		dx, O_ERROR
		lea		bp, DEFAULT_OUT
		call 	ValidateFlag
		
		lea		ax, FLAG_V			; procura flag v
		lea 	cx, tension_str
		lea		dx, V_ERROR
		lea		bp, DEFAULT_TENSION
		call 	ValidateFlag
		cmp		flag_error, 1
		jz		VF_1
		call	ValidateTension
		
	VF_1:
		ret
ValidateFlags	endp

;--------------------------------------------------------------------
; ValidateFlag: verifica se uma flag é válida na linha de comando.
; entra: ax: flag a ser encontrada
;		 bp: Valor padrao a ser settado caso nao houver flag
;		 dx: Mensagem de erro
;		 cx: ponteiro para variavel a ser settada
; retorna:
;		 flag_error = 1: se houver opcao sem parametro
;--------------------------------------------------------------------
ValidateFlag	proc	near
		push	bp					; empilha parametros
		push	cx
		push	dx
		call	FindFlag
		pop		dx					; desempilha parametros
		pop		cx
		pop		bp
		
		cmp		ax, 0				; verifica retorno da FindFlag
		jz		flag_ok
		
		cmp		ax, 1
		jz		flag_sem_param
	
		mov		bx, bp				; seta valor padrao caso nao houver a flag (ax = 2)
		mov		bp, cx
		call	Strcpy
		jmp		flag_ok
		
	flag_sem_param:
		mov 	bx, dx				; printa mensagem de erro passada pelo dx
		call	WriteString
		mov		flag_error, 1
		
	flag_ok:
		ret
ValidateFlag	endp

; -------------------------------------------------------------------
; ValidateTension: verifica se tensão é válida (127 ou 220)
; Saida:
;	tension_error = 1 se houver erro, senaõo 0
;--------------------------------------------------------------------
ValidateTension	proc	near
		mov		ax, 0
		lea		bx, tension_str
		call	atoi
		
		cmp		ax, 127
		jz		tension_ok
		cmp		ax, 220
		jz		tension_ok
		mov		tension_error, 1
		lea		bx, V_ERROR_2
		call	WriteString
		jmp 	VT_2
	
	tension_ok:
		mov		tension_int, al
		
	VT_2:
		ret
ValidateTension	endp

;--------------------------------------------------------------------
; FindFlag: procura uma flag no buffer CMDLINE e seta seu valor na
;			variavel indicada.
; entra: ax: flag a ser encontrada
;		 bx: Usada internamente como ponteiro para CMDLINE
;		 cx: ponteiro para variavel a ser settada caso houver entrada
; retorna:
;		 ax = 0: achou a flag e settou valor
;		 ax = 1: erro (flag sem parametro), 
;		 ax = 2: nao achou a flag
;--------------------------------------------------------------------
FindFlag	proc	near
		lea		bx, CMDLINE
		mov		dh, 0
	
	FF_1:
		mov		dl, [bx]		; While (*S!='\0') {
		cmp		dl, 0
		jnz		FF_2
		mov		ax, 2			; Caso nao encontrou a flag, retorna 2
		
		ret
		
	FF_2:
		cmp		dl, SPACE		; procura a sequencia " -FLAG " onde flag pode ser i, o ou v
		jnz		FF_3
		
		call 	GetNextChar
		cmp		dl, HYPHEN
		jnz		FF_3
		
		call	GetNextChar
		mov		bp, ax
		cmp		dl, [bp]
		jnz		FF_3
		
		call	GetNextChar
		cmp		dl, 0
		jz		FF_error
		cmp		dl, SPACE
		jnz		FF_3
		
		; --- encontrou a flag desejada ---
		call	GetNextChar 		; verifica flag sem parametro (retorna 1)
		cmp		dl, 0
		jz		FF_error
		cmp		dl, HYPHEN
		jz		FF_error
		cmp		dl, LF
		jz 		FF_error
		cmp		dl, CR
		jz		FF_error
		cmp		dl, SPACE
		jz		FF_error
		jmp		FF_found
		
	FF_error:
		mov		ax, 1				; retorna 1 indicando que flag nao tem parametro
		ret
		
	FF_found:
		mov		bp, cx				; caso nenhum erro ocorreu, setta valor na variavel indicada
		call	Strcpy
		mov		ax, 0				; retorna 0 indicando sucesso
		ret
		
	FF_3:	
		inc		bx
		jmp		FF_1

FindFlag 	endp

;====================================================================
;====================== FUNÇÕES PARA STRINGS ========================
;====================================================================

;--------------------------------------------------------------------
; GetNextChar: dl <- [++bx]
; Entra: bx: ponteiro para string a ser percorrida
; Retorna: dl: char lido
;--------------------------------------------------------------------
GetNextChar	proc	near
	inc		bx
	mov		dl,	[bx]
	
	ret
GetNextChar	endp

;--------------------------------------------------------------------
; Strcpy: dados dois ponteiros de string, copia uma para a outra
;		  até encontrar um espaço, ignorando espaços iniciais.
; Entrada: bx: string origem
;		   bp: string destino
;		   cx: indica se string copiada é tensao
;--------------------------------------------------------------------
Strcpy		proc 	near
	CP_repeat:					; ignora tabs e espacos
		mov 	al, [bx]
		cmp 	al, SPACE
		jz 		continue_CP		; If a space, ignores
		cmp		al, TAB
		jz		continue_CP		; If a tab, ignores
		jmp		CP_1
		
	continue_CP:
		inc 	bx           	; Move to the next character
		jmp 	CP_repeat       ; Repeat until non-space character is found

	CP_1:
		mov		al, [bx]
		cmp		al, 0			; copia ate encontra espaco, final da string, CR ou LF
		jz		CP_end	
		cmp		al, CR
		jz		CP_end
		cmp		al, LF
		jz		CP_end 		
		cmp		cx, 1			; se for tensao, copia ate encontrar virgula
		jne		CP_continue
		cmp		al, COMMA
		jz		CP_end
		jmp		CP_2
		
	CP_continue:	
		cmp		al, SPACE
		jz		CP_end

	CP_2:		
		mov		ax, [bx]
		mov		[bp], ax
		inc		bp
		inc		bx
		jmp		CP_1
		
	CP_end:
		mov		[bp], 0
		ret

Strcpy		endp

;--------------------------------------------------------------------
; atoi: String (bx) -> Inteiro (ax)
; Obj.: recebe uma string e transforma em um inteiro
; Ex:
; lea bx, String1 (Em que String1 é db "2024",0)
; call atoi
; -> devolve o numero 2024 em ax	
;--------------------------------------------------------------------
atoi	proc 	near
		;call	WriteString
		mov		ax, 0
		mov		atoi_error, 0
		
	atoi_2:
		; while (*S!='\0') {
		cmp		byte ptr[bx], 0
		jz		atoi_1
		cmp		byte ptr[bx], SPACE
		jz		atoi_error_j
		cmp		byte ptr[bx], TAB
		jz		atoi_error_j

		; 	A = 10 * A
		mov		cx, 10
		mul		cx

		; 	A = A + *S
		mov		ch, 0
		mov		cl, [bx]
		add		ax, cx
		sub		ax, '0'
		inc		bx
		jmp		atoi_2
		
	atoi_error_j:
		mov		atoi_error, 1

	atoi_1:
		ret

atoi	endp
	

;--------------------------------------------------------------------
; Função: Escreve o valor de AX na tela
;--------------------------------------------------------------------
WriteWord	proc	near
		lea		bx, BufferWRWORD
		call	HexToDecAscii
		lea		bx, BufferWRWORD
		call	WriteString
		
		ret
WriteWord	endp


;--------------------------------------------------------------------
; Função: Escrever um string na tela
; Entra: DS:BX -> Ponteiro para o string
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
	push ds 				; Salva as informações de segmentos
	push es

	mov ax, ds 				; Troca DS com ES para poder usa o REP MOVSB
	mov bx, es
	mov ds, bx
	mov es, ax
	mov si, 80h 			; Obtém o tamanho do string da linha de comando e coloca em CX
	mov ch, 0
	mov cl, [si]
	mov ax, cx 				; Salva o tamanho do string em AX, para uso futuro
	mov si, 81h 			; Inicializa o ponteiro de origem
	lea di, CMDLINE 		; Inicializa o ponteiro de destino
	rep movsb
	pop es 					; retorna as informações dos registradores de segmentos 
	pop ds
	
	ret
GetCMDLine endp

;--------------------------------------------------------------------
; HexToDecAscii: Converte um valor HEXA para ASCII-DECIMAL
; Entra:  
;	(A) -> AX -> Valor "Hex" a ser convertido
;   (S) -> DS:BX -> Ponteiro para o string de destino
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
; sprintf_w: dado um numero e uma string, transforma o numero em ascii 
; 	e salva na string
; Entrada:
; 	ax: inteiro
; 	bx: string
; Saida:
; 	bx: contem a string resultante
;--------------------------------------------------------------------
sprintf_w	proc	near
		mov		sw_n, ax
		mov		cx, 5
		mov		sw_m, 10000
		mov		sw_f, 0

	sw_do:
		mov		dx, 0
		mov		ax, sw_n
		div		sw_m
		cmp		al, 0
		jne		sw_store
		cmp		sw_f, 0
		je		sw_continue
	sw_store:
		add		al, '0'
		mov		[bx], al
		inc		bx
		
		mov		sw_f, 1
	sw_continue:
		mov		sw_n, dx
		mov		dx, 0
		mov		ax, sw_m
		mov		bp, 10
		div		bp
		mov		sw_m, ax
		dec		cx
		cmp		cx, 0
		jnz		sw_do

		cmp		sw_f, 0
		jnz		sw_continua2
		mov		[bx], '0'
		inc		bx

	sw_continua2:
		mov		byte ptr[bx], 0
		ret	
sprintf_w	endp

;--------------------------------------------------------------------

BreakLine	proc	near
	mov		dl, LF
	mov		ah, 2
	int		21h
	
	ret
BreakLine	endp
		
BreakLineF	proc	near
	mov		dx, CR
	call	setChar
	mov		dx, LF
	call	setChar
	
	ret
BreakLineF	endp

SpaceF		proc	near
	mov		dx, ' '
	call	setChar
	
	ret
SpaceF		endp
;====================================================================
;===================== FUNÇÕES PARA ARQUIVOS ========================
;====================================================================

;--------------------------------------------------------------------
; fopen: Dado o caminho para um arquivo, devolve o ponteiro desse arquivo
; Entrada: 
;	dx: nome do arquivo
; Saida:
;	bx: ponteiro para o arquivo
;	cf = 0, sucesso/ 1, erro
;--------------------------------------------------------------------
fopen	proc	near
	mov		al, 0
	mov		ah, 3dh
	int		21h
	mov		bx, ax
	
	ret
fopen	endp

;--------------------------------------------------------------------
; fcreate: Dado um nome de arquivo, o cria
; Entrada:
;	dx: string nome do arquivo
; Saida:
;	bx: ponteiro para arquivo aberto
; 	cf = 0, sucesso/1, erro
;--------------------------------------------------------------------
fcreate	proc	near
	mov		cx, 0
	mov		ah, 3Ch
	int		21h
	mov		bx, ax
	
	ret
fcreate	endp

;--------------------------------------------------------------------
; fclose: Fecha stream de arquivo
; Entrada:
;	bx: ponteiro para o arquivo
; Saida:
; 	cf = 0, sucesso/1, erro
;--------------------------------------------------------------------
fclose	proc	near
	mov		ah, 3Eh
	int		21h
	
	ret
fclose	endp

;--------------------------------------------------------------------
; getChar: Dado um arquivo, devolve um caractere, a posicao do cursor 
;	e define CF como 0 se a leitura deu certo
; Entrada:
;	bx: ponteiro para o arquivo
; Saida:
;	dl: caractere lido (ASCII)
;	ax: posicao do cursor
; 	cf = 0, sucesso/1, erro
;--------------------------------------------------------------------
getChar	proc	near
	mov		ah, 3Fh
	mov		cx, 1				; number of bytes to read
	lea		dx, FileBuffer
	int		21h
	mov		dl, FileBuffer
	
	ret
getChar	endp

;--------------------------------------------------------------------
; setChar: Dado um arquivo e um caractere, escreve esse caractere no 
;	arquivo e devolve a posicao do cursor e define CF como 0 se a leitura deu certo
; Entrada:
;	bx: ponteiro para o arquivo
; 	dl: char a ser escrito
; Saida:
;	ax: posicao do cursor
; 	cf = 0, sucesso/1, erro
;--------------------------------------------------------------------
setChar	proc	near
	mov		ah, 40h
	mov		cx, 1				; number of bytes to write
	mov		FileBuffer, dl
	lea		dx, FileBuffer
	int		21h
	
	ret
setChar	endp

;--------------------------------------------------------------------
; GetLine: Lê uma linha do arquivo de entrada (até encontrar LF, CR ou 0)
; Entrada:
;	bx: ponteiro para arquivo
; Saida:
;	cx: indica se o arquivo chegou ao fim (caso 1, entao acabou)
;	FileBuffer: linha lida, com 0 no final
;--------------------------------------------------------------------
GetLine		proc	near
		lea		bp, LineBuffer
		mov		dh, 0
		
	ignore_loop:
		push	bx
		call	getChar
		pop		bx
		jc		end_file
		cmp		ax, 0
		jz		end_file
		cmp		dl, LF
		jz		ignore_loop
		cmp		dl, CR
		jz		ignore_loop
		jmp		ignore_getChar
		
	read_loop:
		push	bx
		call	getChar
		pop		bx
		jc		end_file
		cmp		ax, 0
		jz		end_file
	ignore_getChar:
		cmp		dl, LF
		jz		end_line
		cmp		dl, CR
		jz		end_line
		cmp		dl, 0
		jz		end_file
		
		cmp		dl, 'f'				; caso entrar o caractere 'f' de 'fim' ou 'F', pula para end_file
		jz		end_file
		cmp		dl, 'F'
		jz		end_file
		
		mov		[bp], dl
		inc		bp
		jmp		read_loop
		
	end_file:	
		mov		ax, 1
		jmp		error_return
	
	end_line:
		mov		ax, 0
	
	error_return:
		mov		[bp], 0
		
		ret
GetLine		endp

;--------------------------------------------------------------------
; setLine: Dado um arquivo e uma string, escreve a string no arquivo
; Entrada:
;	bx: ponteiro para o arquivo
; 	bp: ponteiro para a string
; Saida:
;	ax: posicao do cursor
; 	cf = 0, sucesso/1, erro
;--------------------------------------------------------------------
setLine	proc	near
	SL_loop:
		mov		dx, [bp]
		cmp		dx, 0
		je		SL_end	
		cmp		dx, 32						; caractere aparecendo DO NADA
		je      SL_end
		cmp		dx, CR
		jz		SL_end
		cmp		dx, LF
		jz		SL_end
		call	setChar
		inc		bp
		jmp		SL_loop
		
		
	SL_end:
		ret
setLine	endp

;--------------------------------------------------------------------
; OpenFileIn: abre o arquivo de entrada
; Saida:
; 	ax = 1, caso o arquivo de entrada nao existir
; 	file_in_handle: ponteiros para arquivo aberto
;--------------------------------------------------------------------
OpenFileIn	proc	near
		mov		ax, 0						; seta retorno como 0
		
		lea		dx, file_in					; abre arquivo de entrada
		call	fopen
		jnc		in_file_ok					; se cf = 0, in_file_ok

		lea		bx, I_ERROR_2				; arquivo nao existe
		call 	WriteString
		mov		ax, 1
	
	in_file_ok:
		mov		file_in_handle, bx
		ret
OpenFileIn	endp

;--------------------------------------------------------------------
; OpenFileOut: abre o arquivo de saida
; Saida:
; 	file_in_handle: ponteiros para arquivo aberto
;--------------------------------------------------------------------
OpenFileOut	proc	near
		lea		dx, file_out
		call	fcreate
		mov		file_out_handle, bx
	
	out_file_ok:
		ret
OpenFileOut endp

;--------------------------------------------------------------------
	end
;--------------------------------------------------------------------
	