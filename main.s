/*
*   Copyright 2025 Siddhartha Menon
*
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*       http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*   limitations under the License.
*/

.text
.global main
.balign 4
.equ GRID_ROWS, 24
.equ GRID_COLS, 80
.equ HALF_ROWS, GRID_ROWS / 2
.equ HALF_COLS, GRID_COLS / 2
// GRID_STACK_SIZE must be a multiple of 16
.equ GRID_STACK_SIZE, (((GRID_ROWS * GRID_COLS) / 16 + 1) * 16)
.equ NUM_FRAMES, 12
.equ FILL_CHAR, 32 // Space

file_handle .req x19
orig .req x20
rot .req x21


main:
stp fp, lr, [sp, #-16]!
stp x19, x20, [sp, #-16]!
stp x21, x22, [sp, #-16]!
str d19, [sp, #-16]!
mov x0, 2 * GRID_STACK_SIZE
sub sp, sp, x0
mov fp, sp

mov orig, sp // Load grid for original image
mov x0, GRID_STACK_SIZE
add rot, orig, x0 // load grid for rotated image

ldr x0, =filename
ldr x1, =file_mode
bl fopen
cbz x0, done
mov file_handle, x0

mov x0, orig
bl clean
bl load_image
cbnz w0, done

ldr x0, =pi
ldr s0, [x0]
mov x0, (NUM_FRAMES / 2)
scvtf s1, x0
fdiv s0, s0, s1
fneg s0, s0 // negate theta for a clockwise angle
fmov s19, s0 // backup theta

// Main reset-rotate-draw loop
mov x22, #0
anim_start:
cmp x22, NUM_FRAMES
bgt anim_fin
bl reset
scvtf s0, x22
fmul s0, s0, s19 // angle for this frame = frame_num * theta
bl rotate
bl print_screen
mov x0, #1
lsl x0, x0, #20 // 1,048,576 usec ~ 1 sec
bl usleep
add x22, x22, #1
b anim_start
anim_fin:

done:
mov x0, file_handle
cbz x0, 1f // File was NULL, don't close
bl fclose
1:
mov x0, 2 * GRID_STACK_SIZE
add sp, sp, x0
ldr d19, [sp], #16
ldp x21, x22, [sp], #16
ldp x19, x20, [sp], #16
ldp fp, lr, [sp], #16
mov x0, #0
ret


// Read ascii image into grid memory
load_image:
stp fp, lr, [sp, #-16]!
str x22, [sp, #-16]!
mov fp, sp

mov x22, #0
load_loop:
cmp x22, GRID_ROWS
bge load_end
mov w1, GRID_COLS
madd x0, x22, x1, orig
mov w1, #1
mov w2, GRID_COLS + 1 // Add one for null-terminator
mov x3, file_handle
bl fread
cmp w0, GRID_COLS + 1
bne 10f
add x22, x22, #1
b load_loop
load_end:
mov x0, #0
b 99f

10: // Handle errors
ldr x0, =err_msg
bl perror
mov x0, #1
b 99f

99:
ldr x22, [sp], #16
ldp fp, lr, [sp], #16
ret


// x0: address of grid
print_screen:
stp fp, lr, [sp, #-16]!
stp x22, x23, [sp, #-16]!
mov fp, sp

mov x22, #1 // i
1: // i-loop
cmp x22, GRID_ROWS
bgt 80f
mov x23, #1 // j
2:
cmp x23, GRID_COLS
bgt 40f
sub x0, x22, #1
mov x1, GRID_COLS
sub x2, x23, #1
madd x0, x0, x1, x2 // offset of character
add x0, rot, x0 // address of character
ldrb w3, [x0]
// Escape code to draw at (i,j)
ldr x0, =draw_code
mov x1, x22
mov x2, x23
bl printf
cmp x0, #7 // length of escape sequence + char
blt 10f
add x23, x23, #1
b 2b
40:
add x22, x22, #1
b 1b
80:
mov x0, #0
b 99f

10: // handle errors
ldr x0, =err_msg
bl perror
mov w0, #1
b 99f

99:
ldp x22, x23, [sp], #16
ldp fp, lr, [sp], #16
ret
scvtf s20, x0


// Rotate the grid by theta radians
// s0: theta
rotate:
stp fp, lr, [sp, #-16]!
stp x22, x23, [sp, #-16]!
stp x24, x25, [sp, #-16]!
str d19, [sp, #-16]!
mov fp, sp

fmov s19, s0 // backup theta

mov x0, rot
bl clean

fmov s0, s19
bl sinf
fmov s20, s0 // sin(theta)
fmov s0, s19
bl cosf
fmov s21, s0 // cos(theta)

mov x24, HALF_ROWS
mov x25, HALF_COLS

mov x22, #0 // row_count, i
row_loop:
cmp x22, GRID_ROWS
bge 40f
mov x23, #0 // col_count, j
col_loop:
cmp x23, GRID_COLS
bge 20f
// Convert i, j into x, y coords
scvtf s11, x22 // (float) i
scvtf s12, x23 // (float) j
scvtf s13, w25 // (float) HALF_COLS
scvtf s14, w24 // (float) HALF_ROWS
fsub s13, s12, s13 // x = j - HALF_COLS
fsub s12, s14, s11 // y = HALF_ROWS - i
fmov s11, s13
// Calculate the rotated coords
fmul s13, s12, s20 // y * sin(th)
fneg s13, s13
fmadd s13, s11, s21, s13 // x_rot = x * cos(th) - y * sin(th)
fmul s14, s12, s21 // y * cos(th)
fmadd s14, s11, s20, s14 // y_rot = x * sin(th) + y * cos(th)
fcvtas x9, s13 // (int) x_rot
fcvtas x10, s14 // (int) y_rot
sub x11, x10, HALF_ROWS
neg x11, x11 // i_rot = HALF_ROWS - y_rot
add x12, x9, HALF_COLS // j_rot = HALF_COLS + x_rot
mov x2, GRID_COLS
madd x0, x22, x2, x23
add x0, orig, x0
ldrb w0, [x0]
madd x1, x11, x2, x12
// skip iteration if rotated point is out of bounds
cmp x11, #0
blt 10f
cmp x11, GRID_ROWS
bge 10f
cmp x12, #0
blt 10f
cmp x12, GRID_COLS
bge 10f
add x1, rot, x1
strb w0, [x1] // rot[i_rot, j_rot] = orig[i, j]
10:
add w23, w23, #1
b col_loop
20:
add w22, w22, #1
b row_loop
40:
ldr d19, [sp], #16
ldp x24, x25, [sp], #16
ldp x22, x23, [sp], #16
ldp fp, lr, [sp], #16
ret


// Move the cursor the top-left corner of the screen
reset:
stp fp, lr, [sp, #-16]!
mov fp, sp
ldr x0, =reset_code
bl puts
ldp fp, lr, [sp], #16
ret


// Fills the grid with FILL_CHAR
// x0: Grid address
clean:
stp fp, lr, [sp, #-16]!
mov fp, sp
mov w1, FILL_CHAR
mov w2, (GRID_ROWS * GRID_COLS)
bl memset
ldp fp, lr, [sp], #16
ret


.data
.balign 4
pi: .float 3.141593
.balign 8
filename: .asciz "./image.txt"
file_mode: .asciz "r"
reset_code: .asciz "\033[1;1H\033[2J"
draw_code: .asciz "\033[%d;%dH%c"
err_msg: .asciz "Status"

.end
