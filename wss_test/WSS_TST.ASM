bits 16
org 0x100

%define WSS_CONFIG          0x0f40
%define WSS_ID              0x0f43
%define CODEC_INDEX         0x0f44
%define CODEC_DATA          0x0f45
%define CODEC_STATUS        0x0f46

%define DMA_CH1_ADDRESS     0x0005
%define DMA_CH1_COUNT       0x0007
%define DMA_STATUS          0x0011
%define DMA_SINGLE_MASK     0x0015
%define DMA_MODE            0x0017
%define DMA_CLEAR_FF        0x0019
%define DMA_CH1_BANK        0x0021
%define DMA_CH1_HIGH_BANK   0x0e07

%define BUFFER_SIZE         4096
%define WSS_IRQ12_DMA1      0x22

start:
    push cs
    pop ds
    push cs
    pop es

    mov dx, msg_title
    call print_dos

    mov dx, WSS_ID
    in al, dx
    mov [wss_id], al
    and al, 0x0f
    cmp al, 0x04
    je .id_ok
    cmp al, 0x05
    je .id_ok
    mov dx, msg_no_wss
    call print_dos
    mov ax, 0x4c01
    int 0x21

.id_ok:
    call select_safe_buffer
    jc fatal_buffer
    call make_tone

    mov dx, WSS_CONFIG
    in al, dx
    mov [saved_config], al
    mov al, WSS_IRQ12_DMA1
    out dx, al

    call wait_codec_ready
    jc fatal_codec
    call save_codec
    call configure_codec
    jc restore_codec_error
    call program_dma

    xor al, al
    mov dx, CODEC_STATUS
    out dx, al

    mov al, 9
    call codec_read
    or al, 1
    mov ah, al
    mov al, 9
    call codec_write

    mov dx, msg_playing
    call print_dos
    call wait_dma
    pushf
    call stop_and_restore
    popf
    jc fatal_timeout

    mov dx, msg_success
    call print_dos
    mov ax, 0x4c00
    int 0x21

restore_codec_error:
    call stop_and_restore
fatal_codec:
    mov dx, WSS_CONFIG
    mov al, [saved_config]
    out dx, al
    mov dx, msg_codec_error
    call print_dos
    mov ax, 0x4c02
    int 0x21

fatal_buffer:
    mov dx, msg_buffer_error
    call print_dos
    mov ax, 0x4c03
    int 0x21

fatal_timeout:
    mov dx, msg_timeout
    call print_dos
    mov ax, 0x4c04
    int 0x21

print_dos:
    mov ah, 9
    int 0x21
    ret

; Pick a buffer that is above the program and does not cross a 64 KiB
; physical DMA boundary. DOS normally gives a COM program a full segment.
select_safe_buffer:
    mov di, 0x2000
.try:
    mov ax, di
    add ax, BUFFER_SIZE + 15
    mov cl, 4
    shr ax, cl
    mov dx, ds
    add ax, dx
    cmp ax, [2]
    ja .next
    mov ax, ds
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, di
    mov bx, ax
    add bx, BUFFER_SIZE - 1
    jc .next
    mov [tone_offset], di
    clc
    ret
.next:
    add di, 0x2000
    cmp di, 0xc000
    jbe .try
    stc
    ret

make_tone:
    mov di, [tone_offset]
    mov cx, BUFFER_SIZE / 32
.repeat:
    mov si, sine_table
    push cx
    mov cx, 32
    rep movsb
    pop cx
    loop .repeat
    ret

wait_codec_ready:
    push cx
    push dx
    mov cx, 0xffff
    mov dx, CODEC_INDEX
.loop:
    in al, dx
    test al, 0x80
    jz .ready
    loop .loop
    stc
    jmp .done
.ready:
    clc
.done:
    pop dx
    pop cx
    ret

wait_calibration:
    call wait_codec_ready
    jc .done
    push cx
    push dx
    mov dx, CODEC_INDEX
    mov al, 11
    out dx, al
    inc dx
    mov cx, 0xffff
.loop:
    in al, dx
    test al, 0x20
    jz .ready
    loop .loop
    stc
    jmp .restore
.ready:
    clc
.restore:
    pop dx
    pop cx
.done:
    ret

; AL = codec register, returns AL = value.
codec_read:
    push dx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    in al, dx
    pop dx
    ret

; AL = codec register, AH = value.
codec_write:
    push dx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    mov al, ah
    out dx, al
    pop dx
    ret

save_codec:
    mov si, saved_register_numbers
    mov di, saved_register_values
    mov cx, saved_register_count
.next:
    lodsb
    call codec_read
    stosb
    loop .next
    ret

restore_codec:
    ; Stop playback first.
    mov al, 9
    call codec_read
    and al, 0xfe
    mov ah, al
    mov al, 9
    call codec_write

    ; Restore registers 8 and 9 while Mode Change Enable is asserted.
    mov si, saved_register_values
    add si, 2
    mov dx, CODEC_INDEX
    mov al, 0x48
    out dx, al
    inc dx
    mov al, [si]
    out dx, al
    dec dx
    mov al, 0x49
    out dx, al
    inc dx
    mov al, [si + 1]
    and al, 0xfe
    out dx, al
    dec dx
    xor al, al
    out dx, al
    call wait_calibration

    ; Restore the remaining saved registers.
    mov si, saved_register_values
    mov ah, [si]
    mov al, 6
    call codec_write
    mov ah, [si + 1]
    mov al, 7
    call codec_write
    mov ah, [si + 4]
    mov al, 10
    call codec_write
    mov ah, [si + 5]
    mov al, 12
    call codec_write
    mov ah, [si + 6]
    mov al, 14
    call codec_write
    mov ah, [si + 7]
    mov al, 15
    call codec_write
    ret

configure_codec:
    ; MCE + register 9: single DMA channel, playback stopped.
    mov dx, CODEC_INDEX
    mov al, 0x49
    out dx, al
    inc dx
    mov al, 0x04
    out dx, al

    ; MCE + register 8: unsigned 8-bit mono at 11025 Hz.
    dec dx
    mov al, 0x48
    out dx, al
    inc dx
    mov al, 0x03
    out dx, al

    ; Clear MCE and wait for codec calibration.
    dec dx
    xor al, al
    out dx, al
    call wait_calibration
    jc .done

    ; Disable codec interrupts. The test polls the DMA terminal count.
    mov al, 10
    call codec_read
    and al, 0xfd
    mov ah, al
    mov al, 10
    call codec_write

    ; Playback base count is in sample frames minus one, high byte first.
    mov ah, (BUFFER_SIZE - 1) >> 8
    mov al, 14
    call codec_write
    mov ah, (BUFFER_SIZE - 1) & 0xff
    mov al, 15
    call codec_write

    ; Unmute both DAC outputs at full codec volume.
    xor ah, ah
    mov al, 6
    call codec_write
    xor ah, ah
    mov al, 7
    call codec_write
    clc
.done:
    ret

program_dma:
    ; Mask DMA channel 1 while its registers are changed.
    mov dx, DMA_SINGLE_MASK
    mov al, 0x05
    out dx, al

    ; Reset the byte flip-flop, then write the 16-bit address.
    mov dx, DMA_CLEAR_FF
    xor al, al
    out dx, al

    mov ax, ds
    mov bx, ax
    mov cl, 12
    shr bx, cl
    mov ax, ds
    shl ax, 1
    shl ax, 1
    shl ax, 1
    shl ax, 1
    add ax, [tone_offset]
    adc bl, 0

    mov dx, DMA_CH1_ADDRESS
    out dx, al
    mov al, ah
    out dx, al

    ; Bits 16-19 come from the segment plus the carry from the low word.
    mov al, bl
    mov dx, DMA_CH1_BANK
    out dx, al
    mov dx, DMA_CH1_HIGH_BANK
    xor al, al
    out dx, al

    mov dx, DMA_CLEAR_FF
    out dx, al
    mov ax, BUFFER_SIZE - 1
    mov dx, DMA_CH1_COUNT
    out dx, al
    mov al, ah
    out dx, al

    ; Single-cycle, address increment, memory-to-device, channel 1.
    mov dx, DMA_MODE
    mov al, 0x49
    out dx, al

    ; Unmask channel 1.
    mov dx, DMA_SINGLE_MASK
    mov al, 0x01
    out dx, al
    ret

wait_dma:
    push cx
    push dx
    mov bx, 200
    mov dx, DMA_STATUS
.outer:
    mov cx, 0xffff
.inner:
    in al, dx
    test al, 0x02
    jnz .complete
    loop .inner
    dec bx
    jnz .outer
    stc
    jmp .done
.complete:
    clc
.done:
    pop dx
    pop cx
    ret

stop_and_restore:
    pushf
    mov dx, DMA_SINGLE_MASK
    mov al, 0x05
    out dx, al
    call restore_codec
    mov dx, WSS_CONFIG
    mov al, [saved_config]
    out dx, al
    popf
    ret

msg_title db 13,10,'Cu10 WSS DMA sound test',13,10,'$'
msg_playing db 'Playing a short tone...',13,10,'$'
msg_success db 'Test complete. Did you hear a clean tone?',13,10,'$'
msg_no_wss db 'ERROR: WSS codec ID 04h/05h was not found at F43h.',13,10,'$'
msg_codec_error db 'ERROR: The codec did not become ready.',13,10,'$'
msg_buffer_error db 'ERROR: No DMA-safe buffer location was available.',13,10,'$'
msg_timeout db 'ERROR: DMA channel 1 did not complete.',13,10,'$'

saved_register_numbers db 6, 7, 8, 9, 10, 12, 14, 15
saved_register_count equ $ - saved_register_numbers
saved_register_values times saved_register_count db 0
saved_config db 0
wss_id db 0
tone_offset dw 0

; One cycle of an unsigned 8-bit sine wave, repeated at about 345 Hz.
sine_table db 128,153,176,198,218,234,246,253
           db 255,253,246,234,218,198,176,153
           db 128,103,80,58,38,22,10,3
           db 1,3,10,22,38,58,80,103
