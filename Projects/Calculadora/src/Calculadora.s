        PUBLIC  __iar_program_start
        EXTERN  __vector_table
        EXTERN leituraUA
        EXTERN enviaUA
        EXTERN UART_enable
        EXTERN UART_config
        EXTERN GPIO_special
        EXTERN GPIO_select
        EXTERN GPIO_enable
        
        
        
        SECTION .text:CODE:REORDER(2)
        
        ;; Keep vector table even if it's not referenced
        REQUIRE __vector_table
        
        THUMB


; System Control bit definitions
PORTA_BIT               EQU     000000000000001b ; bit  0 = Port A
PORTF_BIT               EQU     000000000100000b ; bit  5 = Port F
PORTJ_BIT               EQU     000000100000000b ; bit  8 = Port J
PORTN_BIT               EQU     001000000000000b ; bit 12 = Port N
UART0_BIT               EQU     00000001b        ; bit  0 = UART 0

; NVIC definitions
NVIC_BASE               EQU     0xE000E000
NVIC_EN1                EQU     0x0104
VIC_DIS1                EQU     0x0184
NVIC_PEND1              EQU     0x0204
NVIC_UNPEND1            EQU     0x0284
NVIC_ACTIVE1            EQU     0x0304
NVIC_PRI12              EQU     0x0430

; GPIO Port definitions
GPIO_PORTA_BASE         EQU     0x40058000
GPIO_PORTF_BASE    	EQU     0x4005D000
GPIO_PORTJ_BASE    	EQU     0x40060000
GPIO_PORTN_BASE    	EQU     0x40064000
GPIO_DIR                EQU     0x0400
GPIO_IS                 EQU     0x0404
GPIO_IBE                EQU     0x0408
GPIO_IEV                EQU     0x040C
GPIO_IM                 EQU     0x0410
GPIO_RIS                EQU     0x0414
GPIO_MIS                EQU     0x0418
GPIO_ICR                EQU     0x041C
GPIO_AFSEL              EQU     0x0420
GPIO_PUR                EQU     0x0510
GPIO_DEN                EQU     0x051C
GPIO_PCTL               EQU     0x052C

; System Control definitions
SYSCTL_BASE             EQU     0x400FE000
SYSCTL_RCGCGPIO         EQU     0x0608
SYSCTL_PRGPIO		EQU     0x0A08
SYSCTL_RCGCUART         EQU     0x0618
SYSCTL_PRUART           EQU     0x0A18

; UART definitions
UART_PORT0_BASE         EQU     0x4000C000
UART_FR                 EQU     0x0018
UART_IBRD               EQU     0x0024
UART_FBRD               EQU     0x0028
UART_LCRH               EQU     0x002C
UART_CTL                EQU     0x0030
UART_CC                 EQU     0x0FC8
;UART bit definitions
TXFE_BIT                EQU     10000000b ; TX FIFO full
RXFF_BIT                EQU     01000000b ; RX FIFO empty
BUSY_BIT                EQU     00001000b ; Busy


; PROGRAMA PRINCIPAL
; R4 operando 1 
; R5 operando 2
; R6 operação: 1 = +, 2 = -, 3 = *, 4 = /
; R7 contagem da quantidade de dígitos
; R8 sinal: 0=positivo e 1 = negativo
; R9 = 10, usado para multiplicar ou dividir por 10
__iar_program_start
        
main:   
        BL inicializa ;rotina de inicialização
        
loop:   
        MOV R4, #0
        MOV R5, #0    ;zera os operandos
        MOV R6, #0
        MOV R7, #0
        MOV R8, #0
        MOV R10, #0
        
parte1:        
        BL leituraUA  ;leitura de dados da UART

        TEQ R1, #'-'  ; sinal de número negativo
        ITT EQ
        MOVEQ R8, #1
        BEQ negativo
        
        BL coleta_operando
        MOV R4, R3    ;move dados coletados de R3 para R4                  
        CBNZ R2, parte2
        
        B parte1
negativo:
        BL enviaUA
parte2:
        BL leituraUA  ;leitura de dados da UART
        
        BL verifica_op ;verifica se foi pressionado caracter de operação
        CBNZ R6, op2     ;R6 = 0 indica que não há operação ainda

        BL coleta_operando
        TEQ R2, #0 
        BEQ parte2
        MUL R4, R9
        ADD R4, R3 ;move dados coletados de R3 para R4
        B parte2
        
op2:    BL enviaUA
        TEQ R8, #1
        IT EQ
        RSBEQ R4, #0
        MOV R7, #0
parte3:
        BL leituraUA  ;leitura de dados da UART
        
        TEQ R1, #'-'  ; sinal de número negativo
        ITT EQ
        MOVEQ R10, #1
        BEQ negativo2
        
        BL coleta_operando
        MOV R5, R3    ;move dados coletados de R3 para R5                 
        CBNZ R2, parte4
        B parte3
negativo2:
        BL enviaUA
parte4:
        BL leituraUA  ;leitura de dados da UART
        
        TEQ R1, #'='  
        BEQ operacao
        
        BL coleta_operando
        TEQ R2, #0 
        BEQ parte4
        MUL R5, R9
        ADD R5, R3 ;move dados coletados de R3 para R5
        B parte4
        
operacao: 
        TEQ R10, #1
        ITT EQ
        RSBEQ R5, #0
        ADDEQ R8, #1

        
        BL enviaUA
        
        TEQ R6, #1    ;operação +
        IT EQ
        BLEQ soma
        
        TEQ R6, #2    ;operação -
        IT EQ
        BLEQ subtracao
        
        TEQ R6, #3    ;operação *
        IT EQ
        BLEQ multiplicacao
        
        TEQ R6, #4    ;operação /
        IT EQ
        BLEQ divisao
        
        MOV R7, #0        ;zera contagem
separa_res:
        MOV R2, R4        ;salva valor R4
        SDIV R4, R9       ;divide resultado por 10
        MUL R1, R4, R9                             
        SUB R1, R2, R1    ;pega o resto da divisão
        ADD R1, #0x30
        PUSH {R1}
        ADD R7,#1
        CBZ R4, envia_res
        B separa_res
envia_res: 
        POP {R1}
        BL enviaUA
        SUB R7,#1
        CBZ R7, fim
        B envia_res
fim:       
        MOV R1, #'\r'  
        BL enviaUA
        MOV R1, #'\n'  
        BL enviaUA
        
        B loop

; SUB-ROTINAS

; soma: R4 = R4 + R5
; R4 = operando 1 e resultado
; R5 = operando 2

soma:
       PUSH {LR}
       ADDS R4, R5
       ITTT MI
       RSBMI R4, #0
       MOVMI R1, #'-'  
       BLMI enviaUA
       POP {PC}
       
; subtracao: R4 = R4 - R5
; R4 = operando 1 e resultado
; R5 = operando 2

subtracao:
       PUSH {LR}
       SUBS R4, R5
       ITTT MI
       RSBMI R4, #0
       MOVMI R1, #'-'  
       BLMI enviaUA
       POP {PC}
; multiplicacao: R4 = R4 * R5
; R4 = operando 1 e resultado
; R5 = operando 2

multiplicacao:
       PUSH {LR}
       MULS R4, R5
       ITTT MI
       RSBMI R4, #0
       MOVMI R1, #'-'  
       BLMI enviaUA
       POP {PC}
; divisao: R4 = R4 / R5
; R4 = operando 1 e resultado
; R5 = operando 2

divisao:
       PUSH {LR}
       TEQ R5, #0  ;divisão por zero
       ITT EQ
       MOVEQ R1, #'E'  
       BLEQ enviaUA
       
       BEQ fdiv
       
       SDIV R4, R5
       TEQ R8, #1
       ITTT EQ
       RSBEQ R4, #0
       MOVEQ R1, #'-'  
       BLEQ enviaUA
fdiv:       
       POP {PC}       
; coleta_operando: verifica operação
; R1 = dado da UART
; R2 = dado não coletado R2=0, dado coletado R2=1
; R3 = dado coletado
; R7 = conta dígitos coletados
coleta_operando:
        PUSH {LR}
        MOV R2, #0
        MOV R3, #0
        CMP R7, #2     ;se já foi coletado 3 dígitos, para a coleta
        BHI coleta_end
        
        CMP R1, #0x30
        BCC coleta_end      ;se for menor que 30 retorna
        SUB R1, #0x30 ;subtrai para comprar se são números de 0 a 9
        CMP R1, #9
        BHI coleta_end      ;se for maior que 9 retorna
        MOV R3, R1
        ADD R1, #0x30
        BL enviaUA    ;envia dados na UART
        MOV R2, #1
        ADD R7, #1    ;conta dígitos inteiros
coleta_end:
        POP {PC}
        
; verifica_op: verifica operação
; R1 = dado da UART
; R6 = operação: 1 = +, 2 = -, 3 = *, 4 = /
verifica_op:
        TEQ R1, #'+'
        IT EQ
        MOVEQ R6, #1
        TEQ R1, #'-'
        IT EQ
        MOVEQ R6, #2
        TEQ R1, #'*'
        IT EQ
        MOVEQ R6, #3
        TEQ R1, #'/'
        IT EQ
        MOVEQ R6, #4
        BX LR

; inicializa: rotina de inicialização
; Destrói: R0, R1 e R2
inicializa:
        PUSH {LR}
        MOV R2, #(UART0_BIT)
	BL UART_enable ; habilita clock ao port 0 de UART

        MOV R2, #(PORTA_BIT)
	BL GPIO_enable ; habilita clock ao port A de GPIO
        
	LDR R0, =GPIO_PORTA_BASE
        MOV R1, #00000011b ; bits 0 e 1 como especiais
        BL GPIO_special

	MOV R1, #0xFF ; máscara das funções especiais no port A (bits 1 e 0)
        MOV R2, #0x11  ; funções especiais RX e TX no port A (UART)
        BL GPIO_select

	LDR R0, =UART_PORT0_BASE
        BL UART_config ; configura periférico UART0
        
        MOV R9, #10   ;para multiplicação por 10

        POP {PC}
        

        END
