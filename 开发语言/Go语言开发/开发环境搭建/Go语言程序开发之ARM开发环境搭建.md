# Go语言程序开发之ARM开发环境搭建

### 参考文档

1. [Go语言官方编译指南(需翻墙访问)](https://golang.org/doc/install/source)

### 开发环境介绍

* 主机操作系统：Ubuntu14.04 64位
* 目标平台：盒子V1(IMX.6)
* 交叉工具链：arm-poky-linux-gnueabi，gcc4.8.2
* Go版本：1.10.3
* 编译时间：2018.8.27

### 编译Go编译器(Host)

因为从Go1.4之后Go语言的编译器完全由Go语言编写，所以为了从源代码编译Go需要先编译一个1.4版本的Go版本。为了方便国内下载可以提供一个[Go1.4工具链源代码地址地址](https://pan.baidu.com/s/1xWrsCeYiWhmAEKZvRTRhKg)。

下载完成之后将得到一个go1.4-bootstrap-20171003.tar.gz压缩包，接下来进行解压编译：

``` bash
tar -zxvf go1.4-bootstrap-20171003.tar.gz -C /usr/local/
cd /usr/local/go/src
GOOS=linux GOARCH=amd64 ./make.bash
```

经过短时间的编译之后将会在`go/bin`目录下生成go命令二进制文件

#### 设置环境变量

在`/etc/bash.bashrc`文件中添加如下内容(重启命令行后生效))：

``` bash
export GOROOT_BOOTSTRAP=/usr/local/go
export CC_FOR_TARGET=/opt/zhaozhongxiang/hwzt_yc_3.10.53/build-x11/tmp/sysroots/x86_64-linux/usr/bin/cortexa9hf-vfp-neon-poky-linux-gnueabi/arm-poky-linux-gnueabi-gcc    
export CXX_FOR_TARGET=/opt/zhaozhongxiang/hwzt_yc_3.10.53/build-x11/tmp/sysroots/x86_64-linux/usr/bin/cortexa9hf-vfp-neon-poky-linux-gnueabi/arm-poky-linux-gnueabi-g++
```

> 提示：当选择开启CGO编译时必须配置`CC_FOR_TARGET`和`CXX_FOR_TARGET`两个环境变量，如果不需要开启CGO编译时可以忽略CC_FOR_TARGET和CXX_FOR_TARGET。

### 编译Go(ARM)

完成Go1.4的编译之后，可以利用Go1.4来编译新版本的Go，这里提供[Go源代码下载地址](https://github.com/golang/go/releases)。

``` bash
tar -zxvf go-go1.10.3.tar.gz
cd go-go1.10.3/src
# 开启CGO编译
CGO_ENABLED=1 GOOS=linux GOARCH=arm GOARM=7 ./make.bash 
# 关闭CGO编译
CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 ./make.bash
```

经过编译之后`go-go1.10.3`目录下会生成arm和amd64两个平台的Go命令和依赖包，所以这个版本编译的Go命令可以进行两个平台的Go应用程序开发。

使用新编译的Go1.10版本替换旧的Go1.4

``` bash
cd go-go1.10.3/src
cd ../../
mv go-go1.10.3 go
rm /usr/local/go -rf
cp -r go /usr/local/go
```

这里也提供已经编译好的Go1.10的版本[[下载地址]](http://192.168.101.174:8001/lib/a8de643e-4c99-4709-beb2-b11d8b226483/file/g/go/1.10.3/go-1.10.3-Release.tar.gz)，下载完成之后解压到`/usr/local`目录下直接使用。

另外还提供了一些Go的内置的依赖库存放在[gopath压缩包](http://192.168.101.174:8001/lib/a8de643e-4c99-4709-beb2-b11d8b226483/file/g/go/1.10.3/gopath-1.10.3-BoxV1.tar.gz)中，下载完成之后解压到`/usr/local`目录下直接使用。

#### 设置环境变量

在`/etc/bash.bashrc`文件中添加如下内容(重启命令行后生效))：

``` bash
export GOROOT_BOOTSTRAP=/usr/local/go
# 当需要编译CGO的Go应用程序(ARM版本)时需要要保留下面的两个环境变量，如果不需要开启CGO编译可以省略CC_FOR_TARGET和CXX_FOR_TARGET
export CC_FOR_TARGET=/opt/zhaozhongxiang/hwzt_yc_3.10.53/build-x11/tmp/sysroots/x86_64-linux/usr/bin/cortexa9hf-vfp-neon-poky-linux-gnueabi/arm-poky-linux-gnueabi-gcc    
export CXX_FOR_TARGET=/opt/zhaozhongxiang/hwzt_yc_3.10.53/build-x11/tmp/sysroots/x86_64-linux/usr/bin/cortexa9hf-vfp-neon-poky-linux-gnueabi/arm-poky-linux-gnueabi-g++
export GOROOT=/usr/local/go
export GOPATH=/usr/local/gopath
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
```

#### 验证Go版本

``` bash
go version
# 正常情况会输出如下内容
go version go1.10.3 linux/amd64
```

> 提示：这里打印的版本是amd64，是编译Arm版本Go时附带编译的版本，通过这个版本的Go可以交叉编译出Arm版本的Go应用程序。

#### 编译Helloworld程序

新建helloworld.go 

``` go
package main

import "fmt"

func main() {
	fmt.Println("Hello world")
}
```

编译ARM版本应用程序
```
GOOS=linux GOARCH=arm GOARM=7 go build helloworld.go
```

编译完成之后在当前目录下会生成helloworld，将此文件上传到ARM目标文件系统上执行测试

### 安装VS Code Go开发环境

#### 安装Go语言插件

#### 下载Go原生依赖库

因为Go语言官方依赖库国内不能访问，所以需要在[Github](https://github.com/golang/)上下载Go原生依赖库

下载方法必须使用`git clone`指令，可以参考github仓库里面的[说明文档](https://github.com/golang/image/blob/master/README.md)

#### 安装Go第三方工具

打开vscode,按下`ctrl + shift + p`,在输入框中输入`Go:Install/Update Tools`,单击，勾选所需要的第三方工具，点击`OK`按钮等待安装完成。
