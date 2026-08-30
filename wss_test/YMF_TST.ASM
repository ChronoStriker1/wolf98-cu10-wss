bits 16
org 0x100

%define SOUND_ID_PORT       0xa460
%define CODEC_INDEX         0x0f44
%define CANBE_MIXER_INDEX   0x0f4a
%define CANBE_MIXER_DATA    0x0f4b
%define PC98_IO_WAIT        0x005f
%define YMF_BOARD_INDEX     0x548e
%define YMF_BOARD_DATA      0x548f
%define INDIRECT_SELECTOR   0xac6c
%define INDIRECT_DATA       0xac6e
%define OPL_ADDRESS         0x1488
%define OPL_DATA            0x1489
%define OPL_MODE_ADDRESS    0x148a
%define OPL_MODE_DATA       0x148b

start:
    push cs
    pop ds

    mov dx, msg_title
    call print_dos
    call save_state

    mov dx, result_name
    xor cx, cx
    mov ah, 0x3c
    int 0x21
    jc create_failed
    mov [report_handle], ax

    mov dx, report_title
    call file_string
    call write_initial_state
    call force_fm_output

    mov dx, msg_test1
    call print_dos
    call enable_nec_ymf
    mov dx, SOUND_ID_PORT
    mov al, 0x82
    out dx, al
    call io_wait
    call run_tone_test
    mov dx, report_test1
    call write_test_result

    call silence_fm
    call restore_state
    call write_restored_state

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

save_state:
    mov dx, SOUND_ID_PORT
    in al, dx
    mov [saved_sound_id], al

    mov al, 0
    call board_read
    mov [saved_board0], al
    mov al, 0x20
    call board_read
    mov [saved_board20], al

    mov al, 1
    call indirect_read
    mov [saved_control1], al
    mov al, 2
    call indirect_read
    mov [saved_control2], al
    mov al, 3
    call indirect_read
    mov [saved_control3], al
    mov al, 4
    call indirect_read
    mov [saved_control4], al

    mov al, 2
    call codec_read
    mov [saved_codec2], al
    mov al, 3
    call codec_read
    mov [saved_codec3], al
    mov al, 4
    call codec_read
    mov [saved_codec4], al
    mov al, 5
    call codec_read
    mov [saved_codec5], al
    mov al, 0x30
    call mixer_read
    mov [saved_mixer30], al
    mov al, 0x31
    call mixer_read
    mov [saved_mixer31], al
    ret

restore_state:
    mov ah, [saved_control3]
    mov al, 3
    call indirect_write
    mov ah, [saved_board20]
    mov al, 0x20
    call board_write
    mov ah, [saved_codec2]
    mov al, 2
    call codec_write
    mov ah, [saved_codec3]
    mov al, 3
    call codec_write
    mov ah, [saved_codec4]
    mov al, 4
    call codec_write
    mov ah, [saved_codec5]
    mov al, 5
    call codec_write
    mov ah, [saved_mixer30]
    mov al, 0x30
    call mixer_write
    mov ah, [saved_mixer31]
    mov al, 0x31
    call mixer_write
    mov dx, SOUND_ID_PORT
    mov al, [saved_sound_id]
    out dx, al
    ret

force_fm_output:
    xor ah, ah
    mov al, 0x30
    call mixer_write
    xor ah, ah
    mov al, 0x31
    call mixer_write
    ; AD1848 registers 4 and 5 are AUX2 left/right. OPL3 is wired to AUX2
    ; on Yamaha OPL3-SA controllers; registers 2 and 3 are AUX1/CD.
    xor ah, ah
    mov al, 4
    call codec_write
    xor ah, ah
    mov al, 5
    call codec_write
    ret

; Follow the active branch in NEC's VxD for board status F0h. Register 3
; already contains the synth-enable bit on the tested Cu10; preserve all bits,
; assert bit 7 as NEC does, and change only board register 20h to 00h.
enable_nec_ymf:
    mov al, 3
    call indirect_read
    or al, 0x80
    mov ah, al
    mov al, 3
    call indirect_write
    xor ah, ah
    mov al, 0x20
    call board_write
    ret

run_tone_test:
    mov dx, SOUND_ID_PORT
    in al, dx
    mov [test_sound_id], al
    mov al, 0x20
    call board_read
    mov [test_board20], al
    mov al, 3
    call indirect_read
    mov [test_control3], al
    mov al, 4
    call codec_read
    mov [test_codec4], al
    mov al, 5
    call codec_read
    mov [test_codec5], al
    mov al, 0x30
    call mixer_read
    mov [test_mixer30], al
    mov al, 0x31
    call mixer_read
    mov [test_mixer31], al
    call probe_opl_status
    call play_opl_tone
    call ask_heard
    mov [test_heard], al
    ret

probe_opl_status:
    mov dx, OPL_ADDRESS
    in al, dx
    mov [probe_before], al

    mov ax, 0x6004
    call opl_write
    mov ax, 0x8004
    call opl_write
    mov ax, 0xff02
    call opl_write
    mov ax, 0x2104
    call opl_write
    mov cx, 256
    mov dx, OPL_ADDRESS
.wait:
    in al, dx
    loop .wait
    in al, dx
    mov [probe_after], al

    mov ax, 0x6004
    call opl_write
    mov ax, 0x8004
    call opl_write
    ret

play_opl_tone:
    mov ax, 0x2001
    call opl_write
    mov ax, 0x0120
    call opl_write
    mov ax, 0x0130
    call opl_write
    mov ax, 0x1040
    call opl_write
    mov ax, 0xf060
    call opl_write
    mov ax, 0x0070
    call opl_write
    mov ax, 0x0f80
    call opl_write

    mov ax, 0x0123
    call opl_write
    mov ax, 0x0043
    call opl_write
    mov ax, 0xf063
    call opl_write
    mov ax, 0x0073
    call opl_write
    mov ax, 0x0f83
    call opl_write

    mov ax, 0x31c0
    call opl_write
    mov ax, 0x98a0
    call opl_write
    mov ax, 0x31b0
    call opl_write
    call wait_two_seconds
    mov ax, 0x11b0
    call opl_write
    ret

silence_fm:
    mov ax, 0x11b0
    call opl_write
    ret

; AL = OPL register, AH = value.
opl_write:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov dx, OPL_ADDRESS
    mov al, bl
    out dx, al
    mov cx, 6
.address_delay:
    in al, dx
    loop .address_delay
    mov dx, OPL_DATA
    mov al, bh
    out dx, al
    mov dx, OPL_ADDRESS
    mov cx, 42
.data_delay:
    in al, dx
    loop .data_delay
    pop dx
    pop cx
    pop bx
    pop ax
    ret

board_read:
    push dx
    mov dx, YMF_BOARD_INDEX
    out dx, al
    call io_wait
    mov dx, YMF_BOARD_DATA
    in al, dx
    pop dx
    ret

; AL = board register, AH = value.
board_write:
    push ax
    push bx
    push dx
    mov bx, ax
    mov dx, YMF_BOARD_INDEX
    mov al, bl
    out dx, al
    call io_wait
    mov dx, YMF_BOARD_DATA
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

; AL = OPL3-SA register, returns AL = value.
indirect_read:
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

; AL = OPL3-SA register, AH = value.
indirect_write:
    push ax
    push bx
    push dx
    mov bx, ax
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
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

codec_read:
    push dx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    in al, dx
    pop dx
    ret

codec_write:
    push dx
    mov dx, CODEC_INDEX
    out dx, al
    inc dx
    mov al, ah
    out dx, al
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

mixer_write:
    push ax
    push bx
    push dx
    mov bx, ax
    mov dx, CANBE_MIXER_INDEX
    mov al, bl
    out dx, al
    call io_wait
    mov dx, CANBE_MIXER_DATA
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

io_wait:
    push dx
    mov dx, PC98_IO_WAIT
    out dx, al
    pop dx
    ret

wait_two_seconds:
    push ax
    push bx
    push dx
    mov ah, 0x2c
    int 0x21
    mov bl, dh
    add bl, 2
    cmp bl, 60
    jb .wait
    sub bl, 60
.wait:
    mov ah, 0x2c
    int 0x21
    cmp dh, bl
    jne .wait
    pop dx
    pop bx
    pop ax
    ret

ask_heard:
    mov dx, msg_heard
    call print_dos
.key:
    mov ah, 8
    int 0x21
    and al, 0xdf
    cmp al, 'Y'
    je .yes
    cmp al, 'N'
    jne .key
    mov dl, 'N'
    mov ah, 2
    int 0x21
    call print_crlf
    xor al, al
    ret
.yes:
    mov dl, 'Y'
    mov ah, 2
    int 0x21
    call print_crlf
    mov al, 1
    ret

write_initial_state:
    mov dx, report_initial
    call file_string
    mov al, [saved_sound_id]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_board0]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_board20]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_control1]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_control2]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_control3]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_control4]
    call file_hex8
    call file_crlf

    mov dx, report_initial_codec
    call file_string
    mov al, [saved_codec2]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_codec3]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_codec4]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [saved_codec5]
    call file_hex8
    call file_crlf
    ret

write_test_result:
    call file_string
    mov al, [test_sound_id]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_board20]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_control3]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_codec4]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_codec5]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_mixer30]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_mixer31]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [probe_before]
    call file_hex8
    mov dx, separator_arrow
    call file_string
    mov al, [probe_after]
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, [test_heard]
    add al, '0'
    mov [one_character], al
    mov bx, [report_handle]
    mov cx, 1
    mov dx, one_character
    mov ah, 0x40
    int 0x21
    jnc .done
    mov byte [write_error], 1
.done:
    call file_crlf
    ret

write_restored_state:
    mov dx, report_restored
    call file_string
    mov dx, SOUND_ID_PORT
    in al, dx
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, 0x20
    call board_read
    call file_hex8
    mov dx, separator_slash
    call file_string
    mov al, 3
    call indirect_read
    call file_hex8
    mov dx, separator_slash
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

print_crlf:
    mov dx, text_crlf
print_dos:
    mov ah, 9
    int 0x21
    ret

result_name db 'YMFRESUL.TXT',0
report_title db 'PC-9821 Cu10 OPL AUX2 output test',13,10,'$'
report_initial db 'INITIAL SID/BOARD00/BOARD20/CTL1/2/3/4=$'
report_initial_codec db 'INITIAL CODEC REG2/3/4/5=$'
report_test1 db 'AUX2 TEST SID/B20/C3/AUX2L/R/FML/R/TIMER/HEARD=$'
report_restored db 'RESTORED SID/BOARD20/CTL3/AUX2L/R=$'
separator_slash db '/$'
separator_arrow db '->$'
text_crlf db 13,10,'$'
hex_digits db '0123456789ABCDEF'

msg_title db 13,10,'PC-9821 Cu10 OPL AUX2 output test',13,10,'$'
msg_test1 db 13,10,'One tone: OPL enabled, codec AUX2 unmuted',13,10,'$'
msg_heard db 'Did you hear the OPL tone? (Y/N) $'
msg_saved db 13,10,'YMFRESUL.TXT was saved. All changed values were restored.',13,10,'$'
msg_create_failed db 'Could not create YMFRESUL.TXT. No hardware values were changed.',13,10,'$'
msg_write_failed db 'A write error occurred. Hardware values were still restored.',13,10,'$'

report_handle dw 0
write_error db 0
saved_sound_id db 0
saved_board0 db 0
saved_board20 db 0
saved_control1 db 0
saved_control2 db 0
saved_control3 db 0
saved_control4 db 0
saved_codec2 db 0
saved_codec3 db 0
saved_codec4 db 0
saved_codec5 db 0
saved_mixer30 db 0
saved_mixer31 db 0
test_sound_id db 0
test_board20 db 0
test_control3 db 0
test_codec4 db 0
test_codec5 db 0
test_mixer30 db 0
test_mixer31 db 0
probe_before db 0
probe_after db 0
test_heard db 0
one_character db 0
