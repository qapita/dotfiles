FROM --platform=$BUILDPLATFORM ubuntu:22.04

LABEL org.opencontainers.image.vendor="Qapita Fintech Pte. Ltd."
LABEL org.opencontainers.image.authors="vamsee@qapita.com"

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETPLATFORM

ENV TZ="Asia/Kolkata"

# install common tools
RUN apt-get update && \
    apt-get install -y curl dnsutils vim tmux iputils-ping \
      wget net-tools postgresql-client groff less unzip \
      apt-transport-https ca-certificates gnupg \
      build-essential zlib1g-dev libncurses5-dev libgdbm-dev \
      libnss3-dev libssl-dev libreadline-dev libffi-dev \
      tzdata software-properties-common && \
      add-apt-repository -y ppa:deadsnakes/ppa

# set timezone
RUN ln -fs /usr/share/zoneinfo/Asia/Kolkata /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# install python3.9
RUN apt-get update && \
    apt-get install -y python3.9

RUN echo "Asia/Kolkata" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# install mongo db sdk
RUN wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add - && \
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
    apt-get update && apt-get install -y mongodb-mongosh

# install aws sdk

RUN if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
    AWS_SDK_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ; \
    elif [ "${TARGETPLATFORM}" = "linux/amd64" ]; then \
    AWS_SDK_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ; \
    else \
    AWS_SDK_URL="unknown url" ; \
    fi \
    && echo $TARGETPLATFORM $AWS_SDK_URL \
    && curl -s "$AWS_SDK_URL" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip && ./aws/install && rm -rf awscliv2.zip ./aws
 
# install google cloud sdk
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && \
    apt-get update -y && apt-get install google-cloud-cli -y

# dotnet and nodejs?

CMD [ "/bin/bash" ]