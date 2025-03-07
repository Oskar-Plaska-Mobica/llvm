; REQUIRES: x86-registered-target

; Test CFI devirtualization through the thin link and backend when
; a type id is Unsat (not used on any global's type metadata).
;
; In this test case, the first module is split and will import a resolution
; for its type test. The resolution would be exported by the second
; module, which is set up so that it does not get split (treated as regular
; LTO because it does not have any external globals from which to create
; a unique module ID). We should not actually get any resolution for the
; type id in this case, since no globals include it in their type metadata,
; so the resolution is Unsat and the type.checked.load instructions are
; converted to type tests that evaluate to false.

; RUN: opt -thinlto-bc -thinlto-split-lto-unit -o %t.o %s
; RUN: opt -thinlto-bc -thinlto-split-lto-unit -o %t1.o %p/Inputs/cfi-unsat.ll

; RUN: llvm-lto2 run -opaque-pointers %t.o %t1.o -save-temps -pass-remarks=. \
; RUN:   -opaque-pointers \
; RUN:   -whole-program-visibility \
; RUN:   -o %t3 \
; RUN:   -r=%t.o,test2,px \
; RUN:   -r=%t1.o,_ZTV1B,px \
; RUN:   -r=%t1.o,test,px \
; RUN:   -r=%t1.o,testb,px
; RUN: llvm-dis %t3.index.bc -o - | FileCheck %s --check-prefix=INDEX
; RUN: llvm-dis %t3.0.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR0
; RUN: llvm-dis %t3.1.4.opt.bc -o - | FileCheck %s --check-prefix=CHECK-IR1

; INDEX-NOT: "typeid:"

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-grtev4-linux-gnu"

%struct.A = type { ptr }

$test2 = comdat any

define linkonce_odr i32 @test2(ptr %obj, i32 %a) comdat {
entry:
  %vtable5 = load ptr, ptr %obj

  %0 = tail call { ptr, i1 } @llvm.type.checked.load(ptr %vtable5, i32 8, metadata !"_ZTS1A")
  %1 = extractvalue { ptr, i1 } %0, 1
  br i1 %1, label %cont, label %trap

trap:
  tail call void @llvm.trap()
  unreachable

cont:
  %2 = extractvalue { ptr, i1 } %0, 0

  %call = tail call i32 %2(ptr nonnull %obj, i32 %a)

  ret i32 %call
}

; CHECK-IR0: define weak_odr i32 @test
; CHECK-IR0-NEXT: entry:
; CHECK-IR0-NEXT: %vtable5 =
; CHECK-IR0-NEXT: tail call void @llvm.trap()
; CHECK-IR0-NEXT: unreachable
; CHECK-IR0-NEXT: }
; CHECK-IR0: define weak_odr i32 @testb
; CHECK-IR0-NEXT: entry:
; CHECK-IR0-NEXT: %vtable5 =
; CHECK-IR0-NEXT: tail call void @llvm.trap()
; CHECK-IR0-NEXT: unreachable
; CHECK-IR0-NEXT: }

; CHECK-IR1: define weak_odr i32 @test2
; CHECK-IR1-NEXT:   entry:
; CHECK-IR1-NEXT:     tail call void @llvm.trap()
; CHECK-IR1-NEXT:     unreachable
; CHECK-IR1-NEXT:   }

declare { ptr, i1 } @llvm.type.checked.load(ptr, i32, metadata)
declare void @llvm.trap()
