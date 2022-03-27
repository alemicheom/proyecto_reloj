PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = ON            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = ON              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
  
#include <xc.inc>
  
  
; -------------- MACROS ---------------
  
  ; Macro para reiniciar el valor del TMR0
  ; **Recibe el valor a configurar en TMR_VAR**
  RESET_TMR0 MACRO TMR_VAR
    BANKSEL PORTA	   
    MOVLW   TMR_VAR
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
; Macro para reiniciar el valor del TMR1 
; Recibe el valor a configurar en TMR1_H y TMR1_L

RESET_TMR1 MACRO TMR1_H, TMR1_L	
 
    BANKSEL TMR1H
    MOVLW   TMR1_H	    ; Literal a guardar en TMR1H
    MOVWF   TMR1H	    ; Guardamos literal en TMR1H
    MOVLW   TMR1_L	    ; Literal a guardar en TMR1L
    MOVWF   TMR1L	    ; Guardamos literal en TMR1L
    BCF	    TMR1IF	    ; Limpiamos bandera de int. TMR1
    ENDM

;------------ VECTOR RESET ------------
  
PSECT resVect, class=CODE, abs, delta=2
  
ORG 00h			; posición 0000h para el reset
  
resetVec:
    PAGESEL MAIN	; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
PSECT udata_bank0
    banderas:		DS 1	; Indica que display hay que encender
    nibbles:		DS 4	; Contiene los nibbles alto y bajo de valor
    display:		DS 4	; Representación de cada nibble en el display de 7-seg
    
    segundos:		DS 1	; clock inc cada segundo 
    minuto:		DS 2	; suma 1 min después de 60 sec
    hora:		DS 2	; suma 1 hora después de 59 min
    
    segundo_tmr:	DS 2    ; para segundos timer 
    minuto_tmr:		DS 2	; para minutos timer
    
    dia:		DS 2	; variable para dia
    mes:		DS 2	; varaibale para mes 
    
    estado:		DS 1	; para cambiar de estado hora -> fecha -> timer
    up:			DS 1	; boton inc
    down:		DS 1	; boton dec
    start:		DS 1	; empieza a contar el reloj automático 
    start_tmr:		DS 1
    
   
;---------- INTERRUPCIONES-------------
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h			; posición 0004h para interrupciones
  
PUSH:
    MOVWF   W_TEMP		; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP		; Guardamos STATUS
    
ISR:
    BTFSC   T0IF		; Interrupción de TMR0 muestra displays 
    CALL    INT_TMR0
    
    BTFSC   TMR1IF		; Interrupcion de TMR1 cuenta segundos 
    CALL    INT_TMR1
    
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB		; Interrupción de PORTB
    
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS		; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W		; Recuperamos valor de W
    RETFIE			; Regresamos a ciclo principal
    
;------------ subrutinas de interrupciones----------
    
INT_TMR0:
    RESET_TMR0 255		; Reiniciamos TMR0
    CALL    MOSTRAR_VALOR	; Mostramos valor en hexadecimal en los displays
    RETURN 
    
INT_TMR1:
    RESET_TMR1 0xB, 0xCD    ; Reiniciamos TMR1 para 1s
    
    BTFSS   estado, 0	    ; estado en reloj
    CALL    TMR_ESTADO_RELOJ
    
    
    BTFSC   estado, 1	    ; estado en timer
    CALL    TMR_ESTADO_TIMER
    
    RETURN
    
    TMR_ESTADO_TIMER:
	BTFSC   start_tmr, 0	    ; solo cuenta segundos cuando se presinona boton de start 
	DECF    segundo_tmr
	
	RETURN
	
    TMR_ESTADO_RELOJ:
	BTFSC   start, 0	     
	INCF    segundos
	RETURN
	
	
INT_PORTB:
    BTFSS   PORTB, 4	    ; cambio de estado
    INCF    estado
    
    BTFSS   estado, 0	    ; estado en reloj
    CALL    INT_ESTADO_RELOJ
    
    BTFSC   estado, 0	    ; estado en fecha 
    CALL    INT_ESTADO_FECHA
    
    BTFSC   estado, 1	    ; estado en timer
    CALL    INT_ESTADO_TIMER
    
    MOVLW   3			; variable estado se reinicia 
    SUBWF   estado,W	   
    BTFSC   STATUS, 2
    CLRF    estado  
    
    BCF	    RBIF
    RETURN
    
INT_ESTADO_RELOJ:
    BTFSS   PORTB, 0
    INCF    up		    ; incrementar reloj
    
    BTFSS   PORTB, 1
    INCF    down	    ; decrementar reloj
	
    BTFSS   PORTB, 3
    INCF    start	    ; empezar reloj automático 
    
    RETURN
    
INT_ESTADO_FECHA:
    
    RETURN
    
INT_ESTADO_TIMER:  
    BTFSS   PORTB, 1
    INCF    up
    
    BTFSS   PORTB, 2
    INCF    down
    
    BTFSS   PORTB, 3
    INCF    start_tmr	    ; empezar reloj automático 
    
    RETURN
    
;------------- CONFIGURACION --------------
   
MAIN: 
   CALL CONFIG_RELOJ 
   CALL CONFIG_TMR0
   CALL CONFIG_TMR1	  
   CALL CONFIG_IO
   CALL CONFIG_INT
   CALL CONFIG_IOCB
   
LOOP:
    BANKSEL PORTA
    CALL    CAMBIO_ESTADO
    GOTO    LOOP
    

;-----------rutinas para cambio de estado------------
    
CAMBIO_ESTADO:
    BANKSEL PORTA
    
    BTFSC   estado, 1		; estado en timer 
    GOTO    ESTADO_TIMER
    BTFSS   estado, 0		; estado en reloj
    GOTO    ESTADO_RELOJ		
    BTFSC   estado, 0		; estado en fecha
    GOTO    ESTADO_FECHA
    return 
    
ESTADO_RELOJ:
    BCF	    PORTE, 2
    BSF	    PORTE, 0
    
    CALL    MOSTRAR_DISPLAY	; mover variables de tiempo a su display respectivo
    
    
    BTFSC   up, 0		; ir a rutina de dec caundo inc es uno 
    CALL    EDITAR_RELOJ_INC
    
    BTFSC   down, 0		; ir a rutina de dec caundo down es uno 
    CALL    EDITAR_RELOJ_DEC
    
    BTFSC   start, 0
    CALL    RELOJ_AUTO
   
    
    BTFSC   start, 1		; iniciar o pausar el reloj 
    CLRF    start
    
    return
ESTADO_FECHA:
    BSF	    PORTE, 1
    BCF	    PORTE, 0
    
    CALL    MOSTRAR_DISPLAY_FECHA
    
    return
    
ESTADO_TIMER:
    BCF	    PORTE, 1
    BSF	    PORTE, 2 
    
    CALL    MOSTRAR_DISPLAY_TIMER
    
    BTFSC   up, 0		; ir a rutina de dec caundo inc es uno 
    CALL    EDITAR_TIMER_INC
    
    BTFSC   down, 0		; ir a rutina de dec caundo down es uno 
    CALL    EDITAR_TIMER_DEC
    
    BTFSC   start_tmr, 0
    CALL    TIMER_AUTO
   
    BTFSC   start_tmr, 1		; iniciar o pausar el reloj 
    CLRF    start_tmr
    
    return 
    	
;-----------rutinas para reloj----------------
    
EDITAR_RELOJ_INC:  
    INCF    minuto
    
    MOVLW   10		    ; display llega hasta 00:09  
    SUBWF   minuto,W
    BTFSC   STATUS, 2 
    GOTO    RELOJ_MIN_2
    
    CLRF    up
    return 
   
    
RELOJ_AUTO:		    ; rutina para que el reloj cuente solo 
    MOVLW   60		    ; suma 1 min después de 60 sec
    SUBWF   segundos,W
    BTFSC   STATUS, 2
    GOTO    RELOJ_MIN_1
    
    return 
    
RELOJ_MIN_1:		    ; rutina para que el reloj cuente solo 
    CLRF    segundos	    ; empieza el conteo otravez 
    INCF    minuto
                         
    MOVLW   10		    ; display llega hasta 00:09  
    SUBWF   minuto,W
    BTFSC   STATUS, 2 
    GOTO    RELOJ_MIN_2  
    
    CLRF    up
    return 
    
RELOJ_MIN_2:		    ; rutina para que el reloj cuente solo 
    CLRF    minuto
    incf    minuto+1
                              
    MOVLW   6		    ; display llega hasta 00:59
    SUBWF   minuto+1,W
    BTFSC   STATUS, 2 
    GOTO    RELOJ_HORA_1
    
    CLRF    up
    return
    
RELOJ_HORA_1:		    ; rutina para que el reloj cuente solo 
    CLRF    minuto+1
    incf    hora
    
    MOVLW   1
    SUBWF   hora+1, W	    ; cuando hora2 no esta en más de 1 segundo display llega a 09:59
    BTFSC   STATUS, 2
    MOVLW   10 
    BTFSC   STATUS,2
    goto    $+2
    
    MOVLW   4		    ; cuando hora2 esta en más de 1 segundo display llega a 23:59
    SUBWF   hora,W
    BTFSC   STATUS, 2 
    GOTO    RELOJ_HORA_2  
    
    CLRF    up
    return   
    
RELOJ_HORA_2:		    ; rutina para que el reloj cuente solo 
    CLRF    hora
    incf    hora+1
                           
    MOVLW   3		    ;  llega a 20:00   
    SUBWF   hora+1,W
    BTFSC   STATUS, 2 
    GOTO    RELOJ_RESET_FINAL
    
    CLRF    up
    return  
    
RELOJ_RESET_FINAL:	    ;reset cuando el reloj llega a 24:00 
    RESET_TMR1 0xB, 0xCD 
    CLRF    segundos
    CLRF    minuto
    CLRF    minuto+1
    CLRF    hora
    CLRF    hora+1
    CLRF    up
    return
    
 ;--------- rutinas para reloj dec --------
    
EDITAR_RELOJ_DEC:
    MOVLW   255		    

    DECF    minuto   
    SUBWF   minuto,W
    BTFSC   STATUS, 2 
    GOTO    DEC_RELOJ_MIN_2	    ; cuando minutos esta en en 0 decrementar min2
    
    CLRF    down
    return 
        
    
DEC_RELOJ_MIN_2:
    
    MOVLW   9			    ; poner min en 9 cuando min2 decrementa
    MOVWF   minuto
    DECF    minuto+1
   
    MOVLW   255		    
    SUBWF   minuto+1,W
    BTFSC   STATUS, 2 
    GOTO    DEC_RELOJ_HORA_1	    ; cuando min2 esta en 0 decrementar hora 
    
    CLRF    down
    return
    
DEC_RELOJ_HORA_1:
    
    MOVLW   5			    ; cuando 00:00 y se hace dec poner 23:59
    MOVWF   minuto+1
    DECF    hora
    
    
    MOVLW   255		    
    SUBWF   hora,W
    BTFSC   STATUS, 2 
    GOTO    DEC_RELOJ_HORA_2	    ; cuando hora esta en 0 decrementar hora2
    
    CLRF down
    return   
    
DEC_RELOJ_HORA_2:
    
    MOVLW   9
    MOVWF   hora
    DECF    hora+1
        
    MOVLW   255		    
    SUBWF   hora+1,W
    BTFSC   STATUS, 2 
    GOTO    UNDERFLOW		    ; cuando hora esta en 0 decrementar hora2
    
    CLRF down
    return  
    
UNDERFLOW:
    MOVLW 2			    ; cuando 00:00 y se hace dec poner 23:59
    MOVWF  hora+1
    
    MOVLW 3			    ; cuando 00:00 y se hace dec poner 23:59
    MOVWF  hora
    
    CLRF down
    return
    
    
 ;----------- RUTINAS FECHA --------------

EDITAR_FECHA1: 
    incf    dia 
    
    MOVLW   32		    ; display llega hasta 30:00 
    SUBWF   dia,W
    BTFSC   STATUS, 2
    CALL    febrero
    CLRF    up
    
   return
    
febrero:
    incf mes
    
    return 

 ;------------ RUTINAS TIMER -------------
 
EDITAR_TIMER_INC:	    ; rutina para inc timer  
    INCF    segundo_tmr
    
    MOVLW   10		    ; display llega hasta 00:09  
    SUBWF   segundo_tmr,W
    BTFSC   STATUS, 2 
    GOTO    TIMER_SEC_2
    
    CLRF    up
    return 
    
TIMER_SEC_2:		 
    CLRF    segundo_tmr
    incf    segundo_tmr+1
                              
    MOVLW   6		    ; display llega hasta 00:59
    SUBWF   segundo_tmr+1,W
    BTFSC   STATUS, 2 
    GOTO    TIMER_MIN_1
    
    CLRF    up
    return
    
TIMER_MIN_1:		    
    CLRF    segundo_tmr+1
    incf    minuto_tmr
     
    MOVLW   10		    ; display llega a 09:00
    SUBWF   minuto_tmr,W
    BTFSC   STATUS, 2 
    GOTO    TIMER_MIN_2  
    
    CLRF    up
    return   
    
TIMER_MIN_2:		    ; rutina para que el reloj cuente solo 
    CLRF    minuto_tmr
    incf    minuto_tmr+1
                           
    MOVLW   10		    ;  llega a 20:00   
    SUBWF   minuto_tmr+1,W
    BTFSC   STATUS, 2 
    GOTO    TIMER_RESET_FINAL
    
    CLRF    up
    return  
    
TIMER_RESET_FINAL:	    ;reset cuando el reloj llega a 24:00 
    CLRF    segundo_tmr
    CLRF    segundo_tmr+1
    CLRF    minuto_tmr
    CLRF    minuto_tmr+1
    CLRF    up
    return    
 
;--------- rutinas para timer dec --------
    
TIMER_AUTO:		    ; rutina para que el reloj cuente solo 
    MOVLW   255		    
    SUBWF   segundo_tmr,W
    BTFSC   STATUS, 2
    GOTO    DEC_TIMER_SEC_2
    
    return
    
EDITAR_TIMER_DEC:
    MOVLW   255		    

    DECF    segundo_tmr   
    SUBWF   segundo_tmr,W
    BTFSC   STATUS, 2 
    GOTO    DEC_TIMER_SEC_2	    ; cuando minutos esta en en 0 decrementar min2
    
    CLRF    down
    return 
        
    
DEC_TIMER_SEC_2:
    
    MOVLW   9			    ; poner min en 9 cuando min2 decrementa
    MOVWF   segundo_tmr
    DECF    segundo_tmr+1
   
    MOVLW   255		    
    SUBWF   segundo_tmr+1,W
    BTFSC   STATUS, 2 
    GOTO    DEC_TIMER_MIN_1	    ; cuando min2 esta en 0 decrementar hora 
    
    CLRF    down
    return
    
DEC_TIMER_MIN_1:
    
    MOVLW   5			    ; cuando 00:00 y se hace dec poner 23:59
    MOVWF   segundo_tmr+1
    DECF    minuto_tmr
    
    
    MOVLW   255		    
    SUBWF   minuto_tmr,W
    BTFSC   STATUS, 2 
    GOTO    DEC_TIMER_MIN_2	    ; cuando hora esta en 0 decrementar hora2
    
    CLRF down
    return   
    
DEC_TIMER_MIN_2:
    
    MOVLW   9
    MOVWF   minuto_tmr
    DECF    minuto_tmr+1
        
    MOVLW   255		    
    SUBWF   minuto_tmr+1,W
    BTFSC   STATUS, 2 
    GOTO    UNDERFLOW_TMR	    ; cuando hora esta en 0 decrementar hora2
    
    CLRF down
    return  
    
UNDERFLOW_TMR:
    MOVLW  9			    ; cuando 00:00 y se hace dec poner 23:59
    MOVWF  minuto_tmr+1
     
    RESET_TMR1 0xB, 0xCD 
    CLRF down
    return
    
 ;------------- SUBRUTINAS ---------------
CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	    ; I/O digitales
    
    BANKSEL TRISC           ; output para display 
    CLRF    TRISC
    
    BANKSEL PORTC
    CLRF    PORTC
    
    BANKSEL TRISD           ; para banderas de display
    BCF     TRISD, 0
    BCF     TRISD, 1
    BCF	    TRISD, 2
    BCF	    TRISD, 3
    
    BANKSEL PORTD
    CLRF    PORTD
    
    BANKSEL TRISB           ; para pushbuttons 
    BSF     TRISB, 0	    ; display up
    BSF     TRISB, 1	    ; display down
    BSF	    TRISB, 2	    ; editar/aceptar 
    BSF	    TRISB, 3	    ; iniciar/parar
    BSF	    TRISB, 4	    ; cabiar de estado hora -> fecha -> timer
    
    BANKSEL PORTB
    CLRF    PORTB
    
    BANKSEL OPTION_REG
    BCF     OPTION_REG, 7   ; RBPU (port B pull up enable bit)
    BSF     WPUB, 0	    ; Weak pull up register bit portb 0
    BSF     WPUB, 1         ; Weak pull up register bit portb 1 
    BSF     WPUB, 2         ; Weak pull up register bit portb 2
    BSF     WPUB, 3         ; Weak pull up register bit portb 3
    BSF     WPUB, 4         ; Weak pull up register bit portb 4
    
    
    CLRF    banderas 
    
  
    BANKSEL TRISA           ; output para demostrar estado de configuración 
    CLRF    TRISA
    
    BANKSEL PORTA
    CLRF    PORTA
    
    BANKSEL TRISE           ; demuestra el estado 
    CLRF    TRISE
    
    BANKSEL PORTE
    CLRF    PORTE
    RETURN
    
CONFIG_RELOJ:
    BANKSEL OSCCON	    ; cambiamos a banco 1
    BSF	    OSCCON, 0	    ; SCS -> 1, Usamos reloj interno
    BCF	    OSCCON, 6
    BSF	    OSCCON, 5
    BSF	    OSCCON, 4	    ; IRCF<2:0> -> 011 500kHz
    RETURN
    
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    T0CS		; TMR0 como temporizador
    BCF	    PSA			; prescaler a TMR0
    BSF	    PS2
    BSF	    PS1
    BSF	    PS0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0 255		; Reiniciamos TMR0 para 50ms
    RETURN 
    
CONFIG_TMR1:
    BANKSEL T1CON	    ; Cambiamos a banco 00
    BCF	    TMR1CS	    ; Reloj interno
    BCF	    T1OSCEN	    ; Apagamos LP
    
    BCF	    T1CKPS1	    ; Prescaler 1:4
    BSF	    T1CKPS0
    
    BCF	    TMR1GE	    ; TMR1 siempre contando
    BSF	    TMR1ON	    ; Encendemos TMR1
    
    RESET_TMR1 0xB, 0xCD   ; TMR1 a 1s
    RETURN
    
    
 CONFIG_IOCB:
    BANKSEL TRISA
    BSF     IOCB, 0	    ; display up
    BSF     IOCB, 1	    ; display down
    BSF     IOCB, 2	    ; editar/aceptar 
    BSF     IOCB, 3	    ; iniicar/parar
    BSF     IOCB, 4	    ; cabiar de estado hora -> fecha -> timer
    RETURN
    
CONFIG_INT:
    BANKSEL PIE1
    BSF	    TMR1IE	    ; int. TMR1
    BSF	    TMR2IE	    ; int. TMR1
    
    BANKSEL INTCON 
    BSF     GIE             ; Habilitamos interrupciones 
    BSF	    PEIE	    ; int. perifericas 
    BSF     T0IE	    ; int. TMR0
    BSF     RBIE	    ; int. PORTB
    
    BANKSEL PORTA
    BCF	    TMR1IF	    ; Limpiamos bandera de TMR1
    BCF	    RBIF	    ; Limpiamos bandera de int. de PORTB
    BCF     T0IF	    ; int. TMR0
    return
    
 ;-------- subrutinas para multiplexado --------
    
MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display nibble
    BCF	    PORTD, 1		; Apagamos display nibble+1
    BCF	    PORTD, 2		; Apagamos display nibble+2
    BCF	    PORTD, 3		; Apagamos display nibble+3
    
    BTFSC   banderas, 0		; Verificamos bandera 0
    GOTO    DISPLAY_0		
    BTFSC   banderas, 1		; Verificamos bandera 1
    GOTO    DISPLAY_1
    BTFSC   banderas, 2		; Verificamos bandera 2
    GOTO    DISPLAY_2
    BTFSC   banderas, 3		; Verificamos bandera 3
    GOTO    DISPLAY_3
    
   DISPLAY_0:			
	MOVF    display, W	; Movemos display a W
	MOVWF   PORTC		
	BSF	PORTD, 3	; Encendemos display de nibble bajo
	BCF	banderas, 0	; Apagamos la bandera actual
	BSF	banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

    DISPLAY_1:
	MOVF    display+1, W	; Movemos display+1 a W
	MOVWF   PORTC		
	BSF	PORTD, 2	; Encendemos display de nibble+1
	BCF	banderas, 1	
	BSF	banderas, 2	
    RETURN
	
    DISPLAY_2:
	MOVF    display+2, W	; Movemos display+2 a W
	MOVWF   PORTC		
	BSF	PORTD, 1 	; Encendemos display de nibble+2
	BCF	banderas, 2	
	BSF	banderas, 3	
    RETURN		
	

    DISPLAY_3:
	MOVF    display+3, W	; Movemos display+3 a W
	MOVWF   PORTC		
	BSF	PORTD, 0	; Encendemos display de nibble alto
	CLRF    banderas 
    RETURN
	
MOSTRAR_DISPLAY:
    BANKSEL PORTA
    MOVF    minuto, W		
    CALL    TABLE		
    MOVWF   display	
    
    MOVF    minuto+1, W		
    CALL    TABLE	  
    MOVWF   display+1		
    
    MOVF    hora, W		
    CALL    TABLE		
    MOVWF   display+2		
    
    MOVF    hora+1, W		
    CALL    TABLE	
    MOVWF   display+3
    
    RETURN

MOSTRAR_DISPLAY_FECHA:
    BANKSEL PORTA
    MOVF    dia, W		
    CALL    TABLE		
    MOVWF   display+2	
    
    MOVF    dia+1, W		
    CALL    TABLE	  
    MOVWF   display+3		
    
    MOVF    mes, W		
    CALL    TABLE		
    MOVWF   display		
    
    MOVF    mes+1, W		
    CALL    TABLE	
    MOVWF   display+1
    
    RETURN
    
MOSTRAR_DISPLAY_TIMER:
    BANKSEL PORTA
    
    MOVF    segundo_tmr, W		
    CALL    TABLE		
    MOVWF   display	
    
    MOVF    segundo_tmr+1, W		
    CALL    TABLE	  
    MOVWF   display+1		
    
    MOVF    minuto_tmr, W		
    CALL    TABLE		
    MOVWF   display+2		
    
    MOVF    minuto_tmr+1, W		
    CALL    TABLE	
    MOVWF   display+3
    
    RETURN
    

;--------- tabla para displays------------
  
  ORG 200h
 
 TABLE:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    
    
END
    
