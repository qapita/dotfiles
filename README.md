# dotfiles

# Build docker image

```bash

curl -H 'Cache-Control: no-cache, no-store' -s \
    https://raw.githubusercontent.com/qapita/dotfiles/master/docker/ubuntu.dockerfile | \
  docker build -t qapita/ubuntu-dev:latest -
  

```