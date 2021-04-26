# 记一次apt-get install gcc-multilib失败的小坑

因为做题中要把源码下在本机（kali_64）编译一下，命令为gcc -o xxx xxx.c -m32 -lm发现gcc缺少32位的环境
网上查询使用命令apt-get install gcc-multilib，但是遇到各种报错如:E: Package 'gcc-multilib' has no installation candidate，按照错误代码查询了一个多小时无果，最后把gcc给卸了准备重装，发现gcc也装不上了，才发现原来是kali的更新源出了问题。
最后修改更新源文件，成功安装编译，过程如下
1.备份源列表(之前没用的话也可以不备份)

```shell
sudo cp /etc/apt/sources.list /etc/apt/sources.list_backup
```

2.打开sources.list文件修改

```shell
sudo vim /etc/apt/sources.list

#中科大
deb http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib
deb-src http://mirrors.ustc.edu.cn/kali kali-rolling main non-free contrib
 
#阿里云
deb http://mirrors.aliyun.com/kali kali-rolling main non-free contrib
deb-src http://mirrors.aliyun.com/kali kali-rolling main non-free contrib
 
#清华大学
deb http://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main contrib non-free
deb-src https://mirrors.tuna.tsinghua.edu.cn/kali kali-rolling main contrib non-free
```

复制其中一个，我这里复制的是阿里的源
vim按`a`键入`Shift+insert`粘贴再按`esc`输入`:w`保存再输入`:q`退出



3.保存后之后回到命令行下执行命令：

```shell
apt-get update && apt-get upgrade && apt-get dist-upgrade
```

完成更新
之后就能使用上面所说的各种命令了
