


TITLE	    "Clock"
SUBTITLE    "SCC369 Assessment 2 WK3-4"
    
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

  
MOVLF MACRO literal, reg
 MOVLW literal
 MOVWF reg mod 0x80
 ENDM

MOVFF	MACRO REG1, REG2
 MOVF	REG1, W
 MOVWF	REG2
 ENDM
  
PSECT udata_bank0
GLOBAL	COUNTER
GLOBAL	COUNTER2
GLOBAL	OUTERCOUNT
GLOBAL	INNERCOUNT
GLOBAL	TEMP			; Temporary register, in this program, it will only be used to save the reset boundary value
GLOBAL	MODE			; The status mode register. The first bit will be record the master/slave status. 1: master mode. 0: slave mode

COUNTER:	DS  1
COUNTER2:	DS  1
OUTERCOUNT:	DS  1
INNERCOUNT:	DS  1
TEMP:		DS  1
MODE:		DS  1
  
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
    MOVLF   0XDF, TRISB	;   PORTB all inputs
    BANKSEL WPUB
    MOVLW   0XDF
    MOVWF   WPUB
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7
    BANKSEL PORTC	;   Could use MOVLB 0 to move to Bank 0
    CLRF    PORTC	;   Clear PORTC
    CLRF    FSR0H
    MOVLF   0XFF, INNERCOUNT
    GOTO    TASK5
   
 DELAY:			;   Delay for 4+3*INNERCOUNT*OUTERCOUNT
    MOVFF   OUTERCOUNT, COUNTER2
 DL_OUTER:
    MOVFF   INNERCOUNT, COUNTER
 DL_INNER:
    DECFSZ  COUNTER, F	;   Break inner loop if zero
    GOTO    DL_INNER
    DECFSZ  COUNTER2, F	;   Break outer loop if zero
    GOTO    DL_OUTER
    RETURN
 
WAIT_UNTIL_PB7_RELEASE:
    BANKSEL PORTB
    BTFSS   PORTB, 7
    GOTO    WAIT_UNTIL_PB7_RELEASE
    RETURN
    
 ;=========================================;
 ;  Test subroutine for debuging, useless
 ;=========================================;
TEST:
    MOVF    PORTB, 0
    MOVWF   PORTC
    GOTO    TEST
    
TASK1:
    CLRF    PORTC
    MOVLF   0XA3, OUTERCOUNT
TASK1_LOOP:
    INCF    PORTC, F
    CALL    DELAY
    GOTO    TASK1_LOOP

TASK2:
    CLRF    PORTC
    MOVLF   0XA3, OUTERCOUNT
    MOVLF   0X3C, TEMP
TASK2_LOOP:
    CALL    DELAY
    INCF    PORTC, F
    MOVF    PORTC, W
    SUBWF   TEMP, W
    BTFSC   STATUS, 2
    CLRF    PORTC
    GOTO    TASK2_LOOP
    
TASK3:
    BANKSEL INTCON
    MOVLF   0XC8, INTCON    ; Set GIE, PEIE and IOCIE bit to enable Interrupt on change
    BANKSEL IOCBN
    BSF	    IOCBN,  7	    ; Set IOCBN 7th bit to enable IoC on PB7 when cleared
    BANKSEL PORTC
    CLRF    PORTC
    MOVLF   0X01, OUTERCOUNT
    MOVLF   0X01, INNERCOUNT
    MOVLF   0X18, TEMP	    ; Put the boundary value (0x18 or 24) to TEMP for boundary reset detection
    RETURN
TASK3_LOOP:
    GOTO    TASK3_LOOP

TASK4:
    BANKSEL OPTION_REG
    MOVLF   0X08, OPTION_REG; Set WPUEN and PSA to enable weak pull-up and clear the prescaler. Clear the TMR0CS to use internal clock
    BANKSEL INTCON
    MOVLF   0XA0, INTCON    ; Set the GIE and TMR0IE to enable global and timer0 interrupt
    BANKSEL PORTC
    CLRF    PORTC
    BCF	    PORTB, 5	    ; Clear the PB5 for task4
    MOVLF   0XA3, OUTERCOUNT
    MOVLF   0XFF, INNERCOUNT
    MOVLF   0x3C, TEMP	    ; Put the boundary value (0x3c or 60) to TEMP for boundary reset detection
    RETURN
TASK4_LOOP:
    GOTO    TASK4_LOOP
    
TASK5:
    BSF	    MODE, 0	    ; At the start of the program, it goes to task4 which is master mode
    CALL    TASK4
TASK5_LOOP:
    BTFSS   PORTB, 6
    GOTO    CHANGE_MODE_SLAVE
    CALL    CHANGE_MODE_MASTER
    GOTO    TASK5_LOOP
    
CHANGE_MODE_SLAVE:
    BTFSS   MODE, 0	    ; Check the last mode
    GOTO    TASK5_LOOP	    ; If it was in slave mode, continue the program
    CALL    TASK3	    ; It is was not in slave mode, switch into slave mode
    BCF	    MODE, 0	    ; Change the mode status bit tp slave mode
    GOTO    TASK5_LOOP	    ; Loop back

CHANGE_MODE_MASTER:
    BTFSC   MODE, 0	    ; Check the last mode
    RETURN		    ; If it was in master mode, continue the program
    CALL    TASK4	    ; If it was not in master mode, switch into master mode
    BSF	    MODE, 0	    ; Change the mode status bit to master mode
    RETURN		    ; Loop back

RESET_PORTC:
    CLRF    PORTC
    MOVLW   0X20
    BTFSC   PORTB, 6	    ; If it is in slave mode, toggle the PB5 everytime reset PORTC
    XORWF   PORTB
    RETURN
    
isr:
    CALL    WAIT_UNTIL_PB7_RELEASE  ; In slave mode, used to wait until PB7 released
    CALL    DELAY		    ; Call a delay for given loops count in OUTERCOUNT and INNERCOUNT register
    BANKSEL PORTC
    INCF    PORTC, F		    ; Increment of PORTC
    MOVF    PORTC, W
    SUBWF   TEMP, W		    ; Check if PORTC hit the boundary value
    BTFSC   STATUS, 2		    ; If hits, the STATUS bit 2 will be set
    CALL    RESET_PORTC		    ; Reset it
    BANKSEL IOCBF
    BCF	    IOCBF, 7		    ; Reset the interrupt flags
    BCF	    INTCON, 2
    RETFIE