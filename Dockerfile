FROM ubuntu:24.04

ENV EMSDK_VER=3.1.0
ENV MAME_VER=mame0239

RUN apt update \
    && apt -y install git build-essential python3 libsdl2-dev libsdl2-ttf-dev \
       libfontconfig-dev libpulse-dev qtbase5-dev qtbase5-dev-tools qtchooser qt5-qmake vim 

RUN git clone https://github.com/mamedev/mame --depth 1 --branch $MAME_VER

RUN git clone https://github.com/emscripten-core/emsdk.git \
    && cd emsdk \
    && ./emsdk install $EMSDK_VER \
    && ./emsdk activate $EMSDK_VER 

ADD Makefile.docker /Makefile
WORKDIR /

RUN mkdir -p /output 
