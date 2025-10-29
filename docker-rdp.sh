#!/bin/bash

# --- Configuration ---
IMAGE_NAME="linux-rdp"
CONTAINER_NAME="linux-rdp"
COMPRESSED_IMAGE="linux-rdp.tar.xz"
INSTALL_MARKER=".installed"

# --- Colors for output ---
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# --- Global signal handler ---
cleanup_on_interrupt() {
    echo -e "\n${RED}Interrupted by user. Exiting...${RESET}"
    exit 130
}

# Set up trap for Ctrl+C globally
trap cleanup_on_interrupt INT TERM

# --- Pre-flight Checks ---
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in your PATH.${RESET}"
    echo "Please install Docker to use this script: https://docs.docker.com/get-docker/"
    exit 1
fi

# --- Helper Functions ---
usage() {
    echo "Usage: $0 {build|package|start|stop|logs|shell|uninstall}"
    echo "Commands:"
    echo "  build      - Builds (or rebuilds) the Docker image."
    echo "  package    - Builds and packages the image as .tar.xz"
    echo "  start      - Starts the RDP container (builds if needed)."
    echo "  stop       - Stops the running container."
    echo "  logs       - View the live logs of the container."
    echo "  shell      - Open an interactive shell inside the running container."
    echo "  uninstall  - DESTRUCTIVE. Removes container and image."
    exit 1
}

load_compressed_image() {
    if [ -f "$COMPRESSED_IMAGE" ]; then
        echo -e "${GREEN}Found compressed image. Loading...${RESET}"
        if xz -d -c "$COMPRESSED_IMAGE" | docker load; then
            echo -e "${GREEN}Image loaded successfully!${RESET}"
            return 0
        else
            echo -e "${RED}Failed to load compressed image.${RESET}"
            exit 1
        fi
    fi
    return 1
}

build_image() {
    echo -e "${BLUE}--- Building Docker image: '$IMAGE_NAME' ---${RESET}"
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}Error: Dockerfile not found in the current directory.${RESET}"
        exit 1
    fi
    
    if docker build -t "$IMAGE_NAME" .; then
        echo -e "${GREEN}Build complete!${RESET}"
        return 0
    else
        echo -e "${RED}Error: Docker build failed.${RESET}"
        exit 1
    fi
}

package_image() {
    echo -e "${BLUE}--- Packaging Docker image ---${RESET}"
    
    # Ensure image exists
    if ! docker image inspect "$IMAGE_NAME" &> /dev/null; then
        echo -e "${YELLOW}Image not found. Building first...${RESET}"
        build_image || exit 1
    fi
    
    echo -e "${YELLOW}Exporting Docker image...${RESET}"
    if ! docker save -o "${IMAGE_NAME}.tar" "$IMAGE_NAME"; then
        echo -e "${RED}Failed to export image.${RESET}"
        exit 1
    fi
    
    echo -e "${YELLOW}Compressing with xz (maximum compression)...${RESET}"
    echo "This may take a while..."
    if ! xz -z -T0 -9 "${IMAGE_NAME}.tar"; then
        echo -e "${RED}Failed to compress image.${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}Package created: ${IMAGE_NAME}.tar.xz${RESET}"
    echo -e "${GREEN}Size: $(du -h ${IMAGE_NAME}.tar.xz | cut -f1)${RESET}"
}

ensure_image_exists() {
    if docker image inspect "$IMAGE_NAME" &> /dev/null; then
        return 0
    fi
    
    echo "Image '$IMAGE_NAME' not found."
    
    if [ -f "$INSTALL_MARKER" ]; then
        echo -e "${YELLOW}Installation marker exists but image is missing. Rebuilding...${RESET}"
        rm -f "$INSTALL_MARKER"
    fi
    
    if ! load_compressed_image; then
        echo "Building from Dockerfile..."
        build_image
    fi
    
    touch "$INSTALL_MARKER"
}

# --- Main Logic ---
case "$1" in
    build)
        echo -e "${YELLOW}Removing previous installation...${RESET}"
        docker stop "$CONTAINER_NAME" &>/dev/null
        docker rm "$CONTAINER_NAME" &>/dev/null
        docker rmi "$IMAGE_NAME" &>/dev/null
        rm -f "$INSTALL_MARKER"

        # Try loading compressed image first
        if ! load_compressed_image; then
            build_image
        fi
        
        touch "$INSTALL_MARKER"
        echo -e "${GREEN}Image ready to use!${RESET}"
        ;;

    package)
        package_image
        ;;

    start)
        echo -e "${BLUE}--- Starting container: '$CONTAINER_NAME' ---${RESET}"
        ensure_image_exists

        if [ "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container is already running. Attaching to view logs..."
            echo -e "${YELLOW}Press Ctrl+C to exit (container will keep running)${RESET}"
            # Override trap for logs viewing only
            trap 'echo -e "\n${YELLOW}Detached from logs. Container is still running.${RESET}"; exit 0' INT TERM
            docker logs -f "$CONTAINER_NAME"
        elif [ "$(docker ps -a -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo "Container exists but is stopped. Starting and attaching..."
            echo -e "${YELLOW}Press Ctrl+C to exit (container will keep running)${RESET}"
            docker start "$CONTAINER_NAME"
            # Override trap for logs viewing only
            trap 'echo -e "\n${YELLOW}Detached from logs. Container is still running.${RESET}"; exit 0' INT TERM
            docker logs -f "$CONTAINER_NAME"
        else
            echo "Creating a new container..."
            echo -e "${YELLOW}You'll be prompted for Chrome Remote Desktop setup.${RESET}"
            echo -e "${YELLOW}Press Ctrl+C to stop and exit.${RESET}"
            docker run -it --privileged --name "$CONTAINER_NAME" "$IMAGE_NAME"
        fi
        ;;

    stop)
        echo -e "${BLUE}--- Stopping container: '$CONTAINER_NAME' ---${RESET}"
        if docker stop "$CONTAINER_NAME" 2>/dev/null; then
            echo -e "${GREEN}Container stopped.${RESET}"
        else
            echo -e "${YELLOW}Container is not running.${RESET}"
        fi
        ;;

    logs)
        echo -e "${BLUE}--- Tailing logs for container: '$CONTAINER_NAME' ---${RESET}"
        if docker ps -q -f name=^/${CONTAINER_NAME}$ &> /dev/null && [ -n "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            echo -e "${YELLOW}Press Ctrl+C to stop viewing logs${RESET}"
            # Override trap for logs viewing only
            trap 'echo -e "\n${YELLOW}Stopped viewing logs. Container is still running.${RESET}"; exit 0' INT TERM
            docker logs -f "$CONTAINER_NAME"
        else
            echo -e "${YELLOW}Container is not running.${RESET}"
            echo "Showing last logs from stopped container:"
            docker logs "$CONTAINER_NAME" 2>/dev/null || echo -e "${RED}No logs available.${RESET}"
        fi
        ;;

    shell)
        echo -e "${BLUE}--- Opening a shell in container: '$CONTAINER_NAME' ---${RESET}"
        ensure_image_exists
        
        if docker ps -q -f name=^/${CONTAINER_NAME}$ &> /dev/null && [ -n "$(docker ps -q -f name=^/${CONTAINER_NAME}$)" ]; then
            # Container is running, exec into it
            docker exec -it "$CONTAINER_NAME" /bin/bash
        else
            echo -e "${YELLOW}Container is not running. Starting temporary shell-only container...${RESET}"
            docker rm "$CONTAINER_NAME" &>/dev/null
            docker run -it --rm --privileged --name "${CONTAINER_NAME}-shell" "$IMAGE_NAME" /bin/bash
        fi
        ;;

    uninstall)
        echo -e "${RED}--- UNINSTALLATION ---${RESET}"
        read -p "WARNING: This will permanently delete the container and image. Are you sure? (y/n): " confirm
        if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
            echo "Stopping and removing container..."
            docker stop "$CONTAINER_NAME" &>/dev/null
            docker rm -f "$CONTAINER_NAME" &>/dev/null
            echo "Removing image..."
            docker rmi -f "$IMAGE_NAME" &>/dev/null
            echo "Cleaning up installation marker..."
            rm -f "$INSTALL_MARKER"
            echo -e "${GREEN}Uninstallation complete.${RESET}"
        else
            echo "Uninstallation cancelled."
        fi
        ;;

    *)
        usage
        ;;
esac
