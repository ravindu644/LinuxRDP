FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=linux-rdp

# Install sudo first
RUN sed -i 's/^# deb/deb/g' /etc/apt/sources.list
RUN apt-get update && \
    apt-get install -y sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create passwordless sudo user
RUN useradd -m -s /bin/bash ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo 'export PATH=$PATH:/home/user/.local/bin' >> /home/${USERNAME}/.bashrc

# Install core dependencies
RUN apt-get update && \
    apt-get install -y \
    software-properties-common \
    wget \
    dbus-x11 \
    dbus \
    xvfb \
    xserver-xorg-video-dummy \
    xbase-clients \
    python3-packaging \
    python3-psutil \
    python3-xdg \
    libgbm1 \
    libutempter0 \
    git \
    libfuse2 \
    nload \
    qbittorrent \
    ffmpeg \
    gpac \
    fonts-lklug-sinhala \
    xfce4 \
    desktop-base \
    xfce4-terminal \
    xfce4-session \
    xscreensaver \
    nano \
    curl \
    aria2 \
    xdg-utils \
    coreutils \
    psmisc \
    zip \
    unzip \
    p7zip-full \
    p7zip-rar \
    xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Firefox ESR
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    apt-get update && \
    apt-get install -y firefox-esr && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure Desktop Environment
RUN bash -c 'echo "exec /etc/X11/Xsession /usr/bin/xfce4-session" > /etc/chrome-remote-desktop-session'

# Install Chrome Remote Desktop
RUN wget https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb && \
    apt-get update && \
    dpkg --install chrome-remote-desktop_current_amd64.deb || true && \
    apt-get install -y --fix-broken && \
    rm chrome-remote-desktop_current_amd64.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add user to chrome-remote-desktop group
RUN usermod -aG chrome-remote-desktop ${USERNAME}

# Setup storage directory
RUN mkdir -p /storage && \
    chmod 777 /storage && \
    chown ${USERNAME}:${USERNAME} /storage && \
    mkdir -p /home/${USERNAME}/storage

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

