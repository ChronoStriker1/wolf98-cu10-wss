bits 32
org 0x7c000

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

%define WSS_IRQ12_DMA1      0x22
%define DMA_BUFFER_BYTES    0x4000
%define DMA_ALLOC_PARAS     0x0800
%define DMA_CHUNK_BYTES     0x3f80
%define SOUND_FINISHED      0x2ca0e

%define SOUND_ID_PORT       0xa460
%define PC98_IO_WAIT        0x005f
%define CANBE_ROUTE_INDEX   0x0f4a
%define CANBE_ROUTE_DATA    0x0f4b
%define OPL_ADDRESS         0x1488
%define OPL_DATA            0x1489
%define OPL_MODE_ADDRESS    0x148a
%define OPL_MODE_DATA       0x148b
%define OPL_CONTROL_ADDRESS 0x148e
%define OPL_CONTROL_DATA    0x148f

; These labels are the stable entry points used by PC-98 Wolfenstein 3D.
; The patcher replaces each old entry with a near jump to the matching label.

driver_detect:
    xor eax, eax
    mov dx, WSS_ID
    in al, dx
    and al, 0x0f
    cmp al, 0x04
    je .found
    cmp al, 0x05
    jne .missing
.found:
    mov eax, 1
    ret
.missing:
    xor eax, eax
    ret

driver_init:
    push ebx
    push esi
    push edi
    push ebp

    cmp byte [installed], 0
    je .fresh
    call driver_shutdown
.fresh:
    call driver_detect
    test eax, eax
    jz .failed

    ; Phar Lap 386|DOS-Extender service: allocate 32 KiB of DOS memory.
    ; A 16 KiB DMA window is selected inside it without crossing 64 KiB.
    mov bx, DMA_ALLOC_PARAS
    mov ax, 0x25c0
    int 0x21
    jc .failed
    movzx ecx, ax
    mov [dos_segment], ecx
    shl eax, 4
    mov edx, eax
    and edx, 0xffff
    cmp edx, 0xc000
    jbe .buffer_ready
    add eax, 0x10000
    and eax, 0xffff0000
.buffer_ready:
    mov [dma_physical], eax

    mov dx, WSS_CONFIG
    in al, dx
    mov [saved_wss_config], al
    ; Match the resource routing proven by the standalone Cu10 tone test.
    ; Codec register 10 keeps interrupt generation disabled, so IRQ12 needs no
    ; protected-mode handler and DMA completion remains timer-polled.
    mov al, WSS_IRQ12_DMA1
    out dx, al

    call wait_codec_ready
    jc .codec_failed
    call save_codec
    call configure_codec
    jc .codec_restore_failed

    mov byte [active], 0
    mov byte [installed], 1
    mov eax, 1
    jmp .done

.codec_restore_failed:
    call restore_codec
.codec_failed:
    mov dx, WSS_CONFIG
    mov al, [saved_wss_config]
    out dx, al
    mov ecx, [dos_segment]
    mov ax, 0x25c1
    int 0x21
    mov dword [dos_segment], 0
.failed:
    xor eax, eax
.done:
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret

driver_shutdown:
    push ebx
    push esi
    push edi
    push ebp
    pushfd
    cli
    cmp byte [installed], 0
    je .done

    call stop_hardware

    call restore_codec
    mov dx, WSS_CONFIG
    mov al, [saved_wss_config]
    out dx, al

    mov ecx, [dos_segment]
    test ecx, ecx
    jz .no_allocation
    mov ax, 0x25c1
    int 0x21
    mov dword [dos_segment], 0
.no_allocation:
    mov byte [installed], 0
.done:
    popfd
    pop ebp
    pop edi
    pop esi
    pop ebx
    ret

driver_play:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    push fs
    pushfd
    cli

    cmp byte [active], 0
    je .new_sound
    call stop_hardware
.new_sound:
    mov eax, [ebp + 8]
    mov [source_offset], eax
    mov ax, [ebp + 12]
    mov [source_selector], ax
    mov eax, [ebp + 16]
    mov [bytes_remaining], eax
    test eax, eax
    jz .done

    call queue_next_block
    mov byte [active], 1
    call start_codec
.done:
    popfd
    pop fs
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

driver_stop:
    pushfd
    cli
    call stop_hardware
    popfd
    ret

driver_set_rate:
    ; Wolfenstein 3D requests roughly 7 kHz. The closest standard WSS rate is
    ; fixed at 8 kHz, so this legacy 86-board selector is unused.
    ret

driver_set_volume:
    push ebp
    mov ebp, esp
    pushfd
    cli
    mov eax, [ebp + 8]
    call volume_to_attenuation
    mov ah, al
    mov al, 6
    call codec_write
    mov al, 7
    call codec_write
    popfd
    pop ebp
    ret

driver_set_pan:
    push ebp
    mov ebp, esp
    pushfd
    cli
    mov eax, [ebp + 8]
    call pan_to_attenuation
    mov ah, al
    mov al, 6
    call codec_write
    mov eax, [ebp + 12]
    call pan_to_attenuation
    mov ah, al
    mov al, 7
    call codec_write
    popfd
    pop ebp
    ret

; EAX is a Wolfenstein 3D volume from 0 through 15. Return CS4231 attenuation.
volume_to_attenuation:
    test eax, eax
    jns .not_negative
    xor eax, eax
.not_negative:
    cmp eax, 15
    jbe .in_range
    mov eax, 15
.in_range:
    neg eax
    add eax, 15
    shl eax, 2
    ret

; The game's pan arguments are attenuation values: 0 is loud and 15 is silent.
; Map each side directly to the CS4231's 0-through-60 dB attenuation range.
pan_to_attenuation:
    test eax, eax
    jns .not_negative
    xor eax, eax
.not_negative:
    cmp eax, 15
    jbe .in_range
    mov eax, 15
.in_range:
    shl eax, 2
    ret

; Copy the next part of the game's unsigned 8-bit mono sample into the DOS
; memory window, update the codec count, and arm PC-98 DMA channel 1.
; Interrupts must be disabled. DS must be the game's data selector.
queue_next_block:
    mov ecx, [bytes_remaining]
    cmp ecx, DMA_CHUNK_BYTES
    jbe .size_ready
    mov ecx, DMA_CHUNK_BYTES
.size_ready:
    mov [block_bytes], ecx
    lfs esi, [source_offset]
    mov edi, [dma_physical]
    push es
    ; Phar Lap selector 34h maps physical memory.  The game's DS selector is
    ; limited to its load image and can fault when the DOS DMA block lies above
    ; that limit.  WOLF98 itself uses 34h when copying to DOS memory.
    push byte 0x34
    pop es
    fs rep movsb
    pop es
    mov [source_offset], esi
    mov eax, [block_bytes]
    sub [bytes_remaining], eax

    ; Playback base count is sample frames minus one, high byte first.
    mov ebx, [block_bytes]
    dec ebx
    mov ah, bh
    mov al, 14
    call codec_write
    mov ah, bl
    mov al, 15
    call codec_write

    ; Mask DMA1 while changing its registers.
    mov dx, DMA_SINGLE_MASK
    mov al, 0x05
    out dx, al
    mov dx, DMA_CLEAR_FF
    xor al, al
    out dx, al

    mov eax, [dma_physical]
    mov dx, DMA_CH1_ADDRESS
    out dx, al
    mov al, ah
    out dx, al
    shr eax, 16
    mov dx, DMA_CH1_BANK
    out dx, al
    mov dx, DMA_CH1_HIGH_BANK
    xor al, al
    out dx, al

    mov dx, DMA_CLEAR_FF
    out dx, al
    mov eax, [block_bytes]
    dec eax
    mov dx, DMA_CH1_COUNT
    out dx, al
    mov al, ah
    out dx, al

    mov dx, DMA_MODE
    mov al, 0x49
    out dx, al
    mov dx, DMA_SINGLE_MASK
    mov al, 0x01
    out dx, al
    ret

start_codec:
    xor al, al
    mov dx, CODEC_STATUS
    out dx, al
    mov al, 9
    call codec_read
    or al, 1
    mov ah, al
    mov al, 9
    call codec_write
    ret

stop_hardware:
    mov dx, DMA_SINGLE_MASK
    mov al, 0x05
    out dx, al
    mov al, 9
    call codec_read
    and al, 0xfe
    mov ah, al
    mov al, 9
    call codec_write
    xor al, al
    mov dx, CODEC_STATUS
    out dx, al
    mov byte [active], 0
    mov dword [bytes_remaining], 0
    ret

; Poll DMA terminal count from Wolfenstein 3D's timer interrupt. This keeps
; playback asynchronous without installing another protected-mode handler.
wss_poll:
    cmp byte [installed], 0
    je .done
    cmp byte [active], 0
    je .done
    mov dx, DMA_STATUS
    in al, dx
    test al, 0x02
    jz .done

    mov dx, DMA_SINGLE_MASK
    mov al, 0x05
    out dx, al
    mov al, 9
    call codec_read
    and al, 0xfe
    mov ah, al
    mov al, 9
    call codec_write
    xor al, al
    mov dx, CODEC_STATUS
    out dx, al

    cmp dword [bytes_remaining], 0
    je .finished
    call queue_next_block
    call start_codec
    ret
.finished:
    mov byte [active], 0
    call SOUND_FINISHED
.done:
    ret

timer_poll_preserve:
    pushfd
    pushad
    push ds
    push es
    push fs
    cld
    mov eax, cs
    add eax, 8
    mov ds, eax
    mov es, eax
    call wss_poll
    pop fs
    pop es
    pop ds
    popad
    popfd
    ret

timer_wrapper_7000:
    call timer_poll_preserve
    jmp 0x2d86d

timer_wrapper_700:
    call timer_poll_preserve
    jmp 0x2d8dd

timer_wrapper_140:
    call timer_poll_preserve
    jmp 0x2daac

wait_codec_ready:
    push ecx
    push edx
    mov ecx, 0x000fffff
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
    pop edx
    pop ecx
    ret

wait_calibration:
    call wait_codec_ready
    jc .done
    push ecx
    push edx
    mov dx, CODEC_INDEX
    mov al, 11
    out dx, al
    inc dx
    mov ecx, 0x000fffff
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
    pop edx
    pop ecx
.done:
    ret

; AL = codec register, return AL = register value.
codec_read:
    push edx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    in al, dx
    pop edx
    ret

; AL = codec register, AH = value.
codec_write:
    push edx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    mov al, ah
    out dx, al
    pop edx
    ret

save_codec:
    mov al, 6
    call codec_read
    mov [saved_reg6], al
    mov al, 7
    call codec_read
    mov [saved_reg7], al
    mov al, 8
    call codec_read
    mov [saved_reg8], al
    mov al, 9
    call codec_read
    mov [saved_reg9], al
    mov al, 10
    call codec_read
    mov [saved_reg10], al
    mov al, 12
    call codec_read
    mov [saved_reg12], al
    ret

configure_codec:
    mov dx, CODEC_INDEX
    mov al, 0x49
    out dx, al
    inc dx
    mov al, 0x04
    out dx, al
    dec dx
    mov al, 0x48
    out dx, al
    inc dx
    ; Unsigned 8-bit mono at 8000 Hz.
    xor al, al
    out dx, al
    dec dx
    out dx, al
    call wait_calibration
    jc .done

    mov al, 10
    call codec_read
    and al, 0xfd
    mov ah, al
    mov al, 10
    call codec_write
    xor ah, ah
    mov al, 6
    call codec_write
    xor ah, ah
    mov al, 7
    call codec_write
    xor al, al
    mov dx, CODEC_STATUS
    out dx, al
    clc
.done:
    ret

restore_codec:
    mov al, 9
    call codec_read
    and al, 0xfe
    mov ah, al
    mov al, 9
    call codec_write

    mov dx, CODEC_INDEX
    mov al, 0x48
    out dx, al
    inc dx
    mov al, [saved_reg8]
    out dx, al
    dec dx
    mov al, 0x49
    out dx, al
    inc dx
    mov al, [saved_reg9]
    and al, 0xfe
    out dx, al
    dec dx
    xor al, al
    out dx, al
    call wait_calibration

    mov ah, [saved_reg6]
    mov al, 6
    call codec_write
    mov ah, [saved_reg7]
    mov al, 7
    call codec_write
    mov ah, [saved_reg10]
    mov al, 10
    call codec_write
    mov ah, [saved_reg12]
    mov al, 12
    call codec_write
    ret

; Wolfenstein 3D produces a complete OPL2 register stream for its IMF music
; and AdLib sound effects. The Cu10 exposes its YMF701 OPL3 bank 0 at
; 1488h/1489h, so reuse the OPL2 register layout instead of translating the
; instruments into the separate OPN-compatible FM mode.

opl_detect_init:
    push ebx
    push ecx
    push edx
    pushfd
    cli

    ; CanBe Sound 2 and PC-9801-118 hardware must switch Sound ID to x3h before
    ; the extended OPL interface responds. Cu10 reports 81h, so this writes 83h.
    mov dx, SOUND_ID_PORT
    in al, dx
    and al, 0xf0
    cmp al, 0x70
    je .sound_family
    cmp al, 0x80
    jne .missing
.sound_family:
    mov bl, al
    mov dx, OPL_CONTROL_ADDRESS
    xor al, al
    out dx, al
    mov dx, OPL_CONTROL_DATA
    in al, dx
    test al, 0x08
    jnz .probe

    mov dx, SOUND_ID_PORT
    mov al, bl
    or al, 0x03
    out dx, al

    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, CANBE_ROUTE_INDEX
    mov al, 0x01
    out dx, al
    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, CANBE_ROUTE_DATA
    mov al, 0x80
    out dx, al

    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, OPL_MODE_ADDRESS
    mov al, 0x05
    out dx, al
    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, OPL_MODE_DATA
    mov al, 0x05
    out dx, al

    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, OPL_MODE_ADDRESS
    mov al, 0x08
    out dx, al
    mov dx, PC98_IO_WAIT
    out dx, al
    mov dx, OPL_MODE_DATA
    mov al, 0x04
    out dx, al

    mov ecx, 2000
    mov dx, PC98_IO_WAIT
.route_delay:
    out dx, al
    loop .route_delay

    mov dx, OPL_MODE_DATA
    xor al, al
    out dx, al
    mov dx, OPL_ADDRESS
    mov al, 0xf7
    out dx, al
    mov dx, OPL_DATA
    out dx, al

.probe:
    ; Standard OPL timer test. A working chip changes status from 00h to C0h.
    mov ax, 0x6004
    call opl_write
    mov ax, 0x8004
    call opl_write
    mov dx, OPL_ADDRESS
    in al, dx
    mov bl, al

    mov ax, 0xff02
    call opl_write
    mov ax, 0x2104
    call opl_write
    mov ecx, 125
    mov dx, OPL_ADDRESS
.timer_delay:
    in al, dx
    loop .timer_delay
    in al, dx
    mov bh, al

    mov ax, 0x6004
    call opl_write
    mov ax, 0x8004
    call opl_write

    and bl, 0xe0
    jnz .missing
    and bh, 0xe0
    cmp bh, 0xc0
    jne .missing

    ; Start in OPL2-compatible mode with all channels silent. The game writes
    ; its original instruments, frequencies, envelopes, and key states.
    mov ebx, 1
.clear_registers:
    mov eax, ebx
    xor ah, ah
    call opl_write
    inc ebx
    cmp ebx, 0xf5
    jbe .clear_registers
    mov ax, 0x2001
    call opl_write

    mov byte [opl_initialized], 1
    mov eax, 1
    jmp .done
.missing:
    mov byte [opl_initialized], 0
    xor eax, eax
.done:
    popfd
    pop edx
    pop ecx
    pop ebx
    ret

; C calling convention: register at [EBP+8], value at [EBP+12].
opl_adlib_write:
    push ebp
    mov ebp, esp
    pushfd
    cli
    cmp byte [opl_initialized], 0
    je .done
    mov al, [ebp + 8]
    mov ah, [ebp + 12]
    ; The CanBe/YMF701 handoff leaves the synth in OPL3 mode. The game supplies
    ; OPL2 C0h-C8h values, whose upper nibble is always zero. On OPL3 that
    ; clears the left/right output enables and can mute whole channels.
    ; Route all nine OPL2 channel slots to both stereo outputs while
    ; preserving its feedback and connection bits.
    cmp al, 0xc0
    jb .write
    cmp al, 0xc8
    ja .write
    or ah, 0x30
.write:
    call opl_write
.done:
    popfd
    pop ebp
    ret

; AL = OPL register, AH = value. The address and data delays match Yamaha's
; OPL timing through PC-98 I/O reads, following the CanBe/118 reference code.
opl_write:
    push ebx
    push ecx
    push edx
    mov bx, ax

    mov dx, OPL_ADDRESS
    mov al, bl
    out dx, al
    mov ecx, 6
.address_delay:
    in al, dx
    loop .address_delay

    mov dx, OPL_DATA
    mov al, bh
    out dx, al
    mov dx, OPL_ADDRESS
    mov ecx, 35
.data_delay:
    in al, dx
    loop .data_delay

    pop edx
    pop ecx
    pop ebx
    ret

align 4, db 0
source_offset:       dd 0
source_selector:     dw 0
bytes_remaining:     dd 0
block_bytes:         dd 0
dma_physical:        dd 0
dos_segment:         dd 0
saved_wss_config:    db 0
saved_reg6:          db 0
saved_reg7:          db 0
saved_reg8:          db 0
saved_reg9:          db 0
saved_reg10:         db 0
saved_reg12:         db 0
installed:           db 0
active:              db 0
opl_initialized:     db 0

driver_end:
