bits 16
org 0x100

%define SOUND_ID_PORT       0xa460
%define WSS_CONFIG          0x0f40
%define WSS_ID              0x0f43
%define CODEC_INDEX         0x0f44
%define CANBE_MIXER_INDEX   0x0f4a
%define CANBE_MIXER_DATA    0x0f4b
%define PC98_IO_WAIT        0x005f
%define YMF701_CONTROL      0x0f86
%define YMF701_DATA         0x0f87
%define YMF701_PASSWORD     0x1d

%define OPN_ADDRESS         0x0188
%define OPN_DATA            0x018a
%define OPL_ADDRESS         0x1488
%define OPL_DATA            0x1489
%define OPL_MODE_ADDRESS    0x148a
%define OPL_MODE_DATA       0x148b
%define OPL_CONTROL_ADDRESS 0x148e
%define OPL_CONTROL_DATA    0x148f

start:
    push cs
    pop ds
    push cs
    pop es

    mov dx, msg_title
    call print_dos
    mov dx, msg_instructions
    call print_dos

    call save_state
    mov dx, msg_initial
    call print_dos
    call print_snapshot
    call force_fm_output

    mov dx, msg_test_opn
    call print_dos
    call play_opn_tone
    call ask_heard
    mov [heard_opn], al

    mov dx, msg_test_direct
    call print_dos
    call probe_opl_status
    mov al, [probe_before]
    mov [direct_before], al
    mov al, [probe_after]
    mov [direct_after], al
    call play_opl_tone
    call ask_heard
    mov [heard_direct], al

    mov dx, msg_test_118
    call print_dos
    call init_118_route
    call capture_route_state
    mov al, [route_sound_id]
    mov [sound_id_118], al
    mov al, [route_control]
    mov [control_118], al
    call print_fm_state
    call probe_opl_status
    mov al, [probe_before]
    mov [probe_118_before], al
    mov al, [probe_after]
    mov [probe_118_after], al
    call play_opl_tone
    call ask_heard
    mov [heard_118], al

    mov dx, msg_test_701
    call print_dos
    call init_701_route
    call capture_route_state
    mov al, [route_sound_id]
    mov [sound_id_701], al
    mov al, [route_control]
    mov [control_701], al
    call print_fm_state
    call probe_opl_status
    mov al, [probe_before]
    mov [probe_701_before], al
    mov al, [probe_after]
    mov [probe_701_after], al
    call play_opl_tone
    call ask_heard
    mov [heard_701], al

    mov dx, msg_test_control
    call print_dos
    call select_initial_sound_id
    call enable_701_synth
    call print_controller_state
    call probe_opl_status
    mov al, [probe_before]
    mov [probe_control_before], al
    mov al, [probe_after]
    mov [probe_control_after], al
    call play_opl_tone
    call ask_heard
    mov [heard_control], al

    mov dx, msg_test_control_route
    call print_dos
    call enable_701_synth
    call init_701_route
    call print_controller_state
    call print_fm_state
    call probe_opl_status
    mov al, [probe_before]
    mov [probe_control_route_before], al
    mov al, [probe_after]
    mov [probe_control_route_after], al
    call play_opl_tone
    call ask_heard
    mov [heard_control_route], al

    call silence_fm
    call restore_state

    mov dx, msg_summary
    call print_dos
    mov dx, msg_summary_opn
    mov al, [heard_opn]
    call print_result
    mov dx, msg_summary_direct
    mov al, [heard_direct]
    call print_result
    mov dx, msg_summary_118
    mov al, [heard_118]
    call print_result
    mov dx, msg_summary_701
    mov al, [heard_701]
    call print_result
    mov dx, msg_summary_control
    mov al, [heard_control]
    call print_result
    mov dx, msg_summary_control_route
    mov al, [heard_control_route]
    call print_result
    call print_final_registers
    mov dx, msg_done
    call print_dos

    mov ax, 0x4c00
    int 0x21

save_state:
    mov dx, SOUND_ID_PORT
    in al, dx
    mov [saved_sound_id], al
    mov dx, WSS_CONFIG
    in al, dx
    mov [saved_wss_config], al
    mov dx, WSS_ID
    in al, dx
    mov [saved_wss_id], al
    mov al, 4
    call codec_read
    mov [saved_codec4], al
    mov al, 5
    call codec_read
    mov [saved_codec5], al
    mov al, 1
    call mixer_read
    mov [saved_mixer1], al
    mov al, 0x30
    call mixer_read
    mov [saved_mixer30], al
    mov al, 0x31
    call mixer_read
    mov [saved_mixer31], al
    mov al, 1
    call controller_read
    mov [saved_control1], al
    mov al, 2
    call controller_read
    mov [saved_control2], al
    mov al, 3
    call controller_read
    mov [saved_control3], al
    mov al, 4
    call controller_read
    mov [saved_control4], al
    ret

restore_state:
    mov ah, [saved_codec4]
    mov al, 4
    call codec_write
    mov ah, [saved_codec5]
    mov al, 5
    call codec_write
    mov ah, [saved_mixer1]
    mov al, 1
    call mixer_write
    mov ah, [saved_mixer30]
    mov al, 0x30
    call mixer_write
    mov ah, [saved_mixer31]
    mov al, 0x31
    call mixer_write
    mov ah, [saved_control3]
    mov al, 3
    call controller_write
    mov dx, WSS_CONFIG
    mov al, [saved_wss_config]
    out dx, al
    mov dx, SOUND_ID_PORT
    mov al, [saved_sound_id]
    out dx, al
    ret

force_fm_output:
    ; The CanBe FM mixer feeds the WSS codec AUX2 input. Use a known audible
    ; level for this diagnostic instead of inheriting a possibly silent value.
    xor ah, ah
    mov al, 0x30
    call mixer_write
    xor ah, ah
    mov al, 0x31
    call mixer_write
    xor ah, ah
    mov al, 4
    call codec_write
    xor ah, ah
    mov al, 5
    call codec_write
    ret

print_snapshot:
    mov dx, label_sound_id
    call print_dos
    mov dx, SOUND_ID_PORT
    in al, dx
    call print_hex8
    call print_space

    mov dx, label_wss_config
    call print_dos
    mov dx, WSS_CONFIG
    in al, dx
    call print_hex8
    call print_space

    mov dx, label_wss_id
    call print_dos
    mov dx, WSS_ID
    in al, dx
    call print_hex8
    call print_crlf

    mov dx, label_codec4
    call print_dos
    mov al, 4
    call codec_read
    call print_hex8
    call print_space

    mov dx, label_codec5
    call print_dos
    mov al, 5
    call codec_read
    call print_hex8
    call print_crlf

    mov dx, label_mixer1
    call print_dos
    mov al, 1
    call mixer_read
    call print_hex8
    call print_space

    mov dx, label_mixer30
    call print_dos
    mov al, 0x30
    call mixer_read
    call print_hex8
    call print_space

    mov dx, label_mixer31
    call print_dos
    mov al, 0x31
    call mixer_read
    call print_hex8
    call print_crlf
    call print_fm_state
    call print_controller_state
    ret

print_controller_state:
    mov dx, label_controller
    call print_dos
    mov al, 1
    call controller_read
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, 2
    call controller_read
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, 3
    call controller_read
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, 4
    call controller_read
    call print_hex8
    call print_crlf
    ret

print_fm_state:
    mov dx, label_sound_id
    call print_dos
    mov dx, SOUND_ID_PORT
    in al, dx
    call print_hex8
    call print_space

    mov dx, label_opl_status
    call print_dos
    mov dx, OPL_ADDRESS
    in al, dx
    call print_hex8
    call print_space

    mov dx, label_control0
    call print_dos
    mov dx, OPL_CONTROL_ADDRESS
    xor al, al
    out dx, al
    mov dx, OPL_CONTROL_DATA
    in al, dx
    call print_hex8
    call print_crlf
    ret

capture_route_state:
    mov dx, SOUND_ID_PORT
    in al, dx
    mov [route_sound_id], al
    mov dx, OPL_CONTROL_ADDRESS
    xor al, al
    out dx, al
    mov dx, OPL_CONTROL_DATA
    in al, dx
    mov [route_control], al
    ret

probe_opl_status:
    mov dx, msg_probe
    call print_dos
    mov dx, OPL_ADDRESS
    in al, dx
    call print_hex8
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

    mov dx, msg_arrow
    call print_dos
    mov al, [probe_after]
    call print_hex8
    call print_crlf
    ret

init_118_route:
    mov dx, SOUND_ID_PORT
    mov al, [saved_sound_id]
    and al, 0xf0
    or al, 3
    out dx, al

    mov dx, OPL_MODE_ADDRESS
    mov al, 5
    out dx, al
    call io_wait_3
    mov dx, OPL_MODE_DATA
    mov al, 5
    out dx, al
    call io_wait_3

    mov dx, OPL_MODE_ADDRESS
    mov al, 8
    out dx, al
    call io_wait_3
    mov dx, OPL_MODE_DATA
    mov al, 4
    out dx, al

    mov cx, 2000
.delay:
    call io_wait_3
    loop .delay

    mov dx, OPL_MODE_DATA
    xor al, al
    out dx, al
    mov dx, OPL_ADDRESS
    mov al, 0xf7
    out dx, al
    mov dx, OPL_DATA
    out dx, al
    ret

init_701_route:
    mov dx, SOUND_ID_PORT
    mov al, 0x82
    out dx, al
    call io_wait_3

    mov al, 1
    call mixer_read
    and al, 0x77
    mov ah, al
    mov al, 1
    call mixer_write

    mov dx, OPL_MODE_ADDRESS
    mov al, 5
    out dx, al
    call io_wait_3
    mov dx, OPL_MODE_DATA
    mov al, 5
    out dx, al
    call io_wait_3

    mov dx, OPL_MODE_ADDRESS
    mov al, 8
    out dx, al
    call io_wait_3
    mov dx, OPL_MODE_DATA
    mov al, 4
    out dx, al
    call io_wait_3

    mov cx, 40
.delay:
    call io_wait_3
    loop .delay

    mov dx, OPL_MODE_DATA
    xor al, al
    out dx, al
    call io_wait_3
    mov dx, OPL_ADDRESS
    mov al, 0xf7
    out dx, al
    call io_wait_3
    mov dx, OPL_DATA
    xor al, al
    out dx, al
    call io_wait_3

    mov ax, 0x0105
    call opl3_write
    mov ax, 0x6004
    call opl_write
    mov ax, 0x0004
    call opl3_write
    mov ax, 0x0008
    call opl_write
    ret

select_initial_sound_id:
    mov dx, SOUND_ID_PORT
    mov al, [saved_sound_id]
    out dx, al
    call io_wait_3
    ret

enable_701_synth:
    mov al, 3
    call controller_read
    or al, 2
    mov ah, al
    mov al, 3
    call controller_write
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

play_opn_tone:
    mov ax, 0x0028
    call opn_write
    mov ax, 0x0022
    call opn_write
    mov ax, 0x0027
    call opn_write

    mov si, opn_operator_offsets
    mov cx, 4
.operator:
    lodsb
    mov bl, al
    xor bh, bh
    mov ax, 0x0130
    add al, bl
    call opn_write
    mov ax, 0x3040
    add al, bl
    call opn_write
    mov ax, 0x1f50
    add al, bl
    call opn_write
    mov ax, 0x0060
    add al, bl
    call opn_write
    mov ax, 0x0070
    add al, bl
    call opn_write
    mov ax, 0x0f80
    add al, bl
    call opn_write
    loop .operator

    mov ax, 0x07b0
    call opn_write
    mov ax, 0xc0b4
    call opn_write
    mov ax, 0x22a4
    call opn_write
    mov ax, 0x69a0
    call opn_write
    mov ax, 0xf028
    call opn_write
    call wait_two_seconds
    mov ax, 0x0028
    call opn_write
    ret

silence_fm:
    mov ax, 0x11b0
    call opl_write
    mov ax, 0x0028
    call opn_write
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

; AL = OPL3 bank-1 register, AH = value.
opl3_write:
    push ax
    push bx
    push cx
    push dx
    mov bx, ax
    mov dx, OPL_MODE_ADDRESS
    mov al, bl
    out dx, al
    mov cx, 6
.address_delay:
    in al, dx
    loop .address_delay
    mov dx, OPL_MODE_DATA
    mov al, bh
    out dx, al
    mov dx, OPL_MODE_ADDRESS
    mov cx, 42
.data_delay:
    in al, dx
    loop .data_delay
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; AL = OPN register, AH = value.
opn_write:
    push ax
    push bx
    push dx
    mov bx, ax
    mov dx, OPN_ADDRESS
    mov al, bl
    out dx, al
    call io_wait_3
    mov dx, OPN_DATA
    mov al, bh
    out dx, al
    call io_wait_3
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
    call io_wait_3
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
    call io_wait_3
    mov dx, CANBE_MIXER_DATA
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

; AL = controller register, returns AL = value. The YMF701 requires password
; 1Dh before every indexed access.
controller_read:
    push bx
    push dx
    mov bl, al
    mov dx, YMF701_CONTROL
    mov al, YMF701_PASSWORD
    out dx, al
    mov al, bl
    out dx, al
    inc dx
    in al, dx
    pop dx
    pop bx
    ret

; AL = controller register, AH = value.
controller_write:
    push ax
    push bx
    push dx
    mov bx, ax
    mov dx, YMF701_CONTROL
    mov al, YMF701_PASSWORD
    out dx, al
    mov al, bl
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    pop dx
    pop bx
    pop ax
    ret

io_wait_3:
    push dx
    mov dx, PC98_IO_WAIT
    out dx, al
    out dx, al
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

print_result:
    push ax
    call print_dos
    pop ax
    test al, al
    jz .no
    mov dx, result_yes
    jmp print_dos
.no:
    mov dx, result_no
    jmp print_dos

print_final_registers:
    mov dx, msg_final_registers
    call print_dos

    mov dx, report_initial
    call print_dos
    mov al, [saved_sound_id]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_wss_config]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_wss_id]
    call print_hex8
    call print_crlf

    mov dx, report_aux
    call print_dos
    mov al, [saved_codec4]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_codec5]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_mixer1]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_mixer30]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_mixer31]
    call print_hex8
    call print_crlf

    mov dx, report_direct
    call print_dos
    mov al, [direct_before]
    call print_hex8
    mov dx, msg_arrow
    call print_dos
    mov al, [direct_after]
    call print_hex8
    call print_crlf

    mov dx, report_118
    call print_dos
    mov al, [sound_id_118]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [control_118]
    call print_hex8
    mov dl, ' '
    mov ah, 2
    int 0x21
    mov al, [probe_118_before]
    call print_hex8
    mov dx, msg_arrow
    call print_dos
    mov al, [probe_118_after]
    call print_hex8
    call print_crlf

    mov dx, report_701
    call print_dos
    mov al, [sound_id_701]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [control_701]
    call print_hex8
    mov dl, ' '
    mov ah, 2
    int 0x21
    mov al, [probe_701_before]
    call print_hex8
    mov dx, msg_arrow
    call print_dos
    mov al, [probe_701_after]
    call print_hex8
    call print_crlf

    mov dx, report_controller_initial
    call print_dos
    mov al, [saved_control1]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_control2]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_control3]
    call print_hex8
    mov dl, '/'
    mov ah, 2
    int 0x21
    mov al, [saved_control4]
    call print_hex8
    call print_crlf

    mov dx, report_control
    call print_dos
    mov al, [probe_control_before]
    call print_hex8
    mov dx, msg_arrow
    call print_dos
    mov al, [probe_control_after]
    call print_hex8
    call print_crlf

    mov dx, report_control_route
    call print_dos
    mov al, [probe_control_route_before]
    call print_hex8
    mov dx, msg_arrow
    call print_dos
    mov al, [probe_control_route_after]
    call print_hex8
    call print_crlf
    ret

print_hex8:
    push ax
    push bx
    push dx
    mov bl, al
    shr al, 1
    shr al, 1
    shr al, 1
    shr al, 1
    call print_nibble
    mov al, bl
    and al, 0x0f
    call print_nibble
    pop dx
    pop bx
    pop ax
    ret

print_nibble:
    and al, 0x0f
    add al, '0'
    cmp al, '9'
    jbe .emit
    add al, 7
.emit:
    mov dl, al
    mov ah, 2
    int 0x21
    ret

print_dos:
    mov ah, 9
    int 0x21
    ret

print_space:
    mov dl, ' '
    mov ah, 2
    int 0x21
    ret

print_crlf:
    mov dx, crlf
    jmp print_dos

msg_title db 13,10,'PC-9821 Cu10 FM hardware diagnostic',13,10,'$'
msg_instructions db 'Six labeled two-second tones will be attempted.',13,10
                 db 'Press Y only when you hear the tone for that test.',13,10,'$'
msg_initial db 13,10,'Initial hardware state:',13,10,'$'
msg_test_opn db 13,10,'TEST 1: Standard OPN FM at 0188h',13,10,'$'
msg_test_direct db 13,10,'TEST 2: Direct extended FM at 1488h, no handoff',13,10,'$'
msg_test_118 db 13,10,'TEST 3: 118/YMF297-style extended-FM handoff',13,10,'$'
msg_test_701 db 13,10,'TEST 4: NEC/YMF701-style extended-FM handoff',13,10,'$'
msg_test_control db 13,10,'TEST 5: YMF701 controller synth enable, direct OPL',13,10,'$'
msg_test_control_route db 13,10,'TEST 6: YMF701 controller enable plus NEC handoff',13,10,'$'
msg_probe db 'OPL timer status before -> after: $'
msg_arrow db ' -> $'
msg_heard db 'Did you hear this tone? Y/N: $'
msg_summary db 13,10,'Results:',13,10,'$'
msg_summary_opn db '  OPN 0188h:       $'
msg_summary_direct db '  OPL direct:      $'
msg_summary_118 db '  OPL 118 route:   $'
msg_summary_701 db '  OPL YMF701 route:$'
msg_summary_control db '  YMF701 enabled:  $'
msg_summary_control_route db '  YMF701 plus route:$'
result_yes db ' HEARD',13,10,'$'
result_no db ' silent',13,10,'$'
msg_final_registers db 13,10,'Register report:',13,10,'$'
report_initial db '  Initial SID/WSS cfg/ID: $'
report_aux db '  AUX L/R, mixer 01/L/R: $'
report_direct db '  Direct OPL timer: $'
report_118 db '  118 SID/Ctl timer: $'
report_701 db '  701 SID/Ctl timer: $'
report_controller_initial db '  Initial YMF701 ctl 1/2/3/4: $'
report_control db '  Controller OPL timer: $'
report_control_route db '  Controller plus route timer: $'
msg_done db 13,10,'Photograph or copy this screen before rebooting.',13,10
         db 'The saved mixer, codec, WSS, and Sound ID values were restored.',13,10,'$'

label_sound_id db 'SoundID=$'
label_wss_config db 'WSScfg=$'
label_wss_id db 'WSSID=$'
label_codec4 db 'AUX2L=$'
label_codec5 db 'AUX2R=$'
label_mixer1 db 'Mix01=$'
label_mixer30 db 'FM-L=$'
label_mixer31 db 'FM-R=$'
label_opl_status db 'OPLstat=$'
label_control0 db 'Ctl00=$'
label_controller db 'YMF701 ctl 1/2/3/4=$'
crlf db 13,10,'$'

opn_operator_offsets db 0, 4, 8, 12
saved_sound_id db 0
saved_wss_config db 0
saved_wss_id db 0
saved_codec4 db 0
saved_codec5 db 0
saved_mixer1 db 0
saved_mixer30 db 0
saved_mixer31 db 0
probe_before db 0
probe_after db 0
heard_opn db 0
heard_direct db 0
heard_118 db 0
heard_701 db 0
heard_control db 0
heard_control_route db 0
route_sound_id db 0
route_control db 0
direct_before db 0
direct_after db 0
sound_id_118 db 0
control_118 db 0
probe_118_before db 0
probe_118_after db 0
sound_id_701 db 0
control_701 db 0
probe_701_before db 0
probe_701_after db 0
saved_control1 db 0
saved_control2 db 0
saved_control3 db 0
saved_control4 db 0
probe_control_before db 0
probe_control_after db 0
probe_control_route_before db 0
probe_control_route_after db 0
