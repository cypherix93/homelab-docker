#!/bin/bash

# portainer stack
docker stack rm portainer
docker stack deploy --prune -c "$(dirname "$0")/../stacks/portainer.yml" portainer_side