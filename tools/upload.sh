#!/bin/bash

scp dump-container.sh image-check.sh root@119.8.100.88:/root/
ssh root@119.8.100.88 "scp -P 2222 /root/dump-container.sh /root/image-check.sh localhost:/root/image-release/"