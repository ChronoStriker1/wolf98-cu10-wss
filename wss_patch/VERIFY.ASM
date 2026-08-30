bits 16
org 0x100

    push ds
    pop es
    cld

    mov dx, source_name
    mov ax, 0x3d00
    int 0x21
    jc failed
    mov [source_handle], ax

    mov dx, target_name
    mov ax, 0x3d00
    int 0x21
    jc failed
    mov [target_handle], ax

.next_block:
    mov bx, [source_handle]
    mov dx, source_buffer
    mov cx, 512
    mov ah, 0x3f
    int 0x21
    jc failed
    mov [block_bytes], ax

    mov bx, [target_handle]
    mov dx, target_buffer
    mov cx, 512
    mov ah, 0x3f
    int 0x21
    jc failed
    cmp ax, [block_bytes]
    jne failed

    mov cx, ax
    jcxz verified
    mov si, source_buffer
    mov di, target_buffer
    repe cmpsb
    jne failed
    jmp .next_block

verified:
    mov ax, 0x4c00
    int 0x21

failed:
    mov ax, 0x4c01
    int 0x21

source_name:   db 'C:\WOLF98.EXE', 0
target_name:   db 'B:\WOLF3D\WOLF98.EXE', 0
source_handle: dw 0
target_handle: dw 0
block_bytes:   dw 0
source_buffer: times 512 db 0
target_buffer: times 512 db 0
