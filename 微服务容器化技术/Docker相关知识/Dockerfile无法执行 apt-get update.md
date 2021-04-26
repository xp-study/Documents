```
【摘要】Dockerfile无法执行 apt-get update，错误提示：Could not connect to archive.ubuntu.com:80 尝试过修改DNS无效，最终是通过修改源解决此问题。 网上提供的dockerfile大部分都是在ubuntu默认源执行apt-update，此时build过程非常慢，甚至请求time out，而且打包出来的镜像使用时也会存在慢的情况。首...
```

Dockerfile无法执行 apt-get update，错误提示：Could not connect to archive.ubuntu.com:80

尝试过修改DNS无效，最终是通过修改源解决此问题。

网上提供的dockerfile大部分都是在ubuntu默认源执行`apt-update`，此时build过程非常慢，甚至请求time out，而且打包出来的镜像使用时也会存在慢的情况。首先从清华源`https://mirror.tuna.tsinghua.edu.cn/help/ubuntu/`复制到sources.list如下：

```javascript
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
```

Dockerfile如下：

```javascript
FROM duruo850/ubuntu18.04-python3.6

ENV DEBIAN_FRONTEND=noninteractive

# 添加源
COPY sources.list /etc/apt/sources.list

RUN apt-get update -y && apt-get install --assume-yes apt-utils && apt-get install -y vim
```

其他错误：

在用docker-compose up时候遇到如下错误：

Docker error: Cannot start service …: network 7808732465bd529e6f20e4071115218b2826f198f8cb10c3899de527c3b637e6 not found

解决：我把该docker-compose任务下的容器都删了，重新运行docker-compose up就正常了。
