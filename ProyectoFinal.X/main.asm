; Organizaci?n de Computadoras 2019
; Proyecto Final
; PIC16F887 Configuration Bit Settings
; Assembly source line config statements

#include "p16f887.inc"

; CONFIG1
; __config 0xE0F2
 __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0xFEFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF

    cblock 0x20    
	pot_h
	d1
	d11
	d2
	d22
	W_TEMP	
	STATUS_TEMP
	contador
	buffer_inicio
	buffer_fin
	buffer_cabeza
	buffer_tmp
	buffer_cola_tmp
	buffer_cola	
	valor_serial
	valor_eeprom
	rcreg_tmp
    endc
    
    org 0x0000
	goto main
    org 0x0004
	goto interrupt
	
conversor
    addwf PCL
    retlw 0x30
    retlw 0x31
    retlw 0x32
    retlw 0x33
    retlw 0x34
    retlw 0x35
    retlw 0x36
    retlw 0x37
    retlw 0x38
    retlw 0x39
    retlw 0x41
    retlw 0x42
    retlw 0x43
    retlw 0x44
    retlw 0x45
    retlw 0x46
    
eusart_init
    banksel TXSTA
    bsf TXSTA, TXEN  ; enable transmitter
    bcf TXSTA, SYNC  ; asynchronous
    banksel RCSTA
    bsf RCSTA, CREN  ; enable receiver
    bsf RCSTA, SPEN  ; enable EUSART, TX/CK/IO as output
    return
    
; baud rate setting is is in w
; check TABLE 12-5: BAUD RATES FOR ASYNCHRONOUS MODES
eusart_baud_rate
    banksel TXSTA
    bsf TXSTA, BRGH      ; BRGH=1
    banksel BAUDCTL
    bcf BAUDCTL, BRG16   ; BRG16=0
    banksel SPBRGH
    clrf SPBRGH
    banksel SPBRG        
    movwf SPBRG
    return
  
buffer_config
    banksel buffer_inicio   ;Grabo el valor de memoria donde inicia el buffer
    movlw 0x00
    movwf buffer_inicio
    movlw 0x00
    movwf buffer_tmp
    movlw 0x09
    movwf buffer_fin
    return
    
adc_config
    banksel TRISA ;
    movlw b'11000011'	; potenciometro entrada
    movwf TRISA

    banksel ADCON1	;Selecciono el banco de memoria de ADCON1
    movlw b'00000000'	;Justificado IZQ(b7=0), Voltajes Vdd(b4=0),Vss(b5=0)
    movwf ADCON1
    
    banksel ADCON0	;Selecciono el banco de memoria de ADCON0
    movlw b'10000001'	;Tad 1,6 (b7b6=10), AN0(b5b4b3b2=0000), ON(b0=1)  
    movwf ADCON0
    call Delay		;Delay para que cargue el capacitor de hold
    return
    
main
    ;call resetear      ;Descomentar esta linea para resetear y luego comentarla
    
    bsf INTCON,7        ;Habilito las interupciones globales
    bsf INTCON,6        ;Habilito las interupciones de perifericos
    
    banksel PIE1
    bsf PIE1,0          ;Habilito las interupciones del timer 1
    bcf PIE1,ADIE	;Deshabilito las interrupciones del conversor AD
    bcf PIE1,TXIE	;Deshabilito las interrupciones del puerto serial
    
    banksel T1CON
    bsf T1CON,0         ;Habilito el timer 1
    bcf T1CON,1         ;Tomar el clock interno
    bsf T1CON,4         ;Prescaler de 1 a 8
    bsf T1CON,5
    
    banksel TRISD
    clrf TRISD
	
    banksel PORTD
    clrf PORTD
    
    ;Ejecuto las configuraciones del puerto serial
    movlw d'129'
    call eusart_baud_rate
    call eusart_init
    
    ;Seteo los valores del timer el ADC y los valores del buffer
    call SetearTMR1            
    call adc_config
    call buffer_config   
    
    ;Cargo el valor inicial del contador para lograr los 10 segundos en la interrupcion
    movlw d'100'
    movwf contador
    
    ;Se cargan los valores de los punteros de buffer circular o sus valores por defecto
    call inicializacion
    
    ;Activo el timer
    call ActivarTimer 
    
_main_loop
    call eusart_get	;El bucle espera a recibir algun caracter desde la pc  
    goto _main_loop

;Funcion auxiliar que se llama descomentadola en el main para eliminar el valor
;en la eeprom que indica que el dispositivo ya fue utilizado
resetear
    movlw 0x00
    banksel valor_eeprom
    movwf valor_eeprom
    movlw 0x52
    banksel buffer_tmp
    movwf buffer_tmp    
    call escribirEEPROM
    return

;Esta funcion se encarga de setear los punteros de cabeza y cola del buffer circular
;en el caso que el dispositivo ya fue usado carga los valores correspondientes
;de lo contrario pone los valores por defecto
inicializacion
    movlw 0x52
    call leerEEPROM_w
    movwf buffer_tmp
    movlw d'100'
    subwf buffer_tmp, w
    btfsc STATUS,2
    goto cargar_punteros
    
inicializar_punteros
    banksel buffer_cabeza
    movlw 0x00
    movwf buffer_cabeza
    movlw 0x00
    movwf buffer_cola
    movlw d'100'
    movwf valor_eeprom
    movlw 0x52
    movwf buffer_tmp    
    call escribirEEPROM
    return
    
cargar_punteros
    movlw 0x50
    call leerEEPROM_w
    movfw buffer_cabeza
    
    movlw 0x51
    call leerEEPROM_w
    movfw buffer_cola
    return

    
;Funcion para leer desde la EEPROM recibe por w la direccion y retorna en w el valor leido
leerEEPROM_w
    banksel EEADR ;    
    movwf EEADR ;Data Memory
    ;Address to read
    banksel EECON1 ;
    BCF EECON1, EEPGD ;Point to DATA memory
    BSF EECON1, RD ;EE Read
    banksel EEDAT ;
    MOVF EEDAT, W ;W = EEDAT    
    return

;Funcion para escribir en la EEPROM las variables buffer_tmp indican la direccion de memoria
;y la variable valor_eeprom el valor a guardar
escribirEEPROM
    banksel buffer_tmp   ;Cambio al banco de memoria de EEADR
    movfw buffer_tmp	    ;Copio el valor en w    
    banksel EEADR	    ;Cambio al banco de memoria de EEADR    
    movwf EEADR		    ;Seteo la direccion en la que se guardan los datos
    
    banksel valor_eeprom
    movfw valor_eeprom		;Seteo el valor a guardar     
    banksel EEDAT
    movwf EEDAT		;Data Memory Value to write
    
    banksel EECON1	;
    bcf EECON1, EEPGD	;
    bsf EECON1, WREN	;Habilito la escritura
    bcf INTCON, GIE	;Disable INTs.
    btfsc INTCON, GIE	;SEE AN576
    goto $-2
    MOVLW 0x55 ;
    MOVWF EECON2 ;Write 55h
    MOVLW 0xAA ;
    MOVWF EECON2 ;Write AAh
    BSF EECON1, WR ;Set WR bit to begin write
    banksel PIR2
    btfss PIR2,EEIF	;En bucle hasta que termine de escribir
    goto $-1
    
    bcf PIR2,EEIF
    BCF EECON1, WREN ;Disable writes
    return

;Esta funcion actualiza los punteros cabeza y cola del buffer circular
actualizarPunteros
    movfw buffer_fin
    subwf buffer_cabeza, w
    btfsc STATUS,2
    goto _reiniciarCabezaBuffer
    incf buffer_cabeza    
    goto _actualizarColaBuffer
    
;Si el valor excede el tope vuelve al valor inicial
_reiniciarCabezaBuffer
    movf buffer_inicio,w
    movwf buffer_cabeza

;Si la cabeza y la cola son iguales suma 1 en la cola
_actualizarColaBuffer
    movf buffer_cabeza,w
    subwf buffer_cola, w	
    btfss STATUS,2
    return
    movfw buffer_fin
    subwf buffer_cola, w	
    btfsc STATUS,2
    goto _reiniciarColaBuffer    
    incf buffer_cola
    return  
;Si la cola del buffer llega al tope la setea al inicio
_reiniciarColaBuffer    
    movfw buffer_inicio    
    movwf buffer_cola
    return
    
;Obtener el valor actual del conversor AD
adc_valor_actual
    bsf ADCON0,GO	;Iniciar la conversion
    btfsc ADCON0,GO	;En bucle hasta que termine la conversion
    goto $-1
    banksel ADRESH	;Selecciono el banco de memoria de ADRESH
    movf ADRESH,w	;lo guardo en pot_h
    banksel pot_h
    movwf pot_h    
    return

;Chequea si se recibio algun valor por el puerto serial
eusart_get
    banksel PIR1
    btfss PIR1,5
    return
    banksel RCREG
    movfw RCREG
    movwf rcreg_tmp
    
    sublw d'65'
    btfsc STATUS,2   
    goto comandoA
    
    movfw rcreg_tmp
    sublw d'72'
    btfsc STATUS,2
    goto comandoH
    
    return
    
;Si la letra recibida por el puerto serial es A reporta el valor actual
comandoA
    call enviar_salto_linea_serial
    call adc_valor_actual
    call enviar_valor_serial_w
    call enviar_salto_linea_serial    
    return
    
;Si la letra recibida por el puerto serial es H imprime todos los valores
comandoH
    movfw buffer_cola
    subwf buffer_cabeza, w
    btfsc STATUS,2    
    return
    
    call enviar_salto_linea_serial
    movf buffer_cabeza,w
    movwf buffer_tmp
    

_enviavalor    
    movfw buffer_inicio
    subwf buffer_tmp, w
    btfsc STATUS,2
    goto _davuelta
    decf buffer_tmp
    goto _enviar
    
_davuelta
    movf buffer_fin,w
    movwf buffer_tmp
    
_enviar
    movf buffer_tmp,w
    call leerEEPROM_w
    call enviar_valor_serial_w
    call enviar_salto_linea_serial
    movfw buffer_cola
    subwf buffer_tmp, w
    btfss STATUS,2    
    goto _enviavalor 
    
    incf buffer_cabeza,w
    subwf buffer_cola, w
    btfss STATUS,2
    return
    movfw buffer_cabeza
    call leerEEPROM_w
    call enviar_valor_serial_w
    call enviar_salto_linea_serial
    return

;Funcion para enviar un caracter de salto de linea
enviar_salto_linea_serial
    movlw 0xA		    ;codigo ASCII Salto linea
    call eusart_send_w	    ;Envio el codigo
    return

;Funcion que envia la informacion por el puerto serial
eusart_send_w
    banksel PIR1
    btfss PIR1,4
    goto $-1
    banksel TXREG
    movwf TXREG 
    return

;Procesa el valor w para que este en formato hexadecimal y lo envia por el puerto serial
enviar_valor_serial_w
    banksel valor_serial
    movwf valor_serial
    call formatear_numero
    
    banksel d2
    movfw d2
    call conversor
    call eusart_send_w
    
    banksel d1
    movfw d1
    call conversor
    call eusart_send_w
    return

;Divide el byte en 2 y lo guarda en las variables d1 y d2
formatear_numero
    movlw b'00001111'
    banksel valor_serial
    andwf valor_serial, w    
    movwf d1    
    movlw b'11110000'    
    andwf valor_serial, w    
    movwf d2
    swapf d2,f
    return        

;Funcion para desactivar el timer 1
DesactivarTimer
    banksel T1CON
    bcf T1CON,0         ;Deshabilito el timer 1
    return

;Funcion para activar el timer 1
ActivarTimer
    banksel T1CON
    bsf T1CON,0         ;Habilito el timer 1
    return

;Setear los valores del timer para lograr 0.1 seg
SetearTMR1
    banksel TMR1H    
    movlw b'00001011'
    movwf TMR1H
    banksel TMR1L
    movlw b'11011100'
    movwf TMR1L
    banksel PIR1
    bcf PIR1,0
    return

;Funcion encargada de leer del ADC y guargar en el buffercircular, luego de guardar
;actualiza las posiciones de los punteros cabeza y cola y los guarda en la eeprom
guardarLectura    
    bsf ADCON0,GO	;Iniciar la conversion
    btfsc ADCON0,GO	;En bucle hasta que termine la conversion
    goto $-1
    banksel ADRESH	;Selecciono el banco de memoria de ADRESH
    
    movf ADRESH,w	;lo guardo en pot_h    
    movwf valor_eeprom
    movf buffer_cabeza,w
    movwf buffer_tmp    
    call escribirEEPROM
    call actualizarPunteros
    
    movf buffer_cabeza,w
    movwf valor_eeprom
    movlw 0x50
    movwf buffer_tmp    
    call escribirEEPROM
    
    movf buffer_cola,w
    movwf valor_eeprom
    movlw 0x51
    movwf buffer_tmp    
    call escribirEEPROM
    movlw d'100'
    movwf contador
    return

;Funcion principal de interrupcion para el timer1
interrupt    
    bcf INTCON,7
    movwf W_TEMP
    movf STATUS,w
    movwf STATUS_TEMP
    
    decf contador     ;cuento 100 ocurrencias de la interrupcion
    btfsc STATUS,2
    call guardarLectura    
    call SetearTMR1    
    
    movf STATUS_TEMP,w
    movwf STATUS
    movf W_TEMP,w

    retfie
    
Delay ;49993 cycles
    movlw 0x0E ;14 en w
    movwf d11   ;w a d1
    ;movlw 0x28 ;40 en w
    movlw 0x78 ;40 en w
    movwf d22   ;w a d2
Delay_0
    decfsz d11, f ;13..0 ,255..0
    goto $+2
    decfsz d22, f ;39,38..0
    goto Delay_0

    goto $+1 ;3 cycles
    nop

    return ;4 cycles  
    
end