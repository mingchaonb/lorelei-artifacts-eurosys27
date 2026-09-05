# Reproducible build and evaluation environment for the EuroSys 2027 artifact.
# Build on the physical Linux host used for the evaluation.
FROM ubuntu:24.04

ARG USE_USTC_MIRROR=0
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/user
ENV USE_USTC_MIRROR=${USE_USTC_MIRROR}

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
        python3-packaging \
        clang-20 llvm-20-dev libclang-20-dev \
        libglib2.0-dev libdw-dev libelf-dev libcapstone-dev libfdt-dev \
        libpixman-1-dev libslirp-dev libffi-dev libffcall-dev libssl-dev \
        libvulkan1 libvulkan-dev mesa-vulkan-drivers \
        libgl1 libglx0 libgl-dev libglx-dev libx11-dev \
        mangohud xauth xvfb x11-xserver-utils x11-utils xdotool \
    && if [[ "$(dpkg --print-architecture)" == arm64 ]]; then \
        apt-get install -y --no-install-recommends \
            gcc-x86-64-linux-gnu g++-x86-64-linux-gnu; \
    fi \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 carries an older yt-dlp that no longer handles the pinned media
# source reliably. Install a fixed current release in an isolated environment.
# The USTC build mode also applies to this Python package download.
# Expose only the launcher through /usr/local/bin. Its shebang already points at
# the virtual environment, so yt-dlp keeps its pinned dependencies. The virtual
# environment must stay off PATH: it would shadow /usr/bin/python3 for every
# other consumer, and the packages installed above (numpy, matplotlib,
# packaging) live in the system interpreter, not in this environment.
RUN python3 -m venv /opt/yt-dlp \
    && if [[ "${USE_USTC_MIRROR}" == 1 ]]; then \
        /opt/yt-dlp/bin/pip install --no-cache-dir \
            --index-url https://pypi.mirrors.ustc.edu.cn/simple \
            yt-dlp==2026.8.19; \
    else \
        /opt/yt-dlp/bin/pip install --no-cache-dir yt-dlp==2026.8.19; \
    fi \
    && ln -s /opt/yt-dlp/bin/yt-dlp /usr/local/bin/yt-dlp

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
