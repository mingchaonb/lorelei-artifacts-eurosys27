# Reproducible build and evaluation environment for the EuroSys 2027 artifact.
# The image must be built and run on a physical ARM64 Ubuntu 24.04 host.
FROM ubuntu:24.04

ARG USE_USTC_MIRROR=0
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/user

SHELL ["/bin/bash", "-lc"]

# Keep the official Ubuntu sources by default. Evaluators in mainland China can
# select the USTC mirror with --build-arg USE_USTC_MIRROR=1.
RUN case "${USE_USTC_MIRROR}" in \
        0) ;; \
        1) sed -i -E \
            's@https?://(archive|security)\.ubuntu\.com/ubuntu@http://mirrors.ustc.edu.cn/ubuntu@g; s@https?://ports\.ubuntu\.com/ubuntu-ports@http://mirrors.ustc.edu.cn/ubuntu-ports@g' \
            /etc/apt/sources.list.d/ubuntu.sources ;; \
        *) echo "USE_USTC_MIRROR must be 0 or 1" >&2; exit 2 ;; \
    esac \
    && echo 'Acquire::Retries "5";' >/etc/apt/apt.conf.d/80-retries \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo ca-certificates git curl wget file patch patchelf ripgrep \
        build-essential autoconf autoconf-archive automake bear bison cmake flex libtool m4 \
        meson ninja-build nasm yasm pkg-config \
        xz-utils zip unzip tar squashfs-tools time xxd \
        python3 python3-pip python3-venv python3-numpy python3-matplotlib python3-tomli \
        gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
        clang-20 llvm-20-dev libclang-20-dev \
        libglib2.0-dev libdw-dev libelf-dev libcapstone-dev libfdt-dev \
        libpixman-1-dev libslirp-dev libffi-dev libffcall-dev libssl-dev \
        libvulkan1 libvulkan-dev mesa-vulkan-drivers \
        libgl1 libglx0 libgl-dev libglx-dev libx11-dev \
        yt-dlp mangohud xauth xvfb x11-xserver-utils x11-utils xdotool \
    && rm -rf /var/lib/apt/lists/*

# Match the host account so bind-mounted sources and generated evidence keep
# their normal ownership. The Ubuntu base image may reserve UID/GID 1000 for an
# ubuntu account, which is removed before creating the evaluator account.
RUN [[ "${USER_UID}" =~ ^[0-9]+$ && "${USER_GID}" =~ ^[0-9]+$ ]] \
    && if id ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && if getent group ubuntu >/dev/null 2>&1; then groupdel ubuntu; fi \
    && groupadd --gid "${USER_GID}" user \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" \
        --create-home --shell /bin/bash user \
    && printf 'user ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/user \
    && chmod 0440 /etc/sudoers.d/user

USER user
WORKDIR /home/user/eurosys-lorelei-artifacts

CMD ["/bin/bash"]
