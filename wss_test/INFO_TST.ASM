bits 16
org 0x100

%define SOUND_ID_PORT       0xa460
%define WSS_CONFIG          0x0f40
%define WSS_ID              0x0f43
%define CODEC_INDEX         0x0f44
%define CANBE_MIXER_INDEX   0x0f4a
%define CANBE_MIXER_DATA    0x0f4b
%define PNP_CONTROL         0x0c24
%define PNP_ADDRESS_LOW     0x0c2b
%define PNP_ADDRESS_HIGH    0x0c2d
%define PC98_IO_WAIT        0x005f
%define YMF_BOARD_INDEX     0x548e
%define YMF_BOARD_DATA      0x548f
%define OPL_STATUS          0x1488
%define INDIRECT_SELECTOR   0xac6c
%define INDIRECT_DATA       0xac6e

start:
    push cs
    pop ds

    mov dx, msg_title
    call print_dos

    mov dx, report_name
    xor cx, cx
    mov ah, 0x3c
    int 0x21
    jc create_failed
    mov [report_handle], ax

    mov dx, report_title
    call file_string
    call write_snapshot
    call write_pnp_map
    call write_board_dump
    call write_candidate_ports
    call write_indirect_controller

    mov bx, [report_handle]
    mov ah, 0x3e
    int 0x21
    jc write_failed
    cmp byte [write_error], 0
    jne write_failed

    mov dx, msg_saved
    call print_dos
    mov ax, 0x4c00
    int 0x21

create_failed:
    mov dx, msg_create_failed
    call print_dos
    mov ax, 0x4c01
    int 0x21

write_failed:
    mov dx, msg_write_failed
    call print_dos
    mov ax, 0x4c01
    int 0x21

write_snapshot:
    mov dx, label_snapshot
    call file_string

    mov dx, SOUND_ID_PORT
    in al, dx
    call file_hex8
    mov dx, separator_slash
    call file_string

    mov dx, WSS_CONFIG
    in al, dx
    call file_hex8
    mov dx, separator_slash
    call file_string

    mov dx, WSS_ID
    in al, dx
    call file_hex8
    call file_crlf

    mov dx, label_codec_aux1
    call file_string
    mov al, 2
    call codec_read
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, 3
    call codec_read
    call file_hex8
    call file_crlf

    mov dx, label_codec_aux2
    call file_string
    mov al, 4
    call codec_read
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, 5
    call codec_read
    call file_hex8
    call file_crlf

    mov dx, label_mixer
    call file_string
    mov al, 0x30
    call mixer_read
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, 0x31
    call mixer_read
    call file_hex8
    call file_crlf

    mov dx, label_opl_status
    call file_string
    mov dx, OPL_STATUS
    in al, dx
    call file_hex8
    call file_crlf
    ret

write_pnp_map:
    mov dx, label_pnp_status
    call file_string
    mov dx, PNP_CONTROL
    in al, dx
    mov [saved_pnp_control], al
    call file_hex8
    call file_crlf

    mov al, [saved_pnp_control]
    and al, 0xe0
    and al, 0xdf
    mov [pnp_read_mode], al

    xor bx, bx
.next:
    mov dx, PNP_CONTROL
    mov al, [pnp_read_mode]
    or al, bl
    out dx, al

    mov dx, PNP_ADDRESS_LOW
    in al, dx
    mov [pnp_address], al
    mov dx, PNP_ADDRESS_HIGH
    in al, dx
    mov [pnp_address + 1], al

    mov dx, label_pnp_entry
    call file_string
    mov al, bl
    call file_hex8
    mov dx, separator_equals
    call file_string
    mov ax, [pnp_address]
    call file_hex16
    call file_crlf

    inc bl
    cmp bl, 16
    jb .next

    mov dx, PNP_CONTROL
    mov al, [saved_pnp_control]
    out dx, al
    ret

write_board_dump:
    mov dx, label_board_dump
    call file_string
    xor bx, bx
.next_line:
    mov dx, label_board_line
    call file_string
    mov al, bl
    call file_hex8
    mov dx, separator_colon
    call file_string
    mov cx, 16
.next_register:
    mov dx, YMF_BOARD_INDEX
    mov al, bl
    out dx, al
    call io_wait
    mov dx, YMF_BOARD_DATA
    in al, dx
    call file_hex8
    mov dx, separator_space
    call file_string
    inc bl
    loop .next_register
    call file_crlf
    cmp bl, 0x40
    jb .next_line
    ret

write_candidate_ports:
    mov dx, label_f86
    call file_string
    mov dx, 0x0f86
    call write_yamaha_candidate
    call file_crlf

    mov dx, label_480
    call file_string
    mov dx, 0x0480
    call write_yamaha_candidate
    call file_crlf

    mov dx, label_direct_ports
    call file_string
    mov dx, YMF_BOARD_DATA
    in al, dx
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov dx, 0x0f87
    in al, dx
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov dx, 0x0481
    in al, dx
    call file_hex8
    call file_crlf
    ret

write_indirect_controller:
    mov dx, label_indirect
    call file_string
    mov cl, 1
.next:
    mov al, cl
    call indirect_controller_read
    call file_hex8
    cmp cl, 4
    je .registers_done
    mov dx, separator_slash
    call file_string
    inc cl
    jmp .next
.registers_done:
    mov dx, label_indirect_locked
    call file_string
    mov dx, INDIRECT_DATA
    in al, dx
    call file_hex8
    call file_crlf
    ret

; AL = OPL3-SA register, returns AL = value. NEC's Windows driver uses this
; indirect PC-98 sequence on machines where direct F86h access is not decoded.
; It selects and reads a register but never writes register data.
indirect_controller_read:
    push bx
    push dx
    mov bl, al

    mov dx, INDIRECT_SELECTOR
    mov ax, 0x5440
    out dx, ax
    mov dx, INDIRECT_DATA
    mov al, 0x1d
    out dx, al

    mov dx, INDIRECT_SELECTOR
    mov ax, 0x5440
    out dx, ax
    mov dx, INDIRECT_DATA
    mov al, bl
    out dx, al

    mov dx, INDIRECT_SELECTOR
    mov ax, 0x5441
    out dx, ax
    mov dx, INDIRECT_DATA
    in al, dx

    pop dx
    pop bx
    ret

; DX = Yamaha candidate index port. Read registers 1 through 4 using the
; documented OPL3-SA password sequence. This routine never writes data.
write_yamaha_candidate:
    push bx
    push cx
    mov bx, dx
    mov cl, 1
.next:
    mov dx, bx
    mov al, 0x1d
    out dx, al
    mov al, cl
    out dx, al
    inc dx
    in al, dx
    call file_hex8
    cmp cl, 4
    je .done
    mov dx, separator_slash
    call file_string
    inc cl
    jmp .next
.done:
    pop cx
    pop bx
    ret

codec_read:
    push dx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    in al, dx
    pop dx
    ret

mixer_read:
    push dx
    mov dx, CANBE_MIXER_INDEX
    out dx, al
    call io_wait
    mov dx, CANBE_MIXER_DATA
    in al, dx
    pop dx
    ret

io_wait:
    push dx
    mov dx, PC98_IO_WAIT
    out dx, al
    pop dx
    ret

file_string:
    push ax
    push bx
    push cx
    push si
    push dx
    mov si, dx
    xor cx, cx
.length:
    cmp byte [si], '$'
    je .write
    inc si
    inc cx
    jmp .length
.write:
    mov bx, [report_handle]
    mov ah, 0x40
    int 0x21
    jnc .done
    mov byte [write_error], 1
.done:
    pop dx
    pop si
    pop cx
    pop bx
    pop ax
    ret

file_hex16:
    push ax
    mov al, ah
    call file_hex8
    pop ax
    call file_hex8
    ret

file_hex8:
    push ax
    push bx
    push dx
    mov bl, al
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    call file_nibble
    mov al, bl
    and al, 0x0f
    call file_nibble
    pop dx
    pop bx
    pop ax
    ret

file_nibble:
    push ax
    push bx
    push cx
    push dx
    xor bx, bx
    mov bl, al
    mov al, [hex_digits + bx]
    mov [one_character], al
    mov bx, [report_handle]
    mov cx, 1
    mov dx, one_character
    mov ah, 0x40
    int 0x21
    jnc .done
    mov byte [write_error], 1
.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

file_crlf:
    mov dx, text_crlf
    jmp file_string

print_dos:
    mov ah, 9
    int 0x21
    ret

report_name db 'CU10INFO.TXT',0
report_title db 'PC-9821 Cu10 sound resource report',13,10,'$'
label_snapshot db 'SID/WSSCFG/WSSID=$'
label_codec_aux1 db 'CODEC AUX1 L/R REG2/3=$'
label_codec_aux2 db 'CODEC AUX2 L/R REG4/5=$'
label_mixer db 'CANBE FM L/R=$'
label_opl_status db 'OPL 1488 STATUS=$'
label_pnp_status db 'PNP 0C24 INITIAL=$'
label_pnp_entry db 'PNP ID $'
label_board_dump db 'YMF BOARD 548E/548F REGISTER DUMP 00-3F',13,10,'$'
label_board_line db 'BOARD $'
label_f86 db 'OPL3SA F86 REGS 1/2/3/4=$'
label_480 db 'OPL3SA 480 REGS 1/2/3/4=$'
label_direct_ports db 'RAW 548F/F87/481=$'
label_indirect db 'INDIRECT AC6C OPL3SA REGS 1/2/3/4=$'
label_indirect_locked db ' LOCKED=$'
separator_slash db '/$'
separator_equals db '=$'
separator_colon db ': $'
separator_space db ' $'
text_crlf db 13,10,'$'
hex_digits db '0123456789ABCDEF'

msg_title db 13,10,'PC-9821 Cu10 sound resource probe',13,10,'$'
msg_saved db 'CU10INFO.TXT was written to this floppy image.',13,10,'Return the USB drive to the Mac without rerunning the test.',13,10,'$'
msg_create_failed db 'Could not create CU10INFO.TXT. The image may be write-protected.',13,10,'$'
msg_write_failed db 'A write error occurred while saving CU10INFO.TXT.',13,10,'$'

report_handle dw 0
saved_pnp_control db 0
pnp_read_mode db 0
pnp_address dw 0
write_error db 0
one_character db 0
