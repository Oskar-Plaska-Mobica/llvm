// UNSUPPORTED: cuda || hip
// UNSUPPORTED: ze_debug
// REQUIRES: gpu,linux
// RUN: %{build} -o %t.out
// RUN: %{run} %t.out

#include "../include/asmhelper.h"
#include <sycl/sycl.hpp>

struct KernelFunctor {
  KernelFunctor() {}

  void operator()(sycl::handler &cgh) {
    cgh.parallel_for<KernelFunctor>(
        sycl::range<1>{16},
        [=](sycl::id<1> wiID) [[intel::reqd_sub_group_size(16)]] {
#if defined(__SYCL_DEVICE_ONLY__)
          asm volatile(".decl tmp1 v_type=G type=d num_elts=16 align=GRF\n"
                       ".decl tmp2 v_type=G type=d num_elts=16 align=GRF\n"
                       "check_label0:\ncheck_label0:\n");
#endif
        });
  }
};

int main() {
  KernelFunctor f;
  launchInlineASMTest(f, /* sg size */ true, /* exception expected */ true);
  return 0;
}
