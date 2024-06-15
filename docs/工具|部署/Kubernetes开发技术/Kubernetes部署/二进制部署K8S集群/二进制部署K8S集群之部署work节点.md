## 部署Worker节点

**kubernetes worker 节点运行如下组件**

- docker
- kubelet
- kube-proxy
- calico
- kube-nginx

**注意：**

1. k8s-master1实现与其他work节点免密认证
2. 特别说明：部署的组件是在所有节点都进行部署，包括master和worker节点
3. 如果未注明，则所有操作在`k8s-master1`节点进行远程操作集群中的work节点

## 1、安装依赖包

- 所有节点安装对应依赖包，所有操作均在k8s-master1节点操作

```shell
[root@k8s-master1 ~]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "yum install -y epel-release"
    ssh root@${node_ip} "yum install -y chrony conntrack ipvsadm ipset jq iptables curl sysstat libseccomp wget socat git"
  done
```

## 2、部署docker

### 2.1、下载和分发 Docker 二进制文件

#### 2.1.1：下载程序包

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/
[root@k8s-master1 work]# wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz
[root@k8s-master1 work]# tar -xzvf docker-19.03.9.tgz
```

#### 2.1.2：分发程序包

- 将程序包分发给各个所有节点

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker/*  root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

### 3.2、创建和分发 systemd unit 文件

#### 3.2.1：创建systemd unit 文件

```shell
[root@k8s-master1 work]# cat > docker.service <<"EOF"
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io
 
[Service]
WorkingDirectory=##DOCKER_DIR##
Environment="PATH=/opt/k8s/bin:/bin:/sbin:/usr/bin:/usr/sbin"
ExecStart=/opt/k8s/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
 
[Install]
WantedBy=multi-user.target
EOF
```

- 更改`IPTABLES`防火墙策略

```shell
[root@k8s-master1 work]# for i in 192.168.66.{65..67}; do echo ">>> $i";ssh root@$i "iptables -P FORWARD ACCEPT"; done
 
[root@k8s-master1 work]# for i in 192.168.66.{65..67}; do echo ">>> $i";ssh root@$i "echo '/sbin/iptables -P FORWARD ACCEPT' >> /etc/rc.local"; done
```

#### 3.2.2：分发 systemd unit 文件到所有 worker 机器

```shell
[root@k8s-master1 work]# sed -i -e "s|##DOCKER_DIR##|${DOCKER_DIR}|" docker.service
 
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp docker.service root@${node_ip}:/etc/systemd/system/
  done
```

### 3.3：配置和分发 docker 配置文件

- 使用国内的仓库镜像服务器以加快 pull image 的速度，同时增加下载的并发数 (需要重启 dockerd 生效)

#### 3.3.1：配置docker加速

- 由于网络环境原因。默认去下载官方的docker hub会下载失败所以使用阿里云的docker加速器
- 登入自己的阿里云生成docker.json，[阿里云镜像地址](https://www.dqzboy.com/go/?url=https://cr.console.aliyun.com/cn-hangzhou/instances/repositories)

```shell
[root@k8s-master1 work]# cat > docker-daemon.json <<EOF
{
    "registry-mirrors": ["https://a7ye1cuu.mirror.aliyuncs.com","https://docker.mirrors.ustc.edu.cn","https://hub-mirror.c.163.com"],
    "insecure-registries": ["docker02:35000"],
    "max-concurrent-downloads": 20,
    "live-restore": true,
    "max-concurrent-uploads": 10,
    "debug": true,
    "data-root": "${DOCKER_DIR}/data",
    "exec-root": "${DOCKER_DIR}/exec",
    "log-opts": {
      "max-size": "100m",
      "max-file": "5"
    }
}
EOF
```

#### 3.3.2：分发至work节点

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p  /etc/docker/ ${DOCKER_DIR}/{data,exec}"
    scp docker-daemon.json root@${node_ip}:/etc/docker/daemon.json
  done
```

### 3.4：启动 docker 服务

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
  done
```

### 3.5：检查服务运行状态

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status docker|grep Active"
  done
```

### 3.6：检查 docker0 网桥

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "/usr/sbin/ip addr show docker0"
  done
```

## 4、部署 kubelet 组件

### 4.1、创建 kubelet bootstrap kubeconfig 文件

#### 4.1.1：创建文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
 
    # 创建 token
    export BOOTSTRAP_TOKEN=$(kubeadm token create \
      --description kubelet-bootstrap-token \
      --groups system:bootstrappers:${node_name} \
      --kubeconfig ~/.kube/config)
 
    # 设置集群参数
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
 
    # 设置客户端认证参数
    kubectl config set-credentials kubelet-bootstrap \
      --token=${BOOTSTRAP_TOKEN} \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
 
    # 设置上下文参数
    kubectl config set-context default \
      --cluster=kubernetes \
      --user=kubelet-bootstrap \
      --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
 
    # 设置默认上下文
    kubectl config use-context default --kubeconfig=kubelet-bootstrap-${node_name}.kubeconfig
  done
```

#### 4.1.2：查看 kubeadm 为各节点创建的 token

```
[root@k8s-node1 work]# kubeadm token list --kubeconfig ~/.kube/config
```

#### 4.1.3：查看各 token 关联的 Secret

```
[root@k8s-master1 work]# kubectl get secrets  -n kube-system|grep bootstrap-token
```

4.2、分发 bootstrap kubeconfig 文件到所有 worker 节点

```shell
[root@k8s-master1 work]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
    scp kubelet-bootstrap-${node_name}.kubeconfig root@${node_name}:/etc/kubernetes/kubelet-bootstrap.kubeconfig
  done
```

### 4.3、创建和分发 kubelet 参数配置文件

#### 4.3.1：创建 kubelet 参数配置模板文件

- **注意：**需要 root 账户运行

```shell
[root@k8s-master1 work]# cat <<EOF | tee kubelet-config.yaml.template
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/cert/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
podCIDR: "${CLUSTER_CIDR}"
maxPods: 220
serializeImagePulls: false
hairpinMode: promiscuous-bridge
cgroupDriver: cgroupfs
runtimeRequestTimeout: "15m"
rotateCertificates: true
serverTLSBootstrap: true
readOnlyPort: 0
port: 10250
address: "##NODE_IP##"
EOF
```

#### 4.3.2：为各节点创建和分发 kubelet 配置文件

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do 
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" kubelet-config.yaml.template > kubelet-config-${node_ip}.yaml.template
    scp kubelet-config-${node_ip}.yaml.template root@${node_ip}:/etc/kubernetes/kubelet-config.yaml
  done
```

### 4.4、创建和分发 kubelet systemd unit 文件

#### 4.4.1：创建 kubelet systemd unit 文件模板

```shell
[root@k8s-master1 work]# cat > kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
 
[Service]
WorkingDirectory=${K8S_DIR}/kubelet
ExecStart=/opt/k8s/bin/kubelet \\
  --bootstrap-kubeconfig=/etc/kubernetes/kubelet-bootstrap.kubeconfig \\
  --cert-dir=/etc/kubernetes/cert \\
  --network-plugin=cni \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/k8s/bin \\
  --root-dir=${K8S_DIR}/kubelet \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --config=/etc/kubernetes/kubelet-config.yaml \\
  --hostname-override=##NODE_NAME## \\
  --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/hu279318344/pause-amd64:3.1 \\
  --image-pull-progress-deadline=15m \\
  --volume-plugin-dir=${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/ \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0
 
[Install]
WantedBy=multi-user.target
EOF
```

#### 4.4.2：为各节点创建和分发 kubelet systemd unit 文件

```shell
[root@k8s-master1 work]# for node_name in ${NODE_NAMES[@]}
  do 
    echo ">>> ${node_name}"
    sed -e "s/##NODE_NAME##/${node_name}/" kubelet.service.template > kubelet-${node_name}.service
    scp kubelet-${node_name}.service root@${node_name}:/etc/systemd/system/kubelet.service
  done
```

### 4.5、授予 kube-apiserver 访问 kubelet API 的权限

```shell
[root@k8s-master1 work]# kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes-master
 
clusterrolebinding.rbac.authorization.k8s.io/kube-apiserver:kubelet-apis created
```

### 4.6、Bootstrap Token Auth 和授予权限

```shell
[root@k8s-master1 work]# kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers
 
clusterrolebinding.rbac.authorization.k8s.io/kubelet-bootstrap created
```

### 4.7、自动 approve CSR 请求，生成 kubelet client 证书

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > csr-crb.yaml <<EOF
 # Approve all CSRs for the group "system:bootstrappers"
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: auto-approve-csrs-for-group
 subjects:
 - kind: Group
   name: system:bootstrappers
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:nodeclient
   apiGroup: rbac.authorization.k8s.io
---
 # To let a node of the group "system:nodes" renew its own credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-client-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: system:certificates.k8s.io:certificatesigningrequests:selfnodeclient
   apiGroup: rbac.authorization.k8s.io
---
# A ClusterRole which instructs the CSR approver to approve a node requesting a
# serving cert matching its client cert.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: approve-node-server-renewal-csr
rules:
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/selfnodeserver"]
  verbs: ["create"]
---
 # To let a node of the group "system:nodes" renew its own server credentials
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: node-server-cert-renewal
 subjects:
 - kind: Group
   name: system:nodes
   apiGroup: rbac.authorization.k8s.io
 roleRef:
   kind: ClusterRole
   name: approve-node-server-renewal-csr
   apiGroup: rbac.authorization.k8s.io
EOF
 
[root@k8s-master1 work]# kubectl apply -f csr-crb.yaml
```

### 4.8、启动 kubelet 服务

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kubelet"
    ssh root@${node_ip} "/usr/sbin/swapoff -a"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet"
  done
```

### 4.9、查看kubelet情况

- 稍等一会，三个节点的 CSR 都被自动 `approved`
- `Pending 的 CSR `用于创建 kubelet server 证书

```shell
[root@k8s-master1 work]# kubectl get csr
```

- 所有节点均注册（Ready 状态是预期的，现在查看状态显示为`NotReady`为正常想象，因为没有部署网络插件，后续安装了网络插件后就好）

```shell
[root@k8s-master1 work]# kubectl get node
NAME          STATUS         ROLES    AGE   VERSION
k8s-node1   NotReady    <none>   18h   v1.18.6
k8s-node2   NotReady    <none>   18h   v1.18.6
k8s-node3   NotReady    <none>   18h   v1.18.6
```

- kube-controller-manager 为各 node 生成了 kubeconfig 文件和公私钥
- 注意在node节点执行以下命令查看

```shell
ls -l /etc/kubernetes/kubelet.kubeconfig
ls -l /etc/kubernetes/cert/kubelet-client-*
```

- 可以看到没有自动生成 `kubelet server` 证书文件

### 4.10、手动 approve server cert csr

- 基于安全性考虑，CSR approving controllers 不会自动 approve kubelet server 证书签名请求，需要手动 approve

```shell
[root@k8s-master1 ~]# kubectl get csr
```

- 手动approve

```shell
[root@k8s-master1 ~]# kubectl get csr | grep Pending | awk '{print $1}' | xargs kubectl certificate approve
```

- 在node节点查看，自动生成了server证书

```shell
ls -l /etc/kubernetes/cert/kubelet-*
```

### 4.11、kubelet api 认证和授权

```shell
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem https://192.168.66.65:10250/metrics
Unauthorized
 
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem https://192.168.66.66:10250/metrics
Unauthorized
 
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem https://192.168.66.67:10250/metrics
Unauthorized
 
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem -H "Authorization: Bearer 123456" https://192.168.66.65:10250/metrics
Unauthorized
```

### 4.12、证书认证和授权

- 权限不足的证书

```shell
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem --cert /etc/kubernetes/cert/kube-controller-manager.pem --key /etc/kubernetes/cert/kube-controller-manager-key.pem https://192.168.66.65:10250/metrics
 
Forbidden (user=system:kube-controller-manager, verb=get, resource=nodes, subresource=metrics)
```

- 使用部署 kubectl 命令行工具时创建的、具有最高权限的 admin 证书；

```shell
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem --cert /opt/k8s/work/admin.pem --key /opt/k8s/work/admin-key.pem https://192.168.66.65:10250/metrics|head
```

### 4.13、bear token 认证和授权

- 创建一个 ServiceAccount，将它和 ClusterRole system:kubelet-api-admin 绑定，从而具有调用 kubelet API 的权限；

```shell
[root@k8s-master1 ~]# kubectl create sa kubelet-api-test
 
serviceaccount/kubelet-api-test created
 
[root@k8s-master1 ~]# kubectl create clusterrolebinding kubelet-api-test --clusterrole=system:kubelet-api-admin --serviceaccount=default:kubelet-api-test
 
clusterrolebinding.rbac.authorization.k8s.io/kubelet-api-test created
 
[root@k8s-master1 ~]# SECRET=$(kubectl get secrets | grep kubelet-api-test | awk '{print $1}')
[root@k8s-master1 ~]# TOKEN=$(kubectl describe secret ${SECRET} | grep -E '^token' | awk '{print $2}')
[root@k8s-master1 ~]# echo ${TOKEN}
 
[root@k8s-master1 ~]# curl -s --cacert /etc/kubernetes/cert/ca.pem -H "Authorization: Bearer ${TOKEN}" https://192.168.66.65:10250/metrics |head
 
# HELP apiserver_audit_event_total [ALPHA] Counter of audit events generated and sent to the audit backend.
# TYPE apiserver_audit_event_total counter
apiserver_audit_event_total 0
# HELP apiserver_audit_requests_rejected_total [ALPHA] Counter of apiserver requests rejected due to an error in audit logging backend.
# TYPE apiserver_audit_requests_rejected_total counter
apiserver_audit_requests_rejected_total 0
# HELP apiserver_client_certificate_expiration_seconds [ALPHA] Distribution of the remaining lifetime on the certificate used to authenticate a request.
# TYPE apiserver_client_certificate_expiration_seconds histogram
apiserver_client_certificate_expiration_seconds_bucket{le="0"} 0
apiserver_client_certificate_expiration_seconds_bucket{le="1800"} 0
```

## 5、部署 kube-proxy 组件

- kube-proxy 运行在所有 worker 节点上，它监听 apiserver 中 `service` 和 `endpoint` 的变化情况，创建路由规则以提供服务 IP 和负载均衡功能。
- 以下操作没有特殊说明，则全部在k8s-master1节点通过远程调用进行操作

### 5.1：创建 kube-proxy 证书

#### 5.1.1：创建证书签名请求

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
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

#### 5.1.2：生成证书和私钥

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy
 
[root@k8s-master1 work]# ls kube-proxy*
kube-proxy.csr  kube-proxy-csr.json  kube-proxy-key.pem  kube-proxy.pem
```

### 5.2：创建和分发 kubeconfig 文件

#### 5.2.1：创建kubeconfig文件

```shell
[root@k8s-master1 work]# kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
 
[root@k8s-master1 work]# kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
 
[root@k8s-master1 work]# kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
 
[root@k8s-master1 work]# kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

#### 5.2.2：分发kubeconfig文件

- 分发至所有work节点机器

```shell
[root@k8s-master1 work]# for node_name in ${NODE_NAMES[@]}
  do
    echo ">>> ${node_name}"
    scp kube-proxy.kubeconfig root@${node_name}:/etc/kubernetes/
  done
```

### 5.3：创建 kube-proxy 配置文件

#### 5.3.1：创建 kube-proxy config 文件模板

```shell
[root@k8s-master1 work]# cat > kube-proxy-config.yaml.template <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-proxy.kubeconfig"
  qps: 100
bindAddress: ##NODE_IP##
healthzBindAddress: ##NODE_IP##:10256
metricsBindAddress: ##NODE_IP##:10249
enableProfiling: true
clusterCIDR: ${CLUSTER_CIDR}
hostnameOverride: ##NODE_NAME##
mode: "ipvs"
portRange: ""
iptables:
  masqueradeAll: false
ipvs:
  scheduler: rr
  excludeCIDRs: []
EOF
```

#### 5.3.2：为各节点创建和分发 kube-proxy 配置文件

```shell
[root@k8s-master1 work]# for (( i=0; i < 6; i++ ))
  do 
    echo ">>> ${NODE_NAMES[i]}"
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${NODE_IPS[i]}/" kube-proxy-config.yaml.template > kube-proxy-config-${NODE_NAMES[i]}.yaml.template
    scp kube-proxy-config-${NODE_NAMES[i]}.yaml.template root@${NODE_NAMES[i]}:/etc/kubernetes/kube-proxy-config.yaml
  done
```

### 5.4：创建和分发 kube-proxy systemd unit 文件

#### 5.4.1：创建文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
 
[Service]
WorkingDirectory=${K8S_DIR}/kube-proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
  --config=/etc/kubernetes/kube-proxy-config.yaml \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
```

#### 5.4.2：分发文件

```shell
[root@k8s-master1 work]# for node_name in ${NODE_NAMES[@]}
  do 
    echo ">>> ${node_name}"
    scp kube-proxy.service root@${node_name}:/etc/systemd/system/
  done
```

### 5.5：启动kube-proxy服务

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-proxy"
    ssh root@${node_ip} "modprobe ip_vs_rr"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy"
  done
```

### 5.6：检查启动结果

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-proxy|grep Active"
  done
```

### 5.7：查看监听端口

- 登入各个work节点执行以下命令查看kube-proxy服务启动状况

```shell
[root@k8s-node1 ~]# netstat -lnpt|grep kube-prox
tcp        0      0 192.168.66.65:10249     0.0.0.0:*               LISTEN      35911/kube-proxy    
tcp        0      0 192.168.66.65:10256     0.0.0.0:*               LISTEN      35911/kube-proxy
```

### 5.8：查看 ipvs 路由规则

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "/usr/sbin/ipvsadm -ln"
  done

>>> 192.168.66.62
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.63
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.64
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0  
>>> 192.168.66.65
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.66
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0         
>>> 192.168.66.67
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.254.0.1:443 rr
  -> 192.168.66.62:6443           Masq    1      0          0         
  -> 192.168.66.63:6443           Masq    1      0          0         
  -> 192.168.66.64:6443           Masq    1      0          0   
```

- 可见所有通过 https 访问 K8S SVC kubernetes 的请求都转发到 kube-apiserver 节点的 6443 端口

## 6、CNI插件部署

### 6.1 flannel插件部署

#### 6.1.1 k8s部署flannel插件

```yaml
---
kind: Namespace
apiVersion: v1
metadata:
  name: kube-flannel
  labels:
    k8s-app: flannel
    pod-security.kubernetes.io/enforce: privileged
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: flannel
  name: flannel
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes/status
  verbs:
  - patch
- apiGroups:
  - networking.k8s.io
  resources:
  - clustercidrs
  verbs:
  - list
  - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    k8s-app: flannel
  name: flannel
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: flannel
subjects:
- kind: ServiceAccount
  name: flannel
  namespace: kube-flannel
---
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: flannel
  name: flannel
  namespace: kube-flannel
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kube-flannel-cfg
  namespace: kube-flannel
  labels:
    tier: node
    k8s-app: flannel
    app: flannel
data:
  cni-conf.json: |
    {
      "name": "cbr0",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "hairpinMode": true,
            "isDefaultGateway": true
          }
        },
        {
          "type": "portmap",
          "capabilities": {
            "portMappings": true
          }
        }
      ]
    }
  net-conf.json: |
    {
      "Network": "172.30.0.0/16",
      "Backend": {
        "Type": "vxlan"
      }
    }
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kube-flannel-ds
  namespace: kube-flannel
  labels:
    tier: node
    app: flannel
    k8s-app: flannel
spec:
  selector:
    matchLabels:
      app: flannel
  template:
    metadata:
      labels:
        tier: node
        app: flannel
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
      hostNetwork: true
      priorityClassName: system-node-critical
      tolerations:
      - operator: Exists
        effect: NoSchedule
      serviceAccountName: flannel
      initContainers:
      - name: install-cni-plugin
        image: docker.io/flannel/flannel-cni-plugin:v1.1.2
       #image: docker.io/rancher/mirrored-flannelcni-flannel-cni-plugin:v1.1.2
        command:
        - cp
        args:
        - -f
        - /flannel
        - /opt/cni/bin/flannel
        volumeMounts:
        - name: cni-plugin
          mountPath: /opt/cni/bin
      - name: install-cni
        image: docker.io/flannel/flannel:v0.22.0
       #image: docker.io/rancher/mirrored-flannelcni-flannel:v0.22.0
        command:
        - cp
        args:
        - -f
        - /etc/kube-flannel/cni-conf.json
        - /etc/cni/net.d/10-flannel.conflist
        volumeMounts:
        - name: cni
          mountPath: /etc/cni/net.d
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
      containers:
      - name: kube-flannel
        image: docker.io/flannel/flannel:v0.22.0
       #image: docker.io/rancher/mirrored-flannelcni-flannel:v0.22.0
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: EVENT_QUEUE_DEPTH
          value: "5000"
        volumeMounts:
        - name: run
          mountPath: /run/flannel
        - name: flannel-cfg
          mountPath: /etc/kube-flannel/
        - name: xtables-lock
          mountPath: /run/xtables.lock
      volumes:
      - name: run
        hostPath:
          path: /run/flannel
      - name: cni-plugin
        hostPath:
          path: /opt/cni/bin
      - name: cni
        hostPath:
          path: /etc/cni/net.d
      - name: flannel-cfg
        configMap:
          name: kube-flannel-cfg
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
```

```shell
kubectl apply -f  kube-flannel.yml 
```

#### 6.1.2 k8s集群集群部署flannel插件

下载flannel插件，并解压到`/opt/k8s/bin`目录下

flannel插件地址：https://github.com/containernetworking/plugins/releases/tag/v0.8.6