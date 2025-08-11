FROM ubuntu:24.04

ENV EMSDK_VER=3.1.0
ENV MAME_VER=mame0239

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive \
       apt -y install git build-essential python3 libsdl2-dev libsdl2-ttf-dev \
       libfontconfig-dev libpulse-dev qtbase5-dev qtbase5-dev-tools qtchooser qt5-qmake \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# Build up latest copy of mame for -xmllist function
RUN git clone https://github.com/mamedev/mame --depth 1 \
    && make -C /mame -j $(nproc) OPTIMIZE=3 NOWERROR=1 TOOLS=0 REGENIE=1 \
    && install /mame/mame /usr/local/bin \
    && rm -rf /mame 

#Setup to build WEBASSEMBLY versions 
RUN git clone  https://github.com/mamedev/mame --depth 1 --branch $MAME_VER \
    && git clone https://github.com/emscripten-core/emsdk.git \
    && cd emsdk \
    && ./emsdk install $EMSDK_VER \
    && ./emsdk activate $EMSDK_VER 

ADD Makefile.docker /Makefile

WORKDIR /

RUN mkdir -p /output 
