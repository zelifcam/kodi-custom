FROM archlinux@sha256:d1f8276aa44cadeb2e24ddc4cb0d1652adbfa2b1e3666b605d7836b319152d39

# Pin packages to a known-good date for reproducible builds
# Change this date to update all dependencies at once
ARG ARCHIVE_DATE=2026/03/01
RUN echo "Server = https://archive.archlinux.org/repos/${ARCHIVE_DATE}/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

RUN pacman -Syu --noconfirm && pacman -S --noconfirm --needed \
    base-devel git cmake wget \
    curl dav1d fmt libass libbluray libcdio libcec \
    libdrm libmicrohttpd libnfs libpulse libva libvdpau \
    libxkbcommon libinput libdisplay-info lirc lzo \
    mariadb-libs mesa pipewire python smbclient sndio \
    spdlog sqlite taglib tinyxml tinyxml2 exiv2 \
    giflib pcre \
    python-pycryptodomex python-pillow python-simplejson python-setuptools \
    nlohmann-json rapidjson \
    nasm swig gperf gtest meson ghostscript graphviz \
    jre17-openjdk-headless \
    && pacman -Scc --noconfirm

# Strip problematic flags from makepkg.conf:
# - pack-relative-relocs: bfd doesn't support it
# - flto: FFmpeg NASM + LTO + shared lib = broken R_X86_64_PC32 relocations
#         and gold's lto-wrapper segfaults with GCC 15
# Force bfd linker
RUN sed -i \
    -e 's/-Wl,-z,pack-relative-relocs//g' \
    -e 's/-flto=auto//g' \
    -e 's/ -flto//g' \
    /etc/makepkg.conf && \
    echo 'LDFLAGS="$LDFLAGS -fuse-ld=bfd"' >> /etc/makepkg.conf

# makepkg refuses to run as root
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Build shairplay from AUR (optional runtime dep, not in official repos)
USER builder
RUN cd /tmp && \
    git clone https://aur.archlinux.org/shairplay.git && \
    cd shairplay && makepkg -si --noconfirm && \
    cd /tmp && rm -rf shairplay

# cmake 3.x — system cmake 4.x breaks Kodi's build scripts
USER root
ARG CMAKE3_VER=3.31.6
RUN mkdir -p /opt/cmake3 && \
    wget -qO- "https://github.com/Kitware/CMake/releases/download/v${CMAKE3_VER}/cmake-${CMAKE3_VER}-linux-x86_64.tar.gz" \
    | tar --strip-components=1 -xz -C /opt/cmake3

RUN mkdir -p /build && chown builder:builder /build

# Kodi expects mariadb/mysql.h but Arch puts it at mysql/mysql.h
RUN ln -s /usr/include/mysql /usr/include/mariadb

WORKDIR /build
USER builder

ENTRYPOINT ["/bin/bash"]
