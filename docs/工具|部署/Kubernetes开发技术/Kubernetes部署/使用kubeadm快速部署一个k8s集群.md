# 使用kubeadm快速部署一个k8s集群

kubeadm是官方社区推出的一个用于快速部署kubernetes集群的工具，能通过简单的指令完成一个kubernetes集群的部署。

## 1. 安装要求

在开始之前，部署Kubernetes集群机器需要满足以下几个条件：

- 一台或多台机器，操作系统 CentOS7.x-86_x64
- 硬件配置：2GB或更多RAM，2个CPU或更多CPU，硬盘30GB或更多
- 可以访问外网，需要拉取镜像，如果服务器不能上网，需要提前下载镜像并导入节点
- 禁用swap分区

更详细的信息请查看[官方指导](https://v1-18.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#before-you-begin)

## 2. 准备环境

| 角色        | IP            |
| ----------- | ------------- |
| K8s-master1 | 192.168.66.62 |
| K8s-node1   | 192.168.66.63 |
| K8s-node2   | 192.168.66.64 |

```bash
# 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 关闭selinux
setenforce 0                                          # 临时
sed -i 's/enforcing/permissive/' /etc/selinux/config  # 永久

# 关闭swap
swapoff -a                             # 临时
sed -ri 's/.*swap.*/#&/' /etc/fstab    # 永久

# 根据规划设置主机名
hostnamectl set-hostname <hostname>

# 添加hosts
cat >> /etc/hosts << EOF
192.168.66.62 K8s-master1
192.168.66.63 K8s-node1
192.168.66.64 K8s-node2
EOF

# 将桥接的IPv4流量传递到iptables的链
# https://v1-18.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#letting-iptables-see-bridged-traffic
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system  # 生效

# 时间同步(可选)
yum install ntpdate -y
ntpdate time.windows.com
```

## 3. 所有节点安装Docker/kubeadm/kubelet

Kubernetes默认CRI（容器运行时）为Docker，因此先安装Docker。

### 3.1 安装Docker

```bash
# 尽量不要使用centos镜像源自带的docker(版本1.13太低), 与教程保持版本一致
# https://developer.aliyun.com/mirror/docker-ce
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce-18.06.1.ce-3.el7
systemctl enable docker && systemctl start docker

# 使用阿里云ACR的加速服务
# https://help.aliyun.com/document_detail/60750.html
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://h35bbdsw.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 3.2 安装kubeadm，kubelet和kubectl

```bash
# 使用阿里云镜像加速安装kubeadm，kubelet和kubectl
# https://developer.aliyun.com/mirror/kubernetes
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# 由于版本更新频繁，这里指定版本号部署：
yum install -y kubelet-1.18.0 kubeadm-1.18.0 kubectl-1.18.0
systemctl enable kubelet && systemctl start kubelet
```

## 4. 部署Kubernetes Master

- 在192.168.66.62(k8s-master1)执行, 注意--apiserver-advertise-address=和--image-repository要替换成node1的IP和阿里云加速源

```lua
kubeadm init \
  --apiserver-advertise-address=192.168.66.62 \
  --image-repository registry.aliyuncs.com/google_containers \
  --kubernetes-version v1.18.0 \
  --service-cidr=10.96.0.0/12 \
  --pod-network-cidr=10.244.0.0/16
```

由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址。

- 创建k8ss所需配置文件

```
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- 查看k8s节点

```shell
kubectl get nodes 
```

## 5. 加入Kubernetes Node

在192.168.66.63/64（k8s-node1/k8s-node2）执行。

向集群添加新节点，执行在kubeadm init输出的kubeadm join命令：

```sql
kubeadm join 192.168.66.62:6443 --token esce21.q6hetwm8si29qxwn \
  --discovery-token-ca-cert-hash sha256:00603a05805807501d7181c3d60b478788408cfe6cedefedb1f97569708be9c5
```

**默认token有效期为24小时，当过期之后，该token就不可用了。这时就需要重新创建token** ，操作如下：

```lua
kubeadm token create --print-join-command
```

## 6. 部署CNI网络插件

```ruby
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl get pods -n kube-system
NAME                          READY   STATUS    RESTARTS   AGE
kube-flannel-ds-amd64-2pc95   1/1     Running   0          72s
```

- 大概率kube-flannel.yml是无法直接下载, 可以挂科学工具下载到本地执行;
- 默认镜像地址无法访问，sed命令修改为docker hub镜像仓库, 也可以下载到本地导入;

## 7. 测试kubernetes集群

在Kubernetes集群中创建一个pod，验证是否正常运行：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
    spec:
      containers:
      - name: busybox-container
        image: busybox
        command: ["sleep", "3600"]
```

```shell
kubectl get pod,svc
```

