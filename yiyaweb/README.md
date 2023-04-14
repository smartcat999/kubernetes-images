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
# 自定义镜像tag
make publish TAG=${dev} 
```