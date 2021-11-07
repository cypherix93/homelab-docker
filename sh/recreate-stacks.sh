#!/bin/bash

# portainer stack
docker stack rm portainer
docker stack deploy -c "$(dirname "$0")/../stacks/portainer.yml" portainer