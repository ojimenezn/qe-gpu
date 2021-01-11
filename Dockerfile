# Use PGI as base image
FROM nvcr.io/hpc/pgi-compilers:ce as builder
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Make sure we have CUDA toolkit 
RUN apt-key adv --fetch-keys  http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub
RUN bash -c 'echo "deb http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list'

# Install misc other things
RUN apt-get update -y && \
     apt-get install -y --no-install-recommends make rsync openssh-server git wget libfftw3-mpi3 libfftw3-mpi-dev libnvidia-compute-440 makedepf90 

RUN apt-get update && apt-get install -y --no-install-recommends \
    cuda-nvml-dev-10-2 \
    cuda-command-line-tools-10-2 \
    cuda-nvprof-10-2 \
    cuda-npp-dev-10-2 \
    cuda-libraries-dev-10-2 \
    cuda-minimal-build-10-2 \
    libcublas-dev=10.2.2.89-1 \
    libnccl-dev \
    cuda-toolkit-10-2 \
    cuda-tools-10-2    

### Install qd into /opt/pgi ###
WORKDIR /opt
RUN git clone https://github.com/scibuilder/QD.git qd-2.3.17
WORKDIR /opt/qd-2.3.17
RUN ./configure --prefix=/opt/pgi/qd-2.3.17/install/
RUN make -j64
RUN make install

### Install fftw and compile. Another option is use default ones from ubuntu libfftw3-mpi ###
WORKDIR /opt/pgi
RUN wget http://www.fftw.org/fftw-3.3.8.tar.gz
RUN tar xf fftw-3.3.8.tar.gz
WORKDIR /opt/pgi/fftw-3.3.8
RUN CPP=/usr/bin/cpp CC=pgcc  CXX=pgc++ F77=pgfortran CFLAGS="-Minfo -fPIC"  FFLAGS="-Minfo" \
./configure   
RUN make -j64
RUN make install

# Environment Variables (setting CUDA_HOME to the path of the CUDA installation)
ENV CUDA_HOME = /usr/local/cuda
ENV PATH = ${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH = ${CUDA_HOME}/lib64:$LD_LIBRARY_PATH

# Get QE-GPU source code from GitLab and compile make -j8 in parallel
WORKDIR /opt/pgi
RUN wget --quiet https://gitlab.com/QEF/q-e-gpu/-/archive/qe-gpu-6.5a2/q-e-gpu-qe-gpu-6.5a2.tar.bz2 \
   && tar xjf q-e-gpu-qe-gpu-6.5a2.tar.bz2 \
   && cd q-e-gpu-qe-gpu-6.5a2 \
   && CPP=/usr/bin/cpp CC=pgcc  CXX=pgc++ F77=pgfortran CFLAGS="-Minfo -fPIC"  FFLAGS="-Minfo" \
   ./configure --build=x86_64-linux-gnu  --host=x86_64-linux-gnu \
   --with-cuda=${CUDA_HOME} --with-cuda-runtime=10.2 --with-cuda-cc=70 \
   --enable-openmp --enable-shared [ --with-scalapack=no ] \
   && make -j8 pw \
   && make install

#WORKDIR /
#COPY qe-gpu-1.0 .
#COPY make.inc_x86-64 .
#WORKDIR qe-gpu-1.0
#RUN make -j8
#RUN make install 