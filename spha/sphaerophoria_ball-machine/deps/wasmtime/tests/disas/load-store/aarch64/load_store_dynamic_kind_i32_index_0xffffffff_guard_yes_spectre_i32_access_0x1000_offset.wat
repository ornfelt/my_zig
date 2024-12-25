;;! target = "aarch64"
;;! test = "compile"
;;! flags = " -C cranelift-enable-heap-access-spectre-mitigation -O static-memory-maximum-size=0 -O static-memory-guard-size=4294967295 -O dynamic-memory-guard-size=4294967295"

;; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;; !!! GENERATED BY 'make-load-store-tests.sh' DO NOT EDIT !!!
;; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

(module
  (memory i32 1)

  (func (export "do_store") (param i32 i32)
    local.get 0
    local.get 1
    i32.store offset=0x1000)

  (func (export "do_load") (param i32) (result i32)
    local.get 0
    i32.load offset=0x1000))

;; wasm[0]::function[0]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       ldr     x10, [x0, #0x68]
;;       ldr     x13, [x0, #0x60]
;;       mov     w11, w2
;;       mov     x12, #0
;;       add     x13, x13, w2, uxtw
;;       add     x13, x13, #1, lsl #12
;;       cmp     x11, x10
;;       csel    x11, x12, x13, hi
;;       csdb
;;       str     w3, [x11]
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[1]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       ldr     x10, [x0, #0x68]
;;       ldr     x13, [x0, #0x60]
;;       mov     w11, w2
;;       mov     x12, #0
;;       add     x13, x13, w2, uxtw
;;       add     x13, x13, #1, lsl #12
;;       cmp     x11, x10
;;       csel    x11, x12, x13, hi
;;       csdb
;;       ldr     w0, [x11]
;;       ldp     x29, x30, [sp], #0x10
;;       ret
