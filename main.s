;****************** main.s ***************
; Program written by: Valvano, solution
; Date Created: 2/4/2017
; Last Modified: 1/17/2021
; Brief description of the program
;   The LED toggles at 2 Hz and a varying duty-cycle
; Hardware connections (External: One button and one LED)
;  PE1 is Button input  (1 means pressed, 0 means not pressed)
;  PE2 is LED output (1 activates external LED on protoboard)
;  PF4 is builtin button SW1 on Launchpad (Internal) 
;        Negative Logic (0 means pressed, 1 means not pressed)
; Overall functionality of this system is to operate like this
;   1) Make PE2 an output and make PE1 and PF4 inputs.
;   2) The system starts with the the LED toggling at 2Hz,
;      which is 2 times per second with a duty-cycle of 30%.
;      Therefore, the LED is ON for 150ms and off for 350 ms.
;   3) When the button (PE1) is pressed-and-released increase
;      the duty cycle by 20% (modulo 100%). Therefore for each
;      press-and-release the duty cycle changes from 30% to 70% to 70%
;      to 90% to 10% to 30% so on
;   4) Implement a "breathing LED" when SW1 (PF4) on the Launchpad is pressed:
;      a) Be creative and play around with what "breathing" means.
;         An example of "breathing" is most computers power LED in sleep mode
;         (e.g., https://www.youtube.com/watch?v=ZT6siXyIjvQ).
;      b) When (PF4) is released while in breathing mode, resume blinking at 2Hz.
;         The duty cycle can either match the most recent duty-
;         cycle or reset to 30%.
;      TIP: debugging the breathing LED algorithm using the real board.
; PortE device registers
GPIO_PORTE_DATA_R  EQU 0x400243FC
GPIO_PORTE_DIR_R   EQU 0x40024400
GPIO_PORTE_AFSEL_R EQU 0x40024420
GPIO_PORTE_DEN_R   EQU 0x4002451C
; PortF device registers
GPIO_PORTF_DATA_R  EQU 0x400253FC
GPIO_PORTF_DIR_R   EQU 0x40025400
GPIO_PORTF_AFSEL_R EQU 0x40025420
GPIO_PORTF_PUR_R   EQU 0x40025510
GPIO_PORTF_DEN_R   EQU 0x4002551C
GPIO_PORTF_LOCK_R  EQU 0x40025520
GPIO_PORTF_CR_R    EQU 0x40025524
GPIO_LOCK_KEY      EQU 0x4C4F434B  ; Unlocks the GPIO_CR register
SYSCTL_RCGCGPIO_R  EQU 0x400FE608

       IMPORT  TExaS_Init
       THUMB
       AREA    DATA, ALIGN=2
;global variables go here
dOn    SPACE 4
dOff   SPACE 4


       AREA    |.text|, CODE, READONLY, ALIGN=2
       THUMB

       EXPORT  Start

Start
 ; TExaS_Init sets bus clock at 80 MHz
     BL  TExaS_Init
; voltmeter, scope on PD3
 ; Initialization goes here

       LDR R0,=SYSCTL_RCGCGPIO_R
       LDRB R1, [R0]
       ORR R1, #0x10
       STRB R1, [R0] ; turn on clock for Port E
       NOP
       NOP ; wait for clock to stabalize

       LDR R0,=GPIO_PORTE_DIR_R
	   LDRB R1, [R0]
	   AND R1, #0xFD ; set PE1 as input 
	ORR R1, #0x04
	STR R1, [R0] ; PE1 is input, PE2 is output
	
	LDR R0,=GPIO_PORTE_DEN_R
	LDRB R1, [R0]
	ORR R1, #0x06	; set bits being used (PE1, PE2)
	STR R1, [R0]    
	

     CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
      
loop 
; main engine goes here
     LDR R0,=GPIO_PORTE_DATA_R
	 LDR R2, =dOn
	 LDR R1, [R2]
	 MOV R1, #300	; duty ON = 30% 
	 STR R1, [R2]
	 LDR R2, =dOff
	 LDR R1, [R2]
	 MOV R1, #700 ; delay OFF = 70%
	 STR R1, [R2] 
normal	 
     LDR R2, [R0]
	 AND R5, R2, #0x02 ; store initial PE1 bit
	 ORR R2, #0x04 ; set PE2 high
	 STR R2, [R0]
	 LDR R1, =dOn
	 LDR R1, [R1]
continue	 BL delay
	 SUB R1, R1, #1
	 CMP R1, #0 
	 BNE continue
	 AND R2, #0xFB ; set PE2 low 
	 STR R2, [R0]
	 LDR R1, =dOff
	 LDR R1, [R1]
again	 BL delay
	 SUB R1, R1, #1
	 CMP R1, #0
	 BNE again
	 
	 LDR R2, [R0]
	 AND R6, R2, #0x02  ; isolate PE1 bit 
	 CMP R5, R6	; see if PE1 was pressed, then unpressed
	 BLS normal
	 LDR R2, =dOn
	 LDR R1, [R2]
	 CMP R1, #900 ; check if duty ON == 90%
	 BEQ at90  
	 ADD R1, R1, #200 ; change duty ON += 20%
	 STR R1, [R2]
	 LDR R2, =dOff
	 LDR R1, [R2]
	 SUB R1, R1, #200 ; change duty OFF -= 20% 
	 STR R1, [R2]
next
	 B    loop
     
delay 
	  MOV R7, #9000	; delay = 0.5 ms 
go	  SUBS R7, R7, #0x01 
      BNE go   
	  BX LR
	  
at90  LDR R2, =dOn
	  LDR R1, [R2]
	  MOV R1, #100
      STR R1, [R2]
	  BL delay
	  LDR R2, =dOff
	  LDR R1, [R2]
	  MOV R1, #900
	  STR R1, [R2]
	  BL delay
	  B next   ; change to duty ON = 10%, duty OFF = 90%
	  
      
     ALIGN      ; make sure the end of this section is aligned
     END        ; end of file