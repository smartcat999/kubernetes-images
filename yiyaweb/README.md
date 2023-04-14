##### 1 publish

###### 1 copy static file
解压dist文件到目录下
```text
yiyaweb
├── Dockerfile
├── Makefile
├── README.md
├── dist <----------
├── scripts
└── yiyai.conf
```
###### 2 build container && publish image
```shell
# 构建发布方式 二选一
# 自定义镜像tag
# 单平台构建
make publish-image TAG=${dev}
# 或者
# 多平台构建
make publish-multi-image TAG=${dev} 
```