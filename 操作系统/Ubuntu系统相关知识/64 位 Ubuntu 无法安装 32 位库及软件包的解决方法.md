# 64 位 Ubuntu 无法安装 32 位库及软件包的解决方法

## 一、问题描述

在搭建[全志 H3](http://www.allwinnertech.com/index.php?c=product&a=index&id=47) 开发环境时，其开发依赖的环境包含 32 位应用程序。
为了统一开发环境至 64 位 Ubuntu Server 主机上，在 64 位 Ubuntu Server 上安装 32 位软件包时出现如下错误：

```
E: Unable to locate package 安装的 32 位软件包名:i386
```

## 二、解决方法

在 64 位系统上添加 32 位软件源及软件运行库支持，具体操作如下：

```
# 添加 i386 架构支持
sudo dpkg --add-architecture i386
# 更新同步缺失的源信息
sudo apt-get update
sudo apt-get update --fix-missing
sudo apt-get dist-upgrade
# 添加 32 位 gcc 运行库环境
sudo apt-get install gcc-multilib g++-multilib
```

然后使用 apt-get 安装所需的 32 位软件包。
