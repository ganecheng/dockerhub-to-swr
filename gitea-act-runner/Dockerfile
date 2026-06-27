#syntax=docker/dockerfile:1
# see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md
# see https://docs.docker.com/engine/reference/builder/#syntax
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-gitea-act-runner

# https://hub.docker.com/_/ubuntu/tags?name=24.04
ARG BASE_IMAGE=ubuntu:24.04

FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG GITEA_RUNNER_VERSION

RUN <<EOF
  echo "#################################################"
  echo "Installing latest OS updates..."
  echo "#################################################"
  apt-get update
  apt-get upgrade -y

  function minimize() {
    ls -l "$@"
    echo "Stripping [$*]..."
    command strip --strip-unneeded "$@"
    ls -l "$@"
  }

  function curl() {
    command curl -sSfL --connect-timeout 10 --max-time 30 --retry 3 --retry-all-errors "$@"
  }

  arch=$(dpkg --print-architecture)
  case "$arch" in
    amd64|arm64) gitea_arch=$arch ;;
    *) echo "Unsupported arch: $arch"; exit 1;;
  esac

  echo "#################################################"
  echo "Installing required packages..."
  echo "#################################################"
  apt-get install --no-install-recommends -y adduser binutils ca-certificates curl sudo tini nodejs npm jq

  minimize /usr/bin/tini-static

  echo "#################################################"
  echo "Downloading Gitea Runner..."
  echo "#################################################"
  GITEA_RUNNER_VERSION=$(curl -sSf 'https://gitea.com/api/v1/repos/gitea/runner/releases?draft=false&pre-release=false&limit=1' | jq -r '.[0].tag_name | ltrimstr("v")')
  if [[ $GITEA_RUNNER_VERSION == "nightly" ]]; then
    gitea_runner_download_url="https://dl.gitea.com/gitea-runner/nightly/gitea-runner-${GITEA_RUNNER_VERSION}-linux-${gitea_arch}"
    gitea_runner_download_fallback_url=""
  else
    gitea_runner_release_url="https://gitea.com/gitea/runner/releases/download/v${GITEA_RUNNER_VERSION}"
    gitea_runner_download_url="${gitea_runner_release_url}/gitea-runner-${GITEA_RUNNER_VERSION}-linux-${gitea_arch}"
    gitea_runner_download_fallback_url="${gitea_runner_release_url}/act_runner-${GITEA_RUNNER_VERSION}-linux-${gitea_arch}"
  fi
  echo "Downloading [$gitea_runner_download_url]..."
  if ! curl "$gitea_runner_download_url" -o /usr/local/bin/gitea-runner; then
    if [[ -z $gitea_runner_download_fallback_url ]]; then
      exit 1
    fi
    echo "Download failed, retrying legacy release asset [$gitea_runner_download_fallback_url]..."
    curl "$gitea_runner_download_fallback_url" -o /usr/local/bin/gitea-runner
  fi
  chmod 755 /usr/local/bin/gitea-runner
  minimize /usr/local/bin/gitea-runner
  gitea-runner --version

  echo "#################################################"
  echo "Installing docker engine..."
  echo "#################################################"
  # git needed by buildx
  apt-get install --no-install-recommends -y git
  # https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
  apt-get install --no-install-recommends -y gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl "https://download.docker.com/linux/ubuntu/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  ARCH="$(dpkg --print-architecture)"
  OS_CODENAME="$(source /etc/os-release && echo "$VERSION_CODENAME")"
  echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $OS_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  (set -x; apt-get install --no-install-recommends -y docker-ce docker-buildx-plugin docker-compose-plugin containerd.io fuse-overlayfs)
  apt-get remove -y gnupg
  apt-get autoremove -y

  minimize \
    /usr/bin/containerd* \
    /usr/bin/ctr \
    /usr/bin/docker* \
    /usr/bin/runc \
    /usr/libexec/docker/cli-plugins/*

  docker --version
  docker compose version
  docker buildx version
  runc --version

  if [[ -f /etc/init.d/docker ]] && grep -q "ulimit -Hn" /etc/init.d/docker; then
    sed -i 's/ulimit -Hn/ulimit -n/g' /etc/init.d/docker
  fi

  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

  docker_version=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
  dind_hack_url="https://raw.githubusercontent.com/moby/moby/v${docker_version}/hack/dind"
  if ! curl -o /dev/null -f -s "$dind_hack_url"; then
    alt_url="https://raw.githubusercontent.com/moby/moby/docker-v${docker_version}/hack/dind"
    if curl -o /dev/null -f -s "$alt_url"; then
      dind_hack_url="$alt_url"
    else
      echo "❌ Could not find dind hack script for Docker version ${docker_version}" >&2
      exit 1
    fi
  fi
  echo "Downloading [$dind_hack_url]..."
  curl "$dind_hack_url" -o /usr/local/bin/dind-hack
  chmod +x /usr/local/bin/dind-hack

  echo "#################################################"
  echo "Cleanup..."
  echo "#################################################"
  apt-get remove -y binutils curl
  apt-get clean autoclean
  apt-get autoremove --purge -y
  rm -rf /var/cache/{apt,debconf} \
     /var/lib/apt/lists/* \
     /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} \
     /tmp/* /var/tmp/*

EOF

# Default configuration: can be overridden at the docker command line
ENV \
  INIT_SH_FILE='' \
  #
  GITEA_RUNNER_CONFIG_TEMPLATE_FILE='/opt/config.template.yaml' \
  #
  GITEA_RUNNER_NAME='' \
  GITEA_RUNNER_LABELS='' \
  #
  # https://gitea.com/gitea/runner-images
  # https://github.com/catthehacker/docker_images#images-available
  # https://hub.docker.com/r/catthehacker/ubuntu/tags?name=act-
  GITEA_RUNNER_LABELS_DEFAULT='\
ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest,\
ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04,\
ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04,\
ubuntu-20.04:docker://ghcr.io/catthehacker/ubuntu:act-20.04' \
  #
  GITEA_RUNNER_EPHEMERAL=false \
  GITEA_RUNNER_REGISTRATION_TIMEOUT=30 \
  GITEA_RUNNER_REGISTRATION_RETRY_INTERVAL=5

COPY gitea-act-runner/*.sh /opt/
COPY gitea-act-runner/config.template.yaml /opt/

VOLUME /data

VOLUME /var/lib/docker

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/bin/bash", "/opt/run.sh"]
