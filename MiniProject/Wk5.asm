


TITLE	    "Comms"
SUBTITLE    "SCC369 Assessment 3 WK5-6"
    
PROCESSOR   16F1507

#include <xc.inc>

; CONFIG1
  CONFIG  FOSC = INTOSC         ; Oscillator Selection bits (Internal Oscillator, I/O Function on OSC1)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable (WDT disabled)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable (PWRT disabled)
  CONFIG  MCLRE = ON            ; MCLR Pin Function Select (MCLR/VPP pin function is MCLR)
  CONFIG  CP = OFF              ; Flash Program Memory Code Protection (Program memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown-out Reset Enable (Brown-out Reset disabled)
  CONFIG  CLKOUTEN = OFF        ; Clock Out Enable (CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin)

; CONFIG2
  CONFIG  WRT = OFF             ; Flash Memory Self-Write Protection (Write protection off)
  CONFIG  STVREN = ON           ; Stack Overflow/Underflow Reset Enable (Stack Overflow or Underflow will cause a Reset)
  CONFIG  BORV = LO             ; Brown-out Reset Voltage Selection (Brown-out Reset Voltage (Vbor), low trip point selected.)
  CONFIG  LPBOR = OFF           ; Low-Power Brown Out Reset (Low-Power BOR is disabled)
  CONFIG  LVP = ON              ; Low-Voltage Programming Enable (Low-voltage programming enabled)

  
MOVLF MACRO LITERAL, REG
 MOVLW LITERAL
 MOVWF REG mod 0x80
 ENDM

MOVFF	MACRO REG1, REG2
 MOVF	REG1, W
 MOVWF	REG2
 ENDM

SUBLF	MACRO LITERAL, REG, DEST
 MOVLW	LITERAL
 SUBWF	REG, DEST
 ENDM
  
PSECT udata_bank0
 GLOBAL	TEMP
 GLOBAL	COUNT_INNER
 GLOBAL	COUNT_OUTER
 GLOBAL	R3_COUNTER
 
    TEMP:		DS  1
    COUNT_INNER:	DS  1
    COUNT_OUTER:	DS  1
    R3_COUNTER:		DS  1
  
;Instruction opcodes are 14 bits wide on this midline device (PIC16F1507).
  
;delta=2 flag indicates that 2 bytes reside at each address in memory space.

;Specify psect position for linker: 
  ; 1. Go to File>Project Properties> pic-as Global options> pic-as Linker in the IDE
  ; 2. Click on 'Custom Linker Options' > '...' and add the line below (excluding the ';')
;    -Pres_vect=0h     
  
PSECT res_vect, class=CODE, delta=2
res_vect:
    goto MAIN
;===================;    
    
;Specify psect position for linker: 
;    -Pint_vect=4h 
PSECT int_vect, class=CODE, delta=2 
int_vect:
    goto ISR
;===================;    
    
;the program psect is positioned automatically and so no corresponding linker entry is needed 
PSECT program, class=CODE, delta=2
;main program here
MAIN:
    BANKSEL ANSELC		;   Could use MOVLB 3 to move to Bank 3
    CLRF    ANSELC		;   Ensure configured for digital I/O (disable ADC)
    CLRF    ANSELB		;   Ensure configured for digital I/O (disable ADC)
    BANKSEL TRISC		;   Could use MOVLB 1 to move to Bank 1
    CLRF    TRISC		;   PORTC all outputs
    MOVLF   0XFF, TRISB		;   PORTB all inputs
    BANKSEL WPUB
    MOVLF   0XFF, WPUB		;   Enable all internal weak pull-up of PORTB
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    
    ; PWM1 configuration
    BANKSEL PIR1		; Clear the timer2 flag
    BCF	    PIR1, 1
    BANKSEL T2CON		; Set the timer2 prescaler to 1:1
    BCF	    T2CON, 0
    BCF	    T2CON, 1
    BANKSEL PWM1CON		; Get timer2 ready for output PWM
    MOVLF   0XE0, PWM1CON
    
    ; IOC configuration
    BANKSEL INTCON
    MOVLF   0XC8, INTCON	; Set GIE, PEIE and IOCIE. Clear others
    BANKSEL IOCBN
    MOVLF   0X70, IOCBN		; IOC listening for PORTB.456 at negative
    MOVLF   0X40, IOCBP		; IOC listening for PORTB.6 at positive which is the sensor
    BANKSEL PORTC
    CLRF    PORTC
LOOP:
    BANKSEL PORTC
    BTFSS   PORTB, 4
    CALL    STOP_PLAYING
    BTFSC   PORTB, 6
    CALL    PLAY250HZ
    GOTO    LOOP
    
PLAY1KHZ:
    BANKSEL PR2
    MOVLF   0X7C, PR2
    BANKSEL PWM1DCH
    MOVLF   0X3E, PWM1DCH
    MOVLF   0X80, PWM1DCL
    BANKSEL T2CON		; Set the TIMER2 prescaler to 1:1
    MOVLW   0XFC
    ANDWF   T2CON, F
    BSF	    T2CON, 2
    BANKSEL PORTC
    RETURN
    
PLAY500HZ:
    BANKSEL PR2
    MOVLF   0XF9, PR2
    BANKSEL PWM1DCH
    MOVLF   0X7D, PWM1DCH
    MOVLF   0X00, PWM1DCL
    BANKSEL T2CON
    MOVLW   0XFC
    ANDWF   T2CON, F
    BSF	    T2CON, 2
    BANKSEL PORTC
    RETURN
    
PLAY250HZ:
    BANKSEL PR2
    MOVLF   0X7C, PR2
    BANKSEL PWM1DCH
    MOVLF   0X3E, PWM1DCH
    MOVLF   0X80, PWM1DCL
    BANKSEL T2CON		; Set the TIMER2 prescaler to 1:4
    BSF	    T2CON, 0
    BCF	    T2CON, 1
    BSF	    T2CON, 2
    BANKSEL PORTC
    RETURN
    
STOP_PLAYING:
    BANKSEL T2CON
    BCF	    T2CON, 2
    BANKSEL PORTC
    RETURN
    
; =======================================
;   SUBR    DELAY
;   PARAM   None
;   RETURN  None
;   WRITES  W, COUNT_INNER, COUNT_OUTER
;
;   DESCR   Long delay using nested loop
;
;   CONFIG  bDlyLpCount	# Byte 0..255: Number of iterations for outer loop
;   CALLS   None
; =======================================
DELAY:
DL_OUTER:
    MOVLW   0xFF		;   Reset inner loop count
    MOVWF   COUNT_INNER

DL_INNER:
    DECFSZ  COUNT_INNER, F	;   Break inner loop if zero
    GOTO    DL_INNER

    DECFSZ  COUNT_OUTER, F	;   Break outer loop if zero
    GOTO    DL_OUTER

    RETURN

ISR:
    BANKSEL IOCBF
    BTFSC   IOCBF, 5
    GOTO    ISR_R3_TRIGGER
    BANKSEL PIR1
    BTFSC   PIR1, 0
    GOTO    ISR_R3
    
    GOTO    ISR_FINALLY
    
ISR_R3_TRIGGER:
    BANKSEL PORTC
    MOVLF   0X1E, R3_COUNTER
    BANKSEL TMR1H
    MOVLF   0X0B, TMR1H
    MOVLF   0XDC, TMR1L
    BANKSEL PIE1
    BSF	    PIE1, 0		; Set TIMER1 enable
    BANKSEL T1CON
    MOVLF   00010101B, T1CON	; Set TIMER1 to instruction clock, 1:2 prescaler, not sync and stop TIMER1
    GOTO    ISR_FINALLY
    
ISR_R3:
    
    
ISR_FINALLY:
    BANKSEL IOCBF
    CLRF    IOCBF
    BANKSEL INTCON
    BCF	    INTCON, 0
    BCF	    PORTC, 7
    RETFIE

    

    
END