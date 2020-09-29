#!/bin/bash

function install_docker_buildx() {
#HFILE=buildx HASHcmd=sha256sum HASHSUM=3f4e77686659766a0726b5a47a87e2cc14c86ebf15abf7f19c45d23b0daff222 HURL=https://github.com/docker/buildx/releases/download/v0.4.1/buildx-v0.4.1.linux-amd64
#HFILE=docker-buildx HDIR=~/.docker/cli-plugins HASHcmd=sha256sum HASHSUM=3f4e77686659766a0726b5a47a87e2cc14c86ebf15abf7f19c45d23b0daff222 HURL=https://github.com/docker/buildx/releases/download/v0.4.2/buildx-v0.4.1.linux-amd64
HFILE=docker-buildx HDIR=~/.docker/cli-plugins HASHcmd=sha256sum HASHSUM=c21f07356de93a4fa5d1b7998252ea5f518dbe94ae781e0edeec7d7e29fdf899 HURL=https://github.com/docker/buildx/releases/download/v0.4.2/buildx-v0.4.2.linux-amd64
printf "HFILE=$HFILE HDIR=$HDIR HASHcmd=$HASHcmd HASHSUM=$HASHSUM HURL=$HURL"

( (cd $HDIR && printf %b $HASHSUM\\040\\052$HFILE\\012 | $HASHcmd -c -) && printf %b "SKIP DOWNLOAD\\040\\012" ) || curl -o $HFILE -LR -f -S --connect-timeout 15 --max-time 600 --retry 3 --dump-header - --compressed --verbose $HURL ; (printf %b CHECKSUM\\072\\040expect\\040this\\040$HASHcmd\\072\\040$HASHSUM\\040\\052$HFILE\\012 ; printf %b $HASHSUM\\040\\052$HFILE\\012 | $HASHcmd -c - ;) || (printf %b ERROR\\072\\040CHECKSUMFAILD\\072\\040the\\040file\\040has\\040this\\040$HASHcmd\\072\\040 ; $HASHcmd -b $HFILE ; exit 1)
mkdir -p "${HDIR}"
mv "${HFILE}" "${HDIR}"/"${HFILE}"
chmod 755 "${HDIR}"/"${HFILE}"
chmod a+x ~/.docker/cli-plugins/docker-buildx

  #+# docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
  # see https://github.com/multiarch/qemu-user-static/issues/38
  # see https://github.com/multiarch/qemu-user-static/issues/100
  #docker run --rm --privileged multiarch/qemu-user-static --reset
  #+# docker run --privileged --rm tonistiigi/binfmt --install all

  # Enable docker CLI experimental support (for 'docker buildx').
  #export DOCKER_CLI_EXPERIMENTAL=enabled
  # Instantiate docker buildx builder with multi-architecture support.
  #+#docker buildx create --name mybuilder
  #+#docker buildx use mybuilder
  # Start up buildx and verify that all is OK.
  #+#docker buildx inspect --bootstrap
}


#BUILDX=$(command -v buildx)
#BUILDX=$(command -v docker-buildx)
#DOCKER_BUILDX_CLI_PLUGIN_PATH=~/.docker/cli-plugins/docker-buildx

#DockerServerVersion=$(docker info --format '{{.ServerVersion}}')
#DockerSexperimental=$(docker info --format '{{.ExperimentalBuild}}')

DockerServerVersion=$(docker version --format '{{.Server.Version}}' || docker info --format '{{.ServerVersion}}')
DockerSexperimental=$(docker version --format '{{.Server.Experimental}}' || docker info --format '{{.ExperimentalBuild}}')
DockerClientVersion=$(docker version --format '{{.Client.Version}}')
DockerCexperimental=$(docker version --format '{{.Client.Experimental}}')

uid="$(id -u)"
_sudo() {
	if [ "$uid" = '0' ]; then
		"$@"
	else
    commandVsudo=$(command -v sudo)
    if [ "$commandVsudo" != "" ]; then
    		sudo "$@"
    else
        "$@"
       fi
	fi
}

_dockerRESTART() {
  if [ -d /run/systemd/system ] && command -v systemctl; then
	_sudo systemctl --quiet stop docker || :
	_sudo systemctl start docker
	_sudo systemctl --full --no-pager status docker
   else
	_sudo service docker stop &> /dev/null || :
	_sudo service docker start
   fi
   docker version
}

_sudo sh -xec '
	mkdir -p /etc/docker
	[ -s /etc/docker/daemon.json ] || echo "{}" > /etc/docker/daemon.json
'

#SUDO=$(command -v sudo)

# Get the server version
# docker version --format '{{.Server.Version}}'
# Dump raw JSON data
# docker info --format '{{json .}}'
# docker version --format '{{json .}}'
# docker version --format '{{json .}}' | jq

# echo '{"registry-mirrors": [ "http://10.16.1.163:5000" ], "max-concurrent-downloads": 5, "hosts" : ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]}' >> $DockerSconfig-tmp
if [[ "DockerSexperimental" != true ]]; then
  # Enable docker daemon experimental support (for 'docker build --squash').
  local -r DockerSconfig='/etc/docker/daemon.json'
  mkdir -p /etc/docker/
  if [[ -e "$DockerSconfig" ]]; then
    #_sudo sed -i -e 's/{/{\n"experimental": true,\n/' "$DockerSconfig"
    _sudo cat "$DockerSconfig" | jq '.experimental = true' >> "$DockerSconfig-tmp"
    _sudo cp -p "$DockerSconfig" "$DockerSconfig-bakup-$(date +%Y-%m-%dT%H%M%S)" && _sudo mv "$DockerSconfig-tmp" "$DockerSconfig" || exit 1;
  else
    _sudo echo {} | jq '.experimental = true' >> "$DockerSconfig-tmp"
    _sudo cp -p "$DockerSconfig" "$DockerSconfig-bakup-$(date +%Y-%m-%dT%H%M%S)" && _sudo mv "$DockerSconfig-tmp" "$DockerSconfig" || exit 1;
    #echo '{ "experimental": true }' | $SUDO tee "$DockerSconfig"
  fi
  _dockerRESTART
   # $SUDO systemctl restart docker
fi

if [[ "DockerCexperimental" != true ]]; then
  # Enable docker cli experimental support (for 'docker build --squash').
  local -r DockerCconfig="$HOME/.docker/config.json"
  mkdir -p $HOME/.docker/
  if [[ -e "$DockerCconfig" ]]; then
    _sudo sed -i -e 's/{/{ "experimental": true, /' "$DockerCconfig"
    #_sudo sed -i -e 's/{/{ "aliases": { "builder": "buildx" }, /' "$DockerCconfig"
    #sed -i -e 's/{/{ "aliases": [ "builder": "buildx" ],\n/' "$DockerCconfig"
    #cat "$DockerCconfig" | jq -M -S | sed -e 's/^{/{ "aliases": { "builder": "buildx" } ,\n/1' | jq -M -S >
    cat "$DockerCconfig" | jq -M | sed -e 's/^{/{ "aliases": { "builder": "buildx" } ,\n/1' | jq -M >> $DockerCconfig-tmp
#cat $DockerCconfig-tmp | jq --arg aliases builder
    _sudo cp -p "$DockerCconfig" "$DockerCconfig-bakup-$(date +%Y-%m-%dT%H%M%S)" && _sudo mv "$DockerCconfig-tmp" "$DockerCconfig" || exit 1;
else
    #echo '{ "experimental": true }' | _sudo tee "$DockerCconfig"
    _sudo echo {} | jq '.experimental = true' >> "$DockerSconfig-tmp"
    _sudo cp -p "$DockerCconfig" "$DockerCconfig-bakup-$(date +%Y-%m-%dT%H%M%S)" && _sudo mv "$DockerCconfig-tmp" "$DockerCconfig" || exit 1;
  fi
  #_dockerRESTART
  #$SUDO systemctl restart docker
fi

#docker 
