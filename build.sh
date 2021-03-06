#!/usr/bin/env bash

# Build images for Centreon servers.

# Arguments are prepended to the `docker-compose build` command argument array
# (before the service name)
#
# Possible values are:
#    --force-rm              Always remove intermediate containers.
#    --no-cache              Do not use cache when building the image.
#    --pull                  Always attempt to pull a newer version of the image.
#    --build-arg key=val     Set build-time variables for one service.

## NB: docker-compose service name must be the same as image’s repository
## for the flatten() function to work.
## image: `<user>/<repository>:<tag>` → service: `<repository>`
USER_ID="oxyure"
SERVICES="centreondb centreon centreonpoller"

function prune_docker {
    echo -e "\n  ### Do some cleaning…\n"
    docker container prune --force
    docker image prune --force 
}

function flatten {
    ## Create a flattened version of image tagged "flat"
    ## ARG1: repository (must match service name)
    ## ARG2: entrypoint, default to ["/bin/sh"]
    ## ARG3: user, default to root
    ## ARG4: workdir, default to /
    if [ -z "$2" ]; then entrypoint='["/bin/sh"]'; else entrypoint="$2"; fi
    if [ -z "$3" ]; then user='root'; else user="$3"; fi
    if [ -z "$4" ]; then workdir='/'; else workdir="$4"; fi
    echo -e "\n  ### Flattening $USER_ID/$1:latest… − Entrypoint:${entrypoint}, User:${user}, Workdir:${workdir}\n"
    RANDNAME="$(echo $RANDOM |md5sum |cut -d' ' -f1)"
    docker run -d --name "$RANDNAME" "$USER_ID/$1:latest"
    docker stop "$RANDNAME"
    docker export -o "/tmp/$RANDNAME.tar" "$RANDNAME"
    docker import \
       --change 'WORKDIR '"${workdir}" \
       --change 'USER '"${user}" \
       --change 'ENTRYPOINT '"${entrypoint}" \
       --message "/tmp/$RANDNAME.tar" \
       "/tmp/$RANDNAME.tar" "$USER_ID/$1:flat"
    rm "/tmp/$RANDNAME.tar"
    docker rm "$RANDNAME"
}

echo -e "\n  *** Centreon docker images creation ***\n"

prune_docker

grep ^CENTREON .env

for service in ${SERVICES}; do

    echo -e "\n  ### Building image \"${service}\"…\n"
    echo -e " \$ docker-compose build $@ ${service}\n"
    docker-compose build $@ ${service}

done

echo -e "\n  ### All images have been built.\n"

#flatten centreon       '["/entrypoint"]' root /
#flatten centreondb     '["/entrypoint"]' root /
#flatten centreonpoller '["/entrypoint"]' root /

echo -e "\n  ### All images have been flattened.\n"

prune_docker

docker image ls

exit 0
