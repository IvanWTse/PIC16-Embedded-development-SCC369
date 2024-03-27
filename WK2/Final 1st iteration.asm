
;;main program here
;main:
;    MOVLW   0X01
;    ADDLW   0X01
;    GOTO    main
;    BANKSEL ANSELC	;   Could use MOVLB 3 to move to Bank 3
;    CLRF    ANSELC	;   Ensure configured for digital I/O (disable ADC)
;    CLRF    ANSELB
;    BANKSEL TRISC	;   Could use MOVLB 1 to move to Bank 1
;    CLRF    TRISC	;   PORTC all outputs
;    MOVLF   0XFF, TRISB
;    BANKSEL PORTC	;   Could use MOVLB 0 to move to Bank 0
;    CLRF    PORTC
;    
;LOOP:
;    btfss   PORTB, 4
;    BSF	    PORTC, 0
;    BTFSS   PORTB, 5
;    BSF	    PORTC, 1
;    BTFSS   PORTB ,6
;    BSF	    PORTC, 2
;    CLRF    PORTC
;    goto    LOOP
;    
;    goto main
;    
;
;;isr routine here    
;isr:
;    movlw 0xfe
;    goto isr
;    
;    
;
;
;

; PIC16F1507 Configuration Bit Settings

; Assembly source line config statements

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

  
MOVLF MACRO literal, reg
 MOVLW literal
 MOVWF reg mod 0x80
 ENDM

bDlyLpCount EQU 0X14
  
PSECT udata_bank0
GLOBAL	COUNTER
GLOBAL	COUNTER2
GLOBAL	TASK_COUNTER
GLOBAL	STU_ID
GLOBAL	TEMP1
GLOBAL	TEMP2
COUNTER:	DS  1
COUNTER2:	DS  1
TASK_COUNTER:	DS  1
STU_ID:		DS  8
TEMP1:		DS  1
TEMP2:		DS  1
  
;Instruction opcodes are 14 bits wide on this midline device (PIC16F1507).
  
;delta=2 flag indicates that 2 bytes reside at each address in memory space.

;Specify psect position for linker: 
  ; 1. Go to File>Project Properties> pic-as Global options> pic-as Linker in the IDE
  ; 2. Click on 'Custom Linker Options' > '...' and add the line below (excluding the ';')
;    -Pres_vect=0h     
  
PSECT res_vect, class=CODE, delta=2
res_vect:
    goto main
;===================;    
    
;Specify psect position for linker: 
;    -Pint_vect=4h 
PSECT int_vect, class=CODE, delta=2 
int_vect:
    goto isr
;===================;    
    
;the program psect is positioned automatically and so no corresponding linker entry is needed 
PSECT program, class=CODE, delta=2
;main program here
main:
    BANKSEL ANSELC	;   Could use MOVLB 3 to move to Bank 3
    CLRF    ANSELC	;   Ensure configured for digital I/O (disable ADC)
    CLRF    ANSELB	;   Ensure configured for digital I/O (disable ADC)
    BANKSEL TRISC	;   Could use MOVLB 1 to move to Bank 1
    CLRF    TRISC	;   PORTC all outputs
    MOVLF   0XFF, TRISB	;   PORTB all inputs
    BANKSEL PORTC	;   Could use MOVLB 0 to move to Bank 0
    CLRF    PORTC	;   Clear PORTC
    CLRF    FSR0H
    GOTO    TASK1
    
TEST:
    MOVF    PORTB, 0
    MOVWF   PORTC
    GOTO    TEST
    
WAIT_PB4_PRESS:
    BTFSS   PORTB, 4
    RETURN
    GOTO    WAIT_PB4_PRESS

WAIT_PB4_RELEASE:
    BTFSC   PORTB, 4
    RETURN
    GOTO    WAIT_PB4_RELEASE
    
TASK1:
    MOVLF   0XFF, PORTC
    CALL    WAIT_PB4_PRESS
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK2
    
TASK2:
    CLRF    PORTC
    CLRW
    MOVLF   0x03, STU_ID
    MOVLF   0X17, STU_ID+1
    MOVLF   0X28, STU_ID+2
    MOVLF   0X34, STU_ID+3
    MOVLF   0X45, STU_ID+4
    MOVLF   0X50, STU_ID+5
    MOVLF   0X63, STU_ID+6
    MOVLF   0X79, STU_ID+7
    CLRF    PORTC
    CLRW
    MOVLF   0X08, COUNTER
    MOVLF   0X23, FSR0L
TASK2_LOOP:
    MOVIW   FSR0++
TASK2_SHOW:
    MOVWF   PORTC
    BTFSC   PORTB, 5
    GOTO    TASK2_SHOW
    CALL    TASK2_PRTB5_PRESSED
    DECFSZ  COUNTER
    GOTO    TASK2_LOOP
    GOTO    TASK2_END
TASK2_PRTB5_PRESSED:
    BTFSS   PORTB, 5
    GOTO    TASK2_PRTB5_PRESSED
    RETURN
TASK2_END:
    MOVLF   0XFF, PORTC
    BTFSC   PORTB, 4
    GOTO    TASK2_END
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK3
    
TASK3:
    CLRF    COUNTER
    CLRF    COUNTER2
    CLRF    TEMP1
    CLRF    TEMP2
    BTFSS   PORTB, 4
    GOTO    TASK3_END

    MOVLW   0XFF
    BTFSS   PORTB, 5
    MOVWF   COUNTER
    BTFSS   PORTB, 6
    MOVWF   COUNTER2
    
    MOVF    COUNTER, 0
    XORLW   0XFF
    MOVWF   TEMP1
    MOVF    COUNTER2, 0
    XORLW   0XFF
    MOVWF   TEMP2
    ANDWF   TEMP1, 0
    BTFSC   WREG, 0
    GOTO    NB5NB6
    
    MOVF    COUNTER, 0
    XORLW   0XFF
    ANDWF   COUNTER2, 0
    BTFSC   WREG, 0
    GOTO    NB5B6
    
    MOVF    COUNTER2, 0
    XORLW   0XFF
    ANDWF   COUNTER, 0
    BTFSC   WREG, 0
    GOTO    B5NB6
    
    MOVF    COUNTER, 0
    ANDWF   COUNTER2, 0
    BTFSC   WREG, 0
    GOTO    B5B6
    
NB5NB6:
    MOVLW   11100000B
    MOVWF   PORTC
    GOTO    TASK3
B5NB6:
    MOVLW   01010101B
    MOVWF   PORTC
    GOTO    TASK3
NB5B6:
    MOVLW   00110110B
    MOVWF   PORTC
    GOTO    TASK3
B5B6:
    MOVLW   00001111B
    MOVWF   PORTC
    GOTO    TASK3

TASK3_END:
    CALL    WAIT_PB4_RELEASE
    MOVLF   0XFF, PORTC
    BTFSC   PORTB, 4
    GOTO    TASK3_END
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK4
    
TASK4:
    CLRF    COUNTER
    CLRF    COUNTER2
    CLRF    PORTC
TASK4_COUNT:
    CALL    DELAY
    INCF    PORTC, F
    BTFSC   PORTB, 4
    GOTO    TASK4_COUNT
    CALL    WAIT_PB4_RELEASE
    MOVLF   0XFF, PORTC
    CALL    WAIT_PB4_PRESS
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK5
        
DELAY:
    MOVLW   bDlyLpCount		;   Reset outer loop count
    MOVWF   COUNTER2

DL_OUTER:
    MOVLW   0xFF		;   Reset inner loop count
    MOVWF   COUNTER

DL_INNER:
    DECFSZ  COUNTER, F	;   Break inner loop if zero
    GOTO    DL_INNER

    DECFSZ  COUNTER2, F	;   Break outer loop if zero
    GOTO    DL_OUTER

    RETURN
    
TASK5:
    MOVLF   0X01, PORTC
    CLRF    COUNTER
    CLRF    COUNTER2
TASK5_LLOOP:
    LSLF    PORTC, 1
    BTFSS   PORTB, 4
    GOTO    TASK1
    CALL    DELAY
    BTFSC   PORTC, 7
    GOTO    TASK5_RLOOP
    BTFSC   PORTB, 4
    GOTO    TASK5_LLOOP
    CALL    WAIT_PB4_RELEASE
    MOVLF   0XFF, PORTC
    CALL    WAIT_PB4_PRESS
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK2
TASK5_RLOOP:
    LSRF    PORTC, 1
    BTFSS   PORTB, 4
    GOTO    TASK1
    CALL    DELAY
    BTFSC   PORTC, 0
    GOTO    TASK5_LLOOP
    BTFSC   PORTB, 4
    GOTO    TASK5_RLOOP
    CALL    WAIT_PB4_RELEASE
    MOVLF   0XFF, PORTC
    CALL    WAIT_PB4_PRESS
    CALL    WAIT_PB4_RELEASE
    GOTO    TASK2
    
;isr routine here    
isr:
    movlw 0xfe
    goto isr
    
