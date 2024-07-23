# 集群规划与环境准备

## 一、架构规划

------

### 1、平台规划

![未命名白板](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/1.png)

### 2、角色分配

| **角色**    | **服务器IP**  | **组件**                                                     | **安装方式** | **系统版本** |
| ----------- | ------------- | ------------------------------------------------------------ | ------------ | ------------ |
| K8s-master1 | 192.168.66.62 | kube-apiserver kube-controller-manager kube-scheduler etcd kubelet kube-proxy docker kube-nginx | 二进制安装   | CentOS 7.8   |
| K8s-master2 | 192.168.66.63 | kube-apiserver kube-controller-manager kube-scheduler etcd kubelet kube-proxy docker kube-nginx | 二进制安装   | CentOS 7.8   |
| K8s-master3 | 192.168.66.64 | kube-apiserver kube-controller-manager kube-scheduler etcd kubelet kube-proxy docker kube-nginx | 二进制安装   | CentOS 7.8   |
| K8s-node1   | 192.168.66.65 | kubelet kube-proxy docker kube-nginx                         | 二进制安装   | CentOS 7.8   |
| K8s-node2   | 192.168.66.66 | Kubelet kube-proxy docker kube-nginx                         | 二进制安装   | CentOS 7.8   |
| K8s-node3   | 192.168.66.67 | Kubelet kube-proxy docker kube-nginx                         | 二进制安装   | CentOS 7.8   |

## 二、系统初始化

------

### 1、配置主机名

- 所有节点执行

```shell
[root@localhost ~]# hostnamectl set-hostname k8s-master1
[root@localhost ~]# hostnamectl set-hostname k8s-master2
[root@localhost ~]# hostnamectl set-hostname k8s-master3
 
[root@localhost ~]# hostnamectl set-hostname k8s-node1
[root@localhost ~]# hostnamectl set-hostname k8s-node2
[root@localhost ~]# hostnamectl set-hostname k8s-node3
```

### 2、配置免密登入

- 先配置主机名称解析

```shell
[root@k8s-master1 ~]# vi /etc/hosts
192.168.66.62 k8s-master1
192.168.66.63 k8s-master2
192.168.66.64 k8s-master3
192.168.66.65 k8s-node1
192.168.66.66 k8s-node2
192.168.66.67 k8s-node3
```

- K8S-master1实现ssh免密登入其他节点

```shell
[root@k8s-master1 ~]# ssh-keygen -t rsa
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.62
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.63
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.64
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.65
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.66
[root@k8s-master1 ~]# ssh-copy-id root@192.168.66.67
```

- 传给各节点,实现通过主机名解析

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67}; do echo ">>> $i";scp /etc/hosts root@$i:/etc/; done
```

- 配置`K8S-Master1`节点通过主机名实现免密登入认证

```shell
[root@k8s-master1 ~]# ssh-copy-id root@k8s-master1
[root@k8s-master1 ~]# ssh-copy-id root@k8s-master2
[root@k8s-master1 ~]# ssh-copy-id root@k8s-master3
[root@k8s-master1 ~]# ssh-copy-id root@k8s-node1
[root@k8s-master1 ~]# ssh-copy-id root@k8s-node2
[root@k8s-master1 ~]# ssh-copy-id root@k8s-node3
```

### 3、关闭防火墙

- 所有节点执行

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67}; do echo ">>> $i";ssh root@$i "systemctl stop firewalld && systemctl disable firewalld && systemctl status firewalld"; done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67}; do echo ">>> $i";ssh root@$i "systemctl stop NetworkManager && systemctl disable NetworkManager && systemctl status NetworkManager"; done
```

### 4、关闭SELinux

- 所有节点执行

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67}; do echo ">>> $i";ssh root@$i "sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config"; done 
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67}; do echo ">>> $i";ssh root@$i "setenforce 0 && getenforce"; done
```

### 5、安装依赖包

- 所有节点执行

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "yum -y install gcc gcc-c++ libaio make cmake zlib-devel openssl-devel pcre pcre-devel wget git curl lynx lftp mailx mutt rsync ntp net-tools vim lrzsz screen sysstat yum-plugin-security yum-utils createrepo bash-completion zip unzip bzip2 tree tmpwatch pinfo man-pages lshw pciutils gdisk system-storage-manager git  gdbm-devel sqlite-devel";done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "yum install -y epel-release";done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git";done
```

### 6、配置时间同步

- master1节点去同步互联网时间，其他节点与master1节点进行时间同步
- chrony服务端节点启动ntpd服务，其余与服务端同步时间的节点停用ntpd服务

```shell
[root@k8s-master1 ~]# vim /etc/chrony.conf
#注意：注释掉默认ntp服务器，我们此处使用阿里云公网ntp服务器
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server ntp3.aliyun.com iburst
server ntp4.aliyun.com iburst
server ntp5.aliyun.com iburst
server ntp6.aliyun.com iburst
server ntp7.aliyun.com iburst
```

![image-20230712160859091](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/2.png)

- 其他节点关闭ntpd服务，我们这里使用`chronyd`服务，如未开启`ntpd`服务，此步骤可忽略！

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{63..67};do echo ">>> $i";ssh root@$i "systemctl stop ntpd && systemctl disable ntpd && systemctl status ntpd";done
```

- 登入各个节点服务器进行手动修改

```shell
vim /etc/chrony.conf
```

![image-20230712160952463](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/3.png)

- 所有节点启动服务，在master1节点操作

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{63..67};do echo ">>> $i";ssh root@$i "systemctl restart chronyd.service && systemctl enable chronyd.service && systemctl status chronyd.service";done
```

- 检查时间同步状态 `^*`表示已经同步，在master1节点操作

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{63..67};do echo ">>> $i";ssh root@$i "chronyc sources ";done
```

![image-20230712161022553](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/4.png)

- 调整系统 TimeZone，在master1节点操作

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "timedatectl set-timezone Asia/Shanghai";done
```

- 将当前的 UTC 时间写入硬件时钟，硬件时间默认为UTC。在master1节点操作
- 使用 Linux 时，最好将硬件时钟设置为 UTC 标准，并在所有操作系统中使用。这样 Linux 系统就可以自动调整夏令时设置，而如果使用 localtime 标准那么系统时间不会根据夏令时自动调整。

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "timedatectl set-local-rtc 0";done
```

- 重启依赖于系统时间的服务，在master1节点操作

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "systemctl restart rsyslog && systemctl restart crond";done
```

### 7、关闭交换分区

**如果不关闭交换分区，会导致K8S服务无法启动**

- 所有节点执行
- 关闭swap

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "swapoff -a && free -h|grep Swap";done
```

- 永久关闭

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "sed -ri 's@/dev/mapper/centos-swap@#/dev/mapper/centos-swap@g' /etc/fstab && grep /dev/mapper/centos-swap /etc/fstab";done
```

### 8、优化系统内核

- 必须关闭 `tcp_tw_recycle`，否则和 NAT 冲突，会导致服务不通；关闭 IPV6，防止触发 docker BUG；
- 注意：我这里内核使用`5.10`，所以`tcp_tw_recycle`参数在linux内核`4.12`版本之后已经移除了`tcp_tw_recycle`参数；如果你还是使用`3.10`的内核那么就必须关闭该参数；3.10内核的话，在下面的配置文件中添加参数：`net.ipv4.tcp_tw_recycle=0`

```shell
[root@k8s-master1 ~]# cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.ipv4.neigh.default.gc_thresh1=1024
net.ipv4.neigh.default.gc_thresh2=2048
net.ipv4.neigh.default.gc_thresh3=4096
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=1048576
fs.file-max=52706963
fs.nr_open=52706963
net.ipv6.conf.all.disable_ipv6=1
net.netfilter.nf_conntrack_max=2310720
EOF
 
[root@k8s-master1 ~]# cat > /etc/modules-load.d/netfilter.conf <<EOF
# Load nf_conntrack.ko at boot
nf_conntrack
EOF
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";scp /etc/modules-load.d/netfilter.conf root@$i:/etc/modules-load.d/;done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";scp /etc/sysctl.d/kubernetes.conf root@$i:/etc/sysctl.d/;done
```

- 重启之后在执行sysctl -p

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{63..67};do echo ">>> $i";ssh root@$i "reboot";done
[root@k8s-master1 ~]# reboot
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "modprobe br_netfilter;sysctl -p /etc/sysctl.d/kubernetes.conf";done
```

### 9、配置环境变量

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "echo 'PATH=/opt/k8s/bin:$PATH' >>/root/.bashrc && source /root/.bashrc";done
```

### 10、创建相关的目录

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "mkdir -p /opt/k8s/{bin,work} /etc/{kubernetes,etcd}/cert";done
```

### 11、关闭无关的服务

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "systemctl stop postfix && systemctl disable postfix";done
```

### 12、升级系统内核

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm";done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "yum --enablerepo=elrepo-kernel install -y kernel-lt";done
```

- 设置开机从新内核启动

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "grub2-set-default 0";done
```

### 13、添加Docker用户

- 在每台服务器上添加Docker用户

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo ">>> $i";ssh root@$i "useradd -m docker";done
 
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo $i;ssh root@$i "id docker";done
```

### 14、配置全局环境变量

- 在所有节点上的profile文件的最后都需要添加下面的参数；注意`集群IP`和`主机名`更改为自己的服务器地址和主机名

```shell
[root@k8s-master1 ~]# vim /etc/profile
#----------------------------K8S-----------------------------#
# 生成 EncryptionConfig 所需的加密 key
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
 
#各机器 IP 数组包含Master与Node节点
export NODE_IPS=(192.168.66.62 192.168.66.63 192.168.66.64 192.168.66.65 192.168.66.66 192.168.66.67)
 
#各机器IP 对应的主机名数组包含Master与Node节点
export NODE_NAMES=(k8s-master1 k8s-master2 k8s-master3 k8s-node1 k8s-node2 k8s-node3)
 
# Master集群节点IP
export MASTER_IPS=(192.168.66.62 192.168.66.63 192.168.66.64)
 
# WORK集群数组IP
export WORK_IPS=(192.168.66.65 192.168.66.66 192.168.66.67)
 
# WORK集群IP对应主机名数组
export WORK_NAMES=(k8s-node1 k8s-node2 k8s-node3)
 
#ETCD集群IP数组
export ETCD_IPS=(192.168.66.62 192.168.66.63 192.168.66.64)
 
# ETCD集群节点IP对应主机名数组
export ETCD_NAMES=(k8s-master1 k8s-master2 k8s-master3)
 
# etcd 集群服务地址列表；注意IP地址根据自己的ETCD集群服务器地址填写
export ETCD_ENDPOINTS="https://192.168.66.62:2379,https://192.168.66.63:2379,https://192.168.66.64:2379"
 
# etcd 集群间通信的 IP 和端口；注意此处改为自己的实际ETCD所在服务器主机名
export ETCD_NODES="k8s-master1=https://192.168.66.62:2380,k8s-master2=https://192.168.66.63:2380,k8s-master3=https://192.168.66.64:2380"
 
# kube-apiserver 的反向代理(kube-nginx)地址端口
export KUBE_APISERVER="https://127.0.0.1:8443"
 
# 节点间互联网络接口名称；根据自己服务器网卡实际名称进行修改
export IFACE="ens33"
 
# etcd 数据目录
export ETCD_DATA_DIR="/data/k8s/etcd/data"
 
# etcd WAL 目录，建议是 SSD 磁盘分区，或者和 ETCD_DATA_DIR 不同的磁盘分区
export ETCD_WAL_DIR="/data/k8s/etcd/wal"
 
# k8s 各组件数据目录
export K8S_DIR="/data/k8s/k8s"
 
## DOCKER_DIR 和 CONTAINERD_DIR 二选一
# docker 数据目录
export DOCKER_DIR="/data/k8s/docker"
 
# containerd 数据目录
export CONTAINERD_DIR="/data/k8s/containerd"
 
## 以下参数一般不需要修改
# TLS Bootstrapping 使用的 Token，可以使用命令 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
BOOTSTRAP_TOKEN="41f7e4ba8b7be874fcff18bf5cf41a7c"
 
# 最好使用 当前未用的网段 来定义服务网段和 Pod 网段
# 服务网段，部署前路由不可达，部署后集群内路由可达(kube-proxy 保证)
SERVICE_CIDR="10.254.0.0/16"
 
# Pod 网段，建议 /16 段地址，部署前路由不可达，部署后集群内路由可达(flanneld 保证)
CLUSTER_CIDR="172.30.0.0/16"
 
# 服务端口范围 (NodePort Range)
export NODE_PORT_RANGE="30000-32767"
 
# kubernetes 服务 IP (一般是 SERVICE_CIDR 中第一个IP)
export CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"
 
# 集群 DNS 服务 IP (从 SERVICE_CIDR 中预分配)
export CLUSTER_DNS_SVC_IP="10.254.0.2"
 
# 集群 DNS 域名（末尾不带点号）
export CLUSTER_DNS_DOMAIN="cluster.local"
 
# 将二进制目录 /opt/k8s/bin 加到 PATH 中
export PATH=/opt/k8s/bin:$PATH
```

- 将配置传给各Master集群节点和ETCD集群和worker节点服务器

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{62..67};do echo $i;scp /etc/profile root@$i:/etc/;done
 
#最后登入各个节点执行以下命令使其生效
source /etc/profile
```

### 15、重启服务器

```shell
[root@k8s-master1 ~]# for i in 192.168.66.{63..67};do echo $i;ssh root@$i "sync && reboot";done
```

- 最后重启K8S-Master1节点

```shell
[root@k8s-master1 ~]# sync && reboot
```

## 三、创建CA根证书和秘钥

------

- 将该证书分发至所有节点，包括master和node

### 1、安装cfssl工具集

**注意：** 所有命令和文件在k8s-master1上在执行，然后将文件分发给其他节点

```shell
[root@k8s-master1 ~]# mkdir -p /opt/k8s/cert && cd /opt/k8s
 
[root@k8s-master1 k8s]# wget https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64 
[root@k8s-master1 k8s]# mv cfssl_1.4.1_linux_amd64 /opt/k8s/bin/cfssl
 
[root@k8s-master1 k8s]# wget https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64 
[root@k8s-master1 k8s]# mv cfssljson_1.4.1_linux_amd64 /opt/k8s/bin/cfssljson
 
[root@k8s-master1 k8s]# wget https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl-certinfo_1.4.1_linux_amd64 
[root@k8s-master1 k8s]# mv cfssl-certinfo_1.4.1_linux_amd64 /opt/k8s/bin/cfssl-certinfo
 
[root@k8s-master1 k8s]# chmod +x /opt/k8s/bin/*
[root@k8s-master1 k8s]# export PATH=/opt/k8s/bin:$PATH
```

### 2、创建根证书(CA)

2.1：创建配置文件

```shell
[root@k8s-master1 k8s]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF
```

2.2：创建证书签名请求文件

```shell
[root@k8s-master1 work]# cat > ca-csr.json <<EOF
{
  "CN": "kubernetes-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "dqz"
    }
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF
```

2.3：生成CA证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -initca ca-csr.json | cfssljson -bare ca
[root@k8s-master1 work]# ls ca*
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

### 3、分发证书文件

- 将生成的 CA 证书、秘钥文件、配置文件拷贝到所有节点的 `/etc/kubernetes/cert` 目录下：

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp ca*.pem ca-config.json root@${node_ip}:/etc/kubernetes/cert
  done
```

## 四、部署ETCD集群

------

### 1、下载和分发 etcd 二进制文件

- **注意：** 我这里ETCD与K8S-Master集群节点都在同一机器上部署的

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/
[root@k8s-master1 work]# tar -zxvf etcd-v3.4.10-linux-amd64.tar.gz
 
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-v3.4.10-linux-amd64/etcd* root@${node_ip}:/opt/k8s/bin
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done 
```

### 2、创建 etcd 证书和私钥

2.1：创建证书签名请求

- 注意：这里的IP地址一定要根据自己的实际ETCD集群IP填写

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "192.168.66.62",
    "192.168.66.63",
    "192.168.66.64"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "dqz"
    }
  ]
}
EOF
```

2.2：生成证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
    -ca-key=/opt/k8s/work/ca-key.pem \
    -config=/opt/k8s/work/ca-config.json \
    -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
 
[root@k8s-master1 work]# ls etcd*pem
etcd-key.pem  etcd.pem
```

2.3：分发证书和私钥至各etcd节点

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/etcd/cert"
    scp etcd*.pem root@${node_ip}:/etc/etcd/cert/
  done
```

### 3、创建 etcd 的 systemd unit 模板文件

```shell
[root@k8s-master1 work]# cat > etcd.service.template <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos
 
[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
ExecStart=/opt/k8s/bin/etcd \\
  --data-dir=${ETCD_DATA_DIR} \\
  --wal-dir=${ETCD_WAL_DIR} \\
  --name=##ETCD_NAME## \\
  --cert-file=/etc/etcd/cert/etcd.pem \\
  --key-file=/etc/etcd/cert/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-cert-file=/etc/etcd/cert/etcd.pem \\
  --peer-key-file=/etc/etcd/cert/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://##ETCD_IP##:2380 \\
  --initial-advertise-peer-urls=https://##ETCD_IP##:2380 \\
  --listen-client-urls=https://##ETCD_IP##:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://##ETCD_IP##:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --auto-compaction-mode=periodic \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=33554432 \\
  --quota-backend-bytes=6442450944 \\
  --heartbeat-interval=250 \\
  --election-timeout=2000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
```

### 4、为各ETCD节点创建和分发 etcd systemd unit 文件

4.1：替换模板文件中的变量

```shell
[root@k8s-master1 work]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##ETCD_NAME##/${ETCD_NAMES[i]}/" -e "s/##ETCD_IP##/${ETCD_IPS[i]}/" etcd.service.template > etcd-${ETCD_IPS[i]}.service 
  done
 
[root@k8s-master1 work]# ls *.service
etcd-192.168.66.62.service  etcd-192.168.66.63.service  etcd-192.168.66.64.service
```

4.2：分发生成的 systemd unit 文件

- 文件重命名为 etcd.service;

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp etcd-${node_ip}.service root@${node_ip}:/etc/systemd/system/etcd.service
  done
```

4.3：检查配置文件

```shell
[root@k8s-master1 work]# ls /etc/systemd/system/etcd.service 
/etc/systemd/system/etcd.service
[root@k8s-master1 work]# vim /etc/systemd/system/etcd.service
```

- 确认脚本文件中的IP地址和数据存储地址是否都正确

### 5、启动ETCD服务

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${ETCD_DATA_DIR} ${ETCD_WAL_DIR} && chmod 0700 /data/k8s/etcd/data"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd"
  done
```

### 6、检查启动结果

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status etcd|grep Active"
  done
```

- 确保启动后没有报错，注意：状态为running并不代表ETCD各节点之间通信正常

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status etcd"
  done
```

### 7、验证服务状态

7.1：任一etcd节点执行以下命令

```shell
[root@k8s-master1 work]# for node_ip in ${ETCD_IPS[@]}
  do
    echo ">>> ${node_ip}"
    /opt/k8s/bin/etcdctl \
    --endpoints=https://${node_ip}:2379 \
    --cacert=/etc/kubernetes/cert/ca.pem \
    --cert=/etc/etcd/cert/etcd.pem \
    --key=/etc/etcd/cert/etcd-key.pem endpoint health
  done
```

- 各服务节点全部为`healthy`，则代表etcd集群状态正常

![image-20230712161740992](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/5.png)

### 8、查看当前leader

```shell
[root@k8s-master1 work]# /opt/k8s/bin/etcdctl \
  -w table --cacert=/opt/k8s/work/ca.pem \
  --cert=/etc/etcd/cert/etcd.pem \
  --key=/etc/etcd/cert/etcd-key.pem \
  --endpoints=${ETCD_ENDPOINTS} endpoint status
```

- 可以看到当前ETCD集群leader为：192.168.66.63这台服务器

![image-20230712164425757](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之集群规划与环境准备/6.png)

## 五、部署kubectl命令行工具

------

### 1、下载和分发 kubectl 二进制文件

- 我这里直接将下载好二进制包上传至所有服务器节点中
- [ **下载链接** ](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.18.md#downloads-for-v1186)

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# tar -zxvf kubernetes-client-linux-amd64.tar.gz
kubernetes/
kubernetes/client/
kubernetes/client/bin/
kubernetes/client/bin/kubectl
```

- 分发到其他Master集群node节点

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/client/bin/kubectl root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

### 2、创建admin证书和私钥

2.1：创建证书签名请求

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "dqz"
    }
  ]
}
EOF
```

2.2：生成证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes admin-csr.json | cfssljson -bare admin
 
[root@k8s-master1 work]# ls admin*
admin.csr  admin-csr.json  admin-key.pem  admin.pem
```

### 3、创建 kubeconfig 文件

- 设置集群参数

```
[root@k8s-master1 work]# kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kubectl.kubeconfig
```

- 设置客户端参数

```
[root@k8s-master1 work]# kubectl config set-credentials admin \
  --client-certificate=/opt/k8s/work/admin.pem \
  --client-key=/opt/k8s/work/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=kubectl.kubeconfig 
```

- 设置上下文参数

```shell
[root@k8s-master1 work]# kubectl config set-context kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=kubectl.kubeconfig 
```

- 设置默认上下文

```
[root@k8s-master1 work]# kubectl config use-context kubernetes --kubeconfig=kubectl.kubeconfig 
```

### 4、分发kubeconfig文件

```
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ~/.kube"
    scp kubectl.kubeconfig root@${node_ip}:~/.kube/config
  done 
```

### 5、确认kubectl已经可以使用

- 确保Master节点和Work节点的kubectl命令都可以使用

```
[root@k8s-master1 work]# kubectl --help
```