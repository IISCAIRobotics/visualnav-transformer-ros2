# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------
# Locale
# -----------------------------
RUN apt-get update && apt-get install -y locales
RUN locale-gen en_US en_US.UTF-8
RUN update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# -----------------------------
# Base tools
# -----------------------------
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    gnupg2 \
    lsb-release \
    wget \
    sudo

# -----------------------------
# ROS2 Repository
# -----------------------------
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
    http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/ros2.list

# -----------------------------
# Gazebo Repository
# -----------------------------
RUN wget https://packages.osrfoundation.org/gazebo.gpg \
    -O /usr/share/keyrings/gazebo.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/gazebo.gpg] \
    http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/gazebo-stable.list

# -----------------------------
# Install ROS2 + Gazebo + GUI libs
# -----------------------------
RUN apt-get update && apt-get install -y \
    ros-humble-desktop \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-argcomplete \
    gazebo \
    libgazebo-dev \
    ros-humble-gazebo-ros-pkgs \
    ros-humble-gazebo-ros2-control \
    mesa-utils \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    x11-apps \
    git \
    python3-pip \
    alsa-utils \
    pulseaudio

# -----------------------------
# install QT wayland
# -----------------------------
RUN apt-get update && apt-get install -y \
    qtwayland5 \
    qt6-wayland
 
# -----------------------------
# FastRTPS SHM disable
# -----------------------------
RUN echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?> \
<profiles xmlns=\"http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles\"> \
<transport_descriptors> \
<transport_descriptor> \
<transport_id>CustomUdpTransport</transport_id> \
<type>UDPv4</type> \
</transport_descriptor> \
</transport_descriptors> \
<participant profile_name=\"participant_profile\" is_default_profile=\"true\"> \
<rtps> \
<userTransports> \
<transport_id>CustomUdpTransport</transport_id> \
</userTransports> \
<useBuiltinTransports>false</useBuiltinTransports> \
</rtps> \
</participant> \
</profiles>" > /fastrtps_disable_shm.xml

ENV FASTRTPS_DEFAULT_PROFILES_FILE=/fastrtps_disable_shm.xml

# -----------------------------
# rosdep
# -----------------------------
RUN rosdep init && rosdep update

# -----------------------------
# Python tools
# -----------------------------
RUN pip3 install --no-cache-dir gdown poetry

# -----------------------------
# Create real non-root user
# -----------------------------
RUN useradd -m -u 1000 anand && \
    usermod -aG sudo anand && \
    echo "anand ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER anand
ENV HOME=/home/anand
WORKDIR /home/anand

# -----------------------------
# ROS environment for user
# -----------------------------
RUN echo "source /opt/ros/humble/setup.bash" >> /home/anand/.bashrc

# -----------------------------
# Clone VisualNav
# -----------------------------
RUN git clone https://github.com/Robotecai/visualnav-transformer-ros2.git visualnav-transformer
WORKDIR /home/anand/visualnav-transformer

# -----------------------------
# Install Python deps
# -----------------------------
# -----------------------------
# Fix network + install Torch manually (prevents Poetry timeout)
# -----------------------------
RUN pip3 config set global.timeout 300 && \
    pip3 config set global.retries 10 && \
    pip3 config set global.index-url https://pypi.org/simple

# Disable IPv6 (very important for WSL Docker)
RUN sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true

# Install Torch BEFORE Poetry
# -----------------------------
# Install NVIDIA CUDA-enabled PyTorch (for Quadro GPU)
# -----------------------------
RUN pip3 config set global.timeout 300 && \
    pip3 config set global.retries 10

RUN pip3 install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# -----------------------------
# Install remaining Python deps via Poetry (skip torch)
# -----------------------------
RUN poetry install --no-interaction --no-ansi --without dev


# -----------------------------
# Download model
# -----------------------------
RUN mkdir -p model_weights && \
    gdown https://drive.google.com/uc?id=1YJhkkMJAYOiKNyCaelbS_alpUpAJsOUb \
    -O model_weights/nomad.pth

# -----------------------------
# Entry
# -----------------------------
ENTRYPOINT ["/bin/bash"]
