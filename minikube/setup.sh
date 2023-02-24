#!/usr/bin/env bash

echo "QAPITA : 💻 Local-Kubernetes-Setup"

echo "Install common tools"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt-get update && \
        sudo apt-get install -y curl dnsutils vim tmux iputils-ping \
        wget net-tools postgresql-client groff less unzip \
        apt-transport-https ca-certificates gnupg \
        build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
        libnss3-dev libssl-dev libreadline-dev libffi-dev \
        tzdata software-properties-common && \
        sudo add-apt-repository -y ppa:deadsnakes/ppa
    echo "Common tools for $OSTYPE installed"

elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Checking if brew (https://brew.sh/) is installed"
    which -s brew
    if [[ $? != 0 ]]; then
        echo "brew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "Updating brew"
        brew update
    fi
    # Install common tools for macOS
    brew install curl wget git vim tmux iputils
    echo "Common tools for $OSTYPE installed"
else
    # Unsupported operating system
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

echo "Checking if docker is installed"

# which -s docker &> /dev/null
# if [[ $? != 0 ]]; then
#     echo "Please install docker on your system before proceeding with this script"
#     #exit 1
# else
#     echo "Docker is already installed"
# fi

# Get current docker version
current_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
# Get latest docker version
latest_version="23.0.1"

# Compare versions and update if necessary
if [ "$current_version" != "$latest_version" ]; then
  echo "Updating docker from $current_version to $latest_version"
  sudo apt-get update
  sudo apt-get remove docker docker-engine docker.io containerd runc
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
else
  echo "Docker is already up-to-date with version $latest_version"
fi

# Install nvm and node

if ! command -v nvm &> /dev/null; then
    echo "nvm not found. Installing..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

elif ! command -v node &> /dev/null; then
    echo "node not found. Installing..."
    # Install node
    export NODE_LTS=`nvm ls-remote --lts | tail -n 1 | awk 'BEGIN{FS=" "} {print $1}'`
    nvm install ${NODE_LTS}
    nvm alias default ${NODE_LTS}
    nvm use ${NODE_LTS}
    npm install -g lerna typescript concurrently
fi

# Install Minikube
echo "Install (Minikube, Kubectl, Helm, Kustomize)"

# Detect the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo "Detected Mac OS X"
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not found. Installing..."
        brew install kubectl
    fi
    if ! command -v minikube &> /dev/null; then
        echo "minikube not found. Installing..."
        brew install minikube
    fi
    if ! command -v helm &> /dev/null; then
        echo "helm not found. Installing..."
        brew install helm
    fi
    if ! command -v kustomize &> /dev/null; then
        echo "kustomize not found. Installing..."
        brew install kustomize
    fi


elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Detected Linux"
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not found. Installing..."
        sudo apt-get update && sudo apt-get install -y curl
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    if ! command -v minikube &> /dev/null; then
        echo "minikube not found. Installing..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    fi
    if ! command -v helm &> /dev/null; then
        echo "helm not found. Installing..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    if ! command -v kustomize &> /dev/null; then
        echo "kustomize not found. Installing..."
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
    fi
else
    echo "Unsupported operating system"
    exit 1
fi

# Start the cluster

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo "Detected Mac OS X"
    if ! minikube status &> /dev/null; then
        echo "Minikube not running. Starting..."
        #minikube start
        minikube start --cpus=2 --memory=4096 --driver=docker

    else
        echo "Minikube is already running."
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Detected Linux"
    if ! minikube status &> /dev/null; then
        echo "Minikube not running. Starting..."
        #minikube start --driver=docker
        minikube start --cpus=2 --memory=4096 --driver=docker

    else
        echo "Minikube is already running."
        echo "Ref: https://minikube.sigs.k8s.io/docs/start/"
    fi
else
    echo "Unsupported operating system"
    exit 1
fi

# Add support for multiple architecture builds
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OS X
    echo "Detected Mac OS X"
    if ! minikube status &> /dev/null; then
        echo "Minikube not running. Starting..."
        minikube start
    fi
    # Get Minikube IP
    MINIKUBE_IP=$(minikube ip)
    # SSH into Minikube and run query
    ssh -i $(minikube ssh-key) docker@$(minikube ip)  'docker run --privileged --rm tonistiigi/binfmt --install arm64,riscv64,arm'
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Detected Linux"
    if ! minikube status &> /dev/null; then
        echo "Minikube not running. Starting..."
        sudo minikube start
    fi
    # Get Minikube IP
    MINIKUBE_IP=$(sudo minikube ip)
    # SSH into Minikube and run query
    ssh -i $(minikube ssh-key) docker@$(minikube ip) 'docker run --privileged --rm tonistiigi/binfmt --install arm64,riscv64,arm'
else
    echo "Unsupported operating system"
    exit 1
fi

# Pull regularly used images to the minikube vm

IMAGES=("mongo:6.0.4-jammy" "datalust/seq:latest" "busybox:latest")
for img in ${IMAGES[@]}; do
    echo "Loading image ${img} to minikube cache"
    EXISTING_IMAGES=$(minikube image ls)
    exists=0
    for currentImg in ${EXISTING_IMAGES[@]}; do
        if [[ "${currentImg}" == *"${img}" ]]; then
            echo "Image ${img} already loaded"
            exists=1
            break
        fi
    done
    if [[ "$exists" != "1" ]]; then
        echo "Loading image ${img}"
        minikube image load ${img}
    fi
done

# # Load MongoDB 6 image
# if ! minikube image ls | grep mongo-6 &> /dev/null; then
#     echo "MongoDB 6 image not found. Loading..." && echo "It might take sometime for the command to finish"
#     minikube image load mongo:6.0.4-jammy
# fi

# # Load Seq image
# if ! minikube image ls | grep datalust/seq &> /dev/null; then
#     echo "Seq image not found. Loading..." && echo "It might take sometime for the command to finish"
#     minikube image load datalust/seq:latest
# fi

# # Load BusyBox image
# if ! minikube image ls | grep busybox &> /dev/null; then
#     echo "BusyBox image not found. Loading..." && echo "Busybox is for testing and troubleshooting issues"
#     minikube image load busybox:latest
# fi

# List the availble images
echo "List of available images in minikube"
minikube image ls
clear -x

# Minikube Addons
echo "Enable minikube addons"

# Install Ingress addon
echo "Installing Ingress addon..."
minikube addons enable ingress

# Install Registry-Creds addon
echo "Installing Registry-Creds addon..."
minikube addons enable registry-creds

# Configure Registry-Creds
echo "Configuring Registry-Creds..."


# Minikube Dashboard
echo "Enable minikube dashboard"
# Start new tmux session
echo "Starting a new tmux session in background"
tmux new-session -d -s dashboard

# Attach to session 
#tmux a -t dashboard

echo "Starting minikube dashboard in background session"
# Execute command in session
tmux send-keys -t dashboard 'echo "Minikube Dashboad" && minikube dashboard' Enter
# Detach from session
tmux detach-client


# Set the namespace name
NAMESPACE="development"

# Check if the namespace already exists
if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace $NAMESPACE already exists"
else
  # Create the namespace
  kubectl create namespace "$NAMESPACE"
  echo "Namespace $NAMESPACE created"
fi

# Set the Kubernetes context to the new namespace
kubectl config set-context --current --namespace="$NAMESPACE"
echo "Namespace $NAMESPACE set as the current context"


# Install cert-manager
# Check if cert-manager is already installed
if kubectl get namespace cert-manager > /dev/null 2>&1; then
    echo "cert-manager is already installed"
else
    # Install cert-manager using the official Helm chart
    kubectl create namespace cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
    echo "cert-manager has been installed"
fi

clear -x

echo "Installed common tools, minikube, kubectl, helm, kustomize"

echo '
                       ___      _    ____ ___ _____  _    
                      / _ \    / \  |  _ \_ _|_   _|/ \   
                     | | | |  / _ \ | |_) | |  | | / _ \  
                     | |_| | / ___ \|  __/| |  | |/ ___ \ 
                      \__\_\/_/   \_\_|  |___| |_/_/   \_\
                                                          
                                                          
'