// RUN: mlir-opt %s -canonicalize="test-convergence" -split-input-file | FileCheck %s

func.func @testenterdataop(%a: memref<10xf32>) -> () {
  %ifCond = arith.constant true
  acc.enter_data if(%ifCond) create(%a: memref<10xf32>)
  return
}

// CHECK: acc.enter_data create(%{{.*}} : memref<10xf32>)

// -----

func.func @testenterdataop(%a: memref<10xf32>) -> () {
  %ifCond = arith.constant false
  acc.enter_data if(%ifCond) create(%a: memref<10xf32>)
  return
}

// CHECK: func @testenterdataop
// CHECK-NOT: acc.enter_data

// -----

func.func @testexitdataop(%a: memref<10xf32>) -> () {
  %ifCond = arith.constant true
  acc.exit_data if(%ifCond) delete(%a: memref<10xf32>)
  return
}

// CHECK: acc.exit_data delete(%{{.*}} : memref<10xf32>)

// -----

func.func @testexitdataop(%a: memref<10xf32>) -> () {
  %ifCond = arith.constant false
  acc.exit_data if(%ifCond) delete(%a: memref<10xf32>)
  return
}

// CHECK: func @testexitdataop
// CHECK-NOT: acc.exit_data

// -----

func.func @testupdateop(%a: memref<f32>) -> () {
  %0 = acc.getdeviceptr varPtr(%a : memref<f32>) -> memref<f32>
  acc.update_host accPtr(%0 : memref<f32>) to varPtr(%a : memref<f32>)
  %ifCond = arith.constant true
  acc.update if(%ifCond) dataOperands(%0: memref<f32>)
  return
}

// CHECK: acc.update dataOperands(%{{.*}} : memref<f32>)

// -----

func.func @testupdateop(%a: memref<f32>) -> () {
  %0 = acc.getdeviceptr varPtr(%a : memref<f32>) -> memref<f32>
  acc.update_host accPtr(%0 : memref<f32>) to varPtr(%a : memref<f32>)
  %ifCond = arith.constant false
  acc.update if(%ifCond) dataOperands(%0: memref<f32>)
  return
}

// CHECK: func @testupdateop
// CHECK-NOT: acc.update{{.$}}

// -----

func.func @testenterdataop(%a: memref<10xf32>, %ifCond: i1) -> () {
  acc.enter_data if(%ifCond) create(%a: memref<10xf32>)
  return
}

// CHECK:  func @testenterdataop(%{{.*}}: memref<10xf32>, [[IFCOND:%.*]]: i1)
// CHECK:    acc.enter_data if(%{{.*}}) create(%{{.*}} : memref<10xf32>)

// -----

func.func @testexitdataop(%a: memref<10xf32>, %ifCond: i1) -> () {
  acc.exit_data if(%ifCond) delete(%a: memref<10xf32>)
  return
}

// CHECK: func @testexitdataop(%{{.*}}: memref<10xf32>, [[IFCOND:%.*]]: i1)
// CHECK:   acc.exit_data if(%{{.*}}) delete(%{{.*}} : memref<10xf32>)

// -----

func.func @testupdateop(%a: memref<f32>, %ifCond: i1) -> () {
  %0 = acc.getdeviceptr varPtr(%a : memref<f32>) -> memref<f32>
  acc.update_host accPtr(%0 : memref<f32>) to varPtr(%a : memref<f32>)
  acc.update if(%ifCond) dataOperands(%0: memref<f32>)
  return
}

// CHECK:  func @testupdateop(%{{.*}}: memref<f32>, [[IFCOND:%.*]]: i1)
// CHECK:    acc.update if(%{{.*}}) dataOperands(%{{.*}} : memref<f32>)
