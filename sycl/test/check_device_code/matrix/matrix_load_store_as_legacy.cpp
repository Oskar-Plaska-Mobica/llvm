// RUN: %clangxx -fsycl-device-only -S -emit-llvm -o - %s | FileCheck %s

// check that correct address spaces are used to load from and store to
#define SYCL_EXT_ONEAPI_MATRIX_VERSION 1
#include <sycl/sycl.hpp>

using namespace sycl;
using namespace sycl::ext::oneapi::experimental::matrix;

int main(void) {
  queue q;
  unsigned short *A = malloc_shared<unsigned short>(8 * 16, q);
  unsigned short *B = malloc_shared<unsigned short>(16 * 16, q);
  float *C = malloc_shared<float>(8 * 16, q);

  auto pA = multi_ptr<unsigned short, access::address_space::global_space>(A);
  auto pB = multi_ptr<unsigned short, access::address_space::global_space>(B);
  auto pC = multi_ptr<float, access::address_space::global_space>(C);

  q.submit([&](handler &h) {
    local_accessor<unsigned short, 2> tileA{{8, 16}, h};

    h.parallel_for(
        nd_range<2>({1, 16}, {1, 16}),
        [=](nd_item<2> it) [[intel::reqd_sub_group_size(16)]] {
          sub_group sg = it.get_sub_group();

          joint_matrix<unsigned short, 8, 16> tA(sg);
          joint_matrix<unsigned short, 16, 16, matrix_layout::packed_b> tB(sg);
          joint_matrix<float, 8, 16> tC(sg);

          vec<unsigned short, 8> slmvec = sg.load<8>(pA);
          sg.store<8>(
              tileA.template get_multi_ptr<sycl::access::decorated::yes>(),
              slmvec);
          it.barrier(access::fence_space::local_space);

          // A should load from local address space
          // CHECK: %{{.*}} = tail call spir_func noundef %spirv.JointMatrixINTEL._short_8_16_0_3 addrspace(4)* @_Z[[#]]__spirv_JointMatrixLoadINTEL{{.*}}(i16 addrspace(3)* noundef %{{.*}}, i64 noundef 16, i32 noundef 0, i32 noundef 3, i32 noundef 0) #{{.*}}
          joint_matrix_load(
              sg, tA,
              tileA.template get_multi_ptr<sycl::access::decorated::yes>(), 16,
              matrix_layout::row_major);
          // B should load from global address space
          // CHECK: %{{.*}} = tail call spir_func noundef %spirv.JointMatrixINTEL._short_16_16_3_3 addrspace(4)* @_Z[[#]]__spirv_JointMatrixLoadINTEL{{.*}}(i16 addrspace(1)* noundef %{{.*}}, i64 noundef 32, i32 noundef [[#]], i32 noundef 3, i32 noundef 0) #{{.*}}
          joint_matrix_load(sg, tB, pB, 32, matrix_layout::packed_b);
          tC = joint_matrix_mad(sg, tA, tB, tC);
          // C should store to global address space
          // CHECK: tail call spir_func void @_Z[[#]]__spirv_JointMatrixStoreINTEL{{.*}}(float addrspace(1)* noundef %{{.*}}, %spirv.JointMatrixINTEL._float_8_16_0_3 addrspace(4)* noundef %{{.*}}, i64 noundef 16, i32 noundef 0, i32 noundef 3, i32 noundef 0) #{{.*}}
          joint_matrix_store(sg, tC, pC, 16, matrix_layout::row_major);
        });
  });

  free(A, q);
  free(B, q);
  free(C, q);

  return 0;
}
