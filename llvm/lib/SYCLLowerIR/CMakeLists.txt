if(${CMAKE_VERSION} VERSION_LESS 3.14)
    macro(FetchContent_MakeAvailable NAME)
        FetchContent_GetProperties(${NAME})
        if(NOT ${NAME}_POPULATED)
            FetchContent_Populate(${NAME})
            add_subdirectory(${${NAME}_SOURCE_DIR} ${${NAME}_BINARY_DIR})
        endif()
    endmacro()
endif()

# Lowering of SYCL ESIMD kernels depends on vc-intrinsics
# NOTE: could have been added earlier from llvm/projects
if (NOT TARGET LLVMGenXIntrinsics)
  if (NOT DEFINED LLVMGenXIntrinsics_SOURCE_DIR)
    set(LLVMGenXIntrinsics_GIT_REPO https://github.com/intel/vc-intrinsics.git)
    # Author: "Victor Mustya" <victor.mustya@intel.com>
    # Date: Mon, 15 May 2023 23:44:14 +0000
    # Mark new lsc_load_merge intrinsics as LSC ones
    set(LLVMGenXIntrinsics_GIT_TAG fe92a377338258b725cfbd0a1bd49a9cf5e2864c)

    message(STATUS "vc-intrinsics repo is missing. Will try to download it from ${LLVMGenXIntrinsics_GIT_REPO}")
    include(FetchContent)
    FetchContent_Declare(vc-intrinsics
      GIT_REPOSITORY ${LLVMGenXIntrinsics_GIT_REPO}
      GIT_TAG        ${LLVMGenXIntrinsics_GIT_TAG}
    )
    FetchContent_MakeAvailable(vc-intrinsics)
    FetchContent_GetProperties(vc-intrinsics)

    set(LLVMGenXIntrinsics_SOURCE_DIR ${vc-intrinsics_SOURCE_DIR})
    set(LLVMGenXIntrinsics_BINARY_DIR ${vc-intrinsics_BINARY_DIR})
  else (NOT DEFINED LLVMGenXIntrinsics_SOURCE_DIR)
    # -DLLVMGenXIntrinsics_SOURCE_DIR is provided
    message(STATUS "vc-intrinsics are added manually ${LLVMGenXIntrinsics_SOURCE_DIR}")

    set(LLVMGenXIntrinsics_BINARY_DIR ${CMAKE_BINARY_DIR}/vc-intrinsics-build)
    add_subdirectory(${LLVMGenXIntrinsics_SOURCE_DIR} ${LLVMGenXIntrinsics_BINARY_DIR})
  endif (NOT DEFINED LLVMGenXIntrinsics_SOURCE_DIR)

  target_include_directories(LLVMGenXIntrinsics
    PUBLIC $<BUILD_INTERFACE:${LLVMGenXIntrinsics_SOURCE_DIR}/GenXIntrinsics/include>
    PUBLIC $<BUILD_INTERFACE:${LLVMGenXIntrinsics_BINARY_DIR}/GenXIntrinsics/include>
  )
endif (NOT TARGET LLVMGenXIntrinsics)

set_property(GLOBAL PROPERTY LLVMGenXIntrinsics_SOURCE_PROP ${LLVMGenXIntrinsics_SOURCE_DIR})
set_property(GLOBAL PROPERTY LLVMGenXIntrinsics_BINARY_PROP ${LLVMGenXIntrinsics_BINARY_DIR})

add_llvm_component_library(LLVMSYCLLowerIR
  ESIMD/ESIMDOptimizeVecArgCallConv.cpp
  ESIMD/ESIMDUtils.cpp
  ESIMD/ESIMDVerifier.cpp
  ESIMD/LowerESIMD.cpp
  ESIMD/LowerESIMDKernelAttrs.cpp
  CompileTimePropertiesPass.cpp
  DeviceGlobals.cpp
  ESIMD/LowerESIMDVecArg.cpp
  ESIMD/LowerESIMDVLoadVStore.cpp
  ESIMD/LowerESIMDSlmReservation.cpp
  HostPipes.cpp
  LowerInvokeSimd.cpp
  LowerKernelProps.cpp
  LowerWGLocalMemory.cpp
  LowerWGScope.cpp
  MutatePrintfAddrspace.cpp
  SYCLAddOptLevelAttribute.cpp
  SYCLPropagateAspectsUsage.cpp
  SYCLUtils.cpp

  LocalAccessorToSharedMemory.cpp
  GlobalOffset.cpp
  TargetHelpers.cpp

  ADDITIONAL_HEADER_DIRS
  ${LLVM_MAIN_INCLUDE_DIR}/llvm/SYCLLowerIR
  ${LLVM_MAIN_SRC_DIR}/projects/vc-intrinsics/GenXIntrinsics/include
  ${LLVM_BINARY_DIR}/projects/vc-intrinsics/GenXIntrinsics/include

  DEPENDS
  intrinsics_gen
  LLVMGenXIntrinsics
  LLVMDemangle
  LLVMTransformUtils

  LINK_LIBS
  LLVMGenXIntrinsics
  LLVMDemangle
  LLVMTargetParser
  LLVMTransformUtils
  
  LINK_COMPONENTS
  Analysis
  Core
  Support
  )

target_include_directories(LLVMSYCLLowerIR
  PRIVATE ${LLVM_MAIN_SRC_DIR}/projects/vc-intrinsics/GenXIntrinsics/include
  PRIVATE ${LLVM_BINARY_DIR}/projects/vc-intrinsics/GenXIntrinsics/include)
