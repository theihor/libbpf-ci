#!/bin/bash

tag=$(echo "$(pwd)" | sed "s:^$HOME/::" | tr '/' '-')

docker build -f Dockerfile -t $tag .

