                CODE
                setdp   $0

;
; Minimal SBC09 FUZIX Boot ROM, based on Dominic Beesley's Blitter-sbc09 boot rom
;<

KERNEL_IMG_BLK  equ     $02     ; the starting MMU page for the kernel image (binary format)
KERNEL_RUN_BLK  equ     $80     ; the starting MMU page for the base of the kernel at run-time

REMAPPED_VECTORS equ    $F7F0

UART            equ     $FE00
MMU0            equ     $FE10

UART_MRA        equ     UART + $00
UART_SRA        equ     UART + $01
UART_CSRA       equ     UART + $01
UART_CRA        equ     UART + $02
UART_THRA       equ     UART + $03
UART_ACR        equ     UART + $04
UART_OPRSET     equ     UART + $0e
UART_OPRCLR     equ     UART + $0f

UART_TXRDY      equ     $04

;---------------------------------------------------------------------------------------------------
; MOS ROM
;---------------------------------------------------------------------------------------------------
                ORG     $C000

handle_res      clra
                tfr     a,dp
                lds     #$100

                lda     #%00010011    ; NO PARITY, 8 BITS/CHAR - MR1A,B
                sta     UART_MRA
                lda     #%00010111    ; CTS ENABLE TX, 1.000 STOP BITS - MR2A,B
                sta     UART_MRA
                lda     #%00000101    ; ENABLE TX AND RX
                sta     UART_CRA
                lda     #%10000000    ; Set Channel A Rx Extend Bit
                sta     UART_CRA
                lda     #%10100000    ; Set Channel A Tx Extend Bit
                sta     UART_CRA
                lda     #%10111011    ; Internal 9,600 baud
                sta     UART_CSRA
                lda     #%01110000    ; Timer Mode, Clock = XTAL/16 = 3686400 / 16 = 230400 Hz
                sta     UART_ACR
                lda     #%00000001    ; assert RTS
                sta     UART_OPRSET

                lda     #%10000100     ; 0000-3FFF -> RAM block 4
                sta     MMU0 + 0
                lda     #%00000001     ; C000-FFFF -> ROM0 block 1
                sta     MMU0 + 3

                ;; Enable the MMU with 16K block size
                lda     #%00010000     ; OP4 = low (MMU Enabled, output is inverted)
                sta     UART_OPRSET

                ;; Boot messsage

                ldx     #str_init
                jsr     ser_send_strX

                ;; Copy FUZIX Kernel from ROM to RAM

                ldx     #str_copy
                jsr     ser_send_strX

                lda     #KERNEL_IMG_BLK
                ldb     #KERNEL_RUN_BLK
loop1           sta     MMU0 + 1
                stb     MMU0 + 2
                pshs    a
                ldx     #$4000         ; length
                ldu     #$4000         ; source block (ROM)
                ldy     #$8000         ; destination block (RAM)
loop2           lda    ,u+
                sta    ,y+
                leax   -1,x
                bne    loop2
                puls   a
                inca
                incb
                cmpa   #KERNEL_IMG_BLK+4
                bne loop1

                ;; copy "bounce" code at chipram 100 onwards (we expect 0..200 to be free)

                ldx     #str_boot
                jsr     ser_send_strX


                ; set up task 0 to have SYS at top (this code), ChipRAM at ram 0-BFFF and SYS screen memory C000-BFFF

                lda     #KERNEL_RUN_BLK
                sta     MMU0 + 0
                lda     #KERNEL_RUN_BLK+1
                sta     MMU0 + 1
                lda     #KERNEL_RUN_BLK+2
                sta     MMU0 + 2


                ; we should now be in map 0 with mmu enabled in 16K mode with this ROM (EXT) mapped at top
                ; copy the bounce code to low memory at 100

                ; copy user task to bank 0
                ldu     #ut0_r
                ldy     #$100
                ldx     #ut0_end-ut0+1
1               lda     ,u+
                sta     ,y+
                leax    -1,x
                bne     1B

                ; jump to user task in bank 0
                jmp     $100

ut0_r
                ORG     $100
                PUT     ut0_r
ut0             ; this is the "bounce" task that is copied to

                ; map in top page of RAM in supervisor task
                lda     #KERNEL_RUN_BLK+3
                sta     MMU0 + 3

                ; call the kernel
                jmp     $200
ut0_end
                ORG     ut0_r + ut0_end - ut0
                PUT     ut0_r + ut0_end - ut0


ser_send_strX   pshs    A
1               lda     ,X+
                beq     2F
                bsr     ser_send_A
                bra     1B
2               puls    A,PC


ser_send_A      stb     ,-S
                ldb     #UART_TXRDY
1               bitb    UART_SRA
                beq     1B
                sta     UART_THRA
                puls    B,PC


str_init        FCB     "FUZIX Boot Rom for SBC09",13,10,13,10,0
str_copy        FCB     "Copying Kernel Image from ROM to RAM",13,10,13,10,0
str_boot        FCB     "Starting image at 00 0200",13,10,13,10,0

                ORG     REMAPPED_VECTORS

XRESV           FDB     handle_div0     ; $FFF0   ; Hardware vectors, paged in to $F7Fx from $FFFx
XSWI3V          FDB     handle_swi3     ; $FFF2         ; on 6809 we use this instead of 6502 BRK
XSWI2V          FDB     handle_swi2     ; $FFF4
XFIRQV          FDB     handle_firq     ; $FFF6
XIRQV           FDB     handle_irq      ; $FFF8
XSWIV           FDB     handle_swi      ; $FFFA
XNMIV           FDB     handle_nmi      ; $FFFC
XRESETV         FDB     handle_res      ; $FFFE

handle_div0
                jmp     handle_div0
handle_swi3
                jmp     handle_swi3
handle_swi2
                jmp     handle_swi2
handle_swi
                jmp     handle_swi
handle_firq
                jmp     handle_firq
handle_irq
                jmp     handle_irq
handle_nmi
                jmp     handle_nmi

                ORG     $FFFF
                FCB     0
