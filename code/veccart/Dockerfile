FROM ubuntu:18.04
LABEL Description="A clone of the i2c-tiny-usb based upon STM32 and libopencm3"          

RUN DEBIAN_FRONTEND=noninteractive apt-get update -y -q \
    && apt-get install -y -q sudo make python git-core \
    && apt-get install -y -q software-properties-common \
    && add-apt-repository ppa:team-gcc-arm-embedded/ppa \
    && apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y gcc-arm-embedded

WORKDIR /build
RUN git clone https://github.com/libopencm3/libopencm3.git \
    && cd libopencm3 \
#    && git checkout 9b8d44e8a3cc52d83aba3b5547c2bb56cdbd8b63 \
    && make

WORKDIR /build/veccart
