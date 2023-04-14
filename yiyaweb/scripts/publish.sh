#!/bin/bash


ssh root@huawei01 "kubectl -n yiyaweb set image deployments.apps yiyaweb-frontend yiyaweb-frontend=${1}"
