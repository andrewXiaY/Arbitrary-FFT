#include "utils.cuh"
#include <stdio.h>
// self defined complex exponential cuda
__device__ cuDoubleComplex cuda_complex_exp (cuDoubleComplex arg){
    double s, c;
    double e = exp(cuCreal(arg));
    sincos(cuCimag(arg), &s, &c);
    return make_cuDoubleComplex(c * e, s * e);
}

/*
  Following kernels are used for NaiveDFT cuda
*/
// check if there is an error happened in gpu
void Check_CUDA_Error(const char *message){
    cudaError_t error = cudaGetLastError();
    if(error!=cudaSuccess) {
        fprintf(stderr,"ERROR: %s: %s\n", message, cudaGetErrorString(error) );
        exit(-1);
    }
}

// gpu dft kernel using 2d grid
__global__ void dft_kernel2d(cuDoubleComplex* X, cuDoubleComplex* Y, const std::size_t N, std::size_t col_size){
  __shared__ cuDoubleComplex cache[BLOCKSIZE];
  
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;

  if(idx < N && idy < N){
    cuDoubleComplex tmp = cuda_complex_exp(make_cuDoubleComplex(0, -_2Pi / (Real) N * (Real) idx * (Real) idy));
    cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCmul(tmp, X[idy]); 
  }else{
    cache[threadIdx.x * blockDim.y + threadIdx.y] = make_cuDoubleComplex(0.0, 0.0);
  }
  __syncthreads();

  if(idx < N && idy < N){
    // perform reduction in block
    for (unsigned int s = blockDim.y/2; s>0; s>>=1) {
        if (threadIdx.y < s) {
            cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCadd(cache[threadIdx.x * blockDim.y + threadIdx.y], cache[threadIdx.x * blockDim.y + threadIdx.y + s]);
        }
        __syncthreads();
    }

    if(threadIdx.y == 0)
      Y[idx*col_size + blockIdx.y] = cache[threadIdx.x * blockDim.y];
  }
}

__global__ void idft_kernel2d(cuDoubleComplex* X, cuDoubleComplex* Y, const std::size_t N, std::size_t col_size){
  __shared__ cuDoubleComplex cache[BLOCKSIZE];
  
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;

  if(idx < N && idy < N){
    cuDoubleComplex tmp = cuda_complex_exp(make_cuDoubleComplex(0, _2Pi / (Real) N * (Real) idx * (Real) idy));
    cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCmul(tmp, X[idy]); 
  }else{
    cache[threadIdx.x * blockDim.y + threadIdx.y] = make_cuDoubleComplex(0.0, 0.0);
  }
  __syncthreads();

  if(idx < N && idy < N){
    // perform reduction in block
    for (unsigned int s = blockDim.y/2; s>0; s>>=1) {
        if (threadIdx.y < s) {
            cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCadd(cache[threadIdx.x * blockDim.y + threadIdx.y], cache[threadIdx.x * blockDim.y + threadIdx.y + s]);
        }
        __syncthreads();
    }

    if(threadIdx.y == 0)
      Y[idx*col_size + blockIdx.y] = cache[threadIdx.x * blockDim.y];
  }

}

// perform reduction on row of a 2d matrix
__global__ void reduction_2d(cuDoubleComplex* Y, std::size_t N, std::size_t col_size){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  cuDoubleComplex tmp = make_cuDoubleComplex(0.0, 0.0);
  if(idx < N){
    for(int i = 0; i < col_size; ++i){
      tmp = cuCadd(tmp, Y[idx*col_size + i]);
    }
    Y[idx*col_size] = tmp;
  }
}
/* ======================================================================================================= */


/*
  Following kernels are used to fft
*/
// kernel for initialize w in ditfft algorithm
__global__ void init_w_kernel(cuDoubleComplex* W, const double w, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  if(idx < N){
      W[idx] = cuda_complex_exp(make_cuDoubleComplex(0.0, w * idx));
  }
}

__global__ void init_C_kernel(cuDoubleComplex* C, const double w, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  if(idx < N){
      C[idx] = cuda_complex_exp(make_cuDoubleComplex(0.0, w * idx * idx));
  }
}

__global__ void bitrev_kernel(cuDoubleComplex* Y, const cuDoubleComplex* X, std::size_t* I, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  if(idx < N)
      Y[idx] = X[I[idx]];
}

__global__ void ditfft_kernel(cuDoubleComplex* Y, cuDoubleComplex* W, std::size_t iter, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;

  auto g = N >> (iter + 1);
  auto h = size_t{1} << iter;
  auto j = 2*h*idx;
  auto k = idy;

  // for consistence
  if(j < N && k < h){
      auto u = Y[j + k];
      auto v = cuCmul(cuConj(W[k * g]), Y[j + k + h]);
      Y[j + k] = cuCadd(u, v);
      Y[j + k + h] = cuCsub(u, v);
  }
}

__global__ void ditdiffft_kernel(cuDoubleComplex* Y, cuDoubleComplex* W, std::size_t iter, std::size_t N){

  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;
  
  auto g = N >> (iter + 1);
  auto h = size_t{1} << iter;
  auto j = 2*h*idx;
  auto k = idy;

  // for consistence
  if(j < N && k < h){
      auto u = Y[j + k];
      auto v = Y[j + k + h];
      Y[j + k] = cuCadd(u, v);
      Y[j + k + h] = cuCmul(cuConj(W[k * g]), cuCsub(u, v));
  }

}

__global__ void ditdifidft_kernel(cuDoubleComplex* Y, cuDoubleComplex* W, std::size_t iter, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;

  auto g = N >> (iter + 1);
  auto h = size_t{1} << iter;
  auto j = 2*h*idx;
  auto k = idy;

  // for consistence
  if(j < N && k < h){
    auto u = Y[j + k];
    auto v = cuCmul(W[k * g], Y[j + k + h]);
    Y[j + k] = cuCadd(u, v) ;
    Y[j + k + h] = cuCsub(u, v);
  }
}


__global__ void complex_vec_mul_kernel(cuDoubleComplex* A, cuDoubleComplex* B, cuDoubleComplex* C, std::size_t N, std::size_t col_size){
  __shared__ cuDoubleComplex cache[BLOCKSIZE];
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  std::size_t idy = threadIdx.y + blockIdx.y*blockDim.y;
  
  if(idx < N && idy < N){
    cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCmul(A[idx], B[idy]);
  }else{
    cache[threadIdx.x * blockDim.y + threadIdx.y] = make_cuDoubleComplex(0.0, 0.0);
  }
  
  __syncthreads();
  
  if(idx < N && idy < N){
    for (unsigned int s = blockDim.y/2; s > 0; s >>= 1) {
      if (threadIdx.y < s) {
          cache[threadIdx.x * blockDim.y + threadIdx.y] = cuCadd(cache[threadIdx.x * blockDim.y + threadIdx.y], cache[threadIdx.x * blockDim.y + threadIdx.y + s]);
      }
      __syncthreads();
    }
  }

  if(threadIdx.y == 0){
    C[idx*col_size + blockIdx.y] = cache[threadIdx.x * blockDim.y];
  }
}

__global__ void complex_mul_conj_kernel(cuDoubleComplex* A, cuDoubleComplex* X, cuDoubleComplex* C, std::size_t N, std::size_t Nl){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;

  if(idx < N){
    A[idx] = cuCmul(X[idx], cuConj(C[idx]));
  }else if(idx < Nl){
    A[idx] = {};
  }

}

__global__ void complex_mul_kernel(cuDoubleComplex* A, cuDoubleComplex* X, cuDoubleComplex* C, std::size_t N, std::size_t Nl){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;

  if(idx < N){
    A[idx] = cuCmul(X[idx], C[idx]);
  }else if(idx < Nl){
    A[idx] = {};
  }

}

__global__ void complex_self_mul_kernel(cuDoubleComplex* A, cuDoubleComplex* B, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;

  if(idx < N){
    A[idx] = cuCmul(A[idx], B[idx]);
  }

}

__global__ void complex_self_conj_mul_kernel(cuDoubleComplex* A, cuDoubleComplex* B, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;

  if(idx < N){
    A[idx] = cuCmul(A[idx], cuConj(B[idx]));
  }

}

__global__ void complex_div_real(cuDoubleComplex* Y, std::size_t N){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  
  if(idx < N){
    Y[idx] = cuCdiv(Y[idx], make_cuDoubleComplex(N, 0.0));
  }
}

__global__ void complex_div_real_mul(cuDoubleComplex* A, cuDoubleComplex* Y, cuDoubleComplex* C, std::size_t N, std::size_t Nl){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  
  if(idx < N){
    A[idx] = cuCdiv(A[idx], make_cuDoubleComplex(N, 0.0));
  }

  __syncthreads();
  if(idx < Nl){
    Y[idx] = cuCdiv(cuCmul(A[idx], C[idx]) , make_cuDoubleComplex(Nl, 0.));
  }
}

__global__ void complex_div_real_mul_conj(cuDoubleComplex* A, cuDoubleComplex* Y, cuDoubleComplex* C, std::size_t N, std::size_t Nl){
  std::size_t idx = threadIdx.x + blockIdx.x*blockDim.x;
  
  if(idx < N){
    A[idx] = cuCdiv(A[idx], make_cuDoubleComplex(N, 0.0));
  }

  __syncthreads();
  if(idx < Nl){
    Y[idx] = cuCmul(A[idx], cuConj(C[idx]));
  }
}

// Self defined atomicAdd
__device__ double atomicAdd2(double* address, double val){
  unsigned long long int* address_as_ull =
          (unsigned long long int*)address;
  unsigned long long int old = *address_as_ull, assumed;

  do {
      assumed = old;
      old = atomicCAS(address_as_ull, assumed,
                      __double_as_longlong(val + __longlong_as_double(assumed)));

      // Note: uses integer comparison to avoid hang in case of NaN (since NaN != NaN)
  } while (assumed != old);

  return __longlong_as_double(old);
}
