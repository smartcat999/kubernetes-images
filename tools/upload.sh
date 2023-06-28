#!/bin/bash

scp run-jobs.sh image-check.sh root@119.8.100.88:/root/
ssh root@119.8.100.88 "scp -P 2222 /root/run-jobs.sh /root/image-check.sh localhost:/root/image-release/"