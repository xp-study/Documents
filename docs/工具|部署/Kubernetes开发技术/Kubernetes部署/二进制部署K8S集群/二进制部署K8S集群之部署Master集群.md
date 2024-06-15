## 部署Master集群

------

### 1、部署环境说明

**kubernetes master 节点运行如下组件：**

- kube-apiserver
- kube-scheduler
- kube-controller-manager

- kube-apiserver、kube-scheduler 和 kube-controller-manager 均以多实例模式运行：

1. kube-scheduler 和 kube-controller-manager 会自动选举产生一个 leader 实例，其它实例处于阻塞模式，当 leader 挂了后，重新选举产生新的 leader，从而保证服务可用性；
2. kube-apiserver 是无状态的，可以通过 kube-nginx 进行代理访问从而保证服务可用性；

**注意：** 如果三台Master节点仅仅作为集群管理节点的话，那么则无需部署docker、kubelet、kube-proxy组件；但是如果后期要部署mertics-server、istio组件服务时会出现无法运行的情况，所以还是建议master节点也部署docker、kubelet、kube-proxy组件

1.1：下载程序包并解压

- 将k8s-server压缩包上传至服务器`/opt/k8s/work`目录下，并进行解压

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# tar -zxvf kubernetes-server-linux-amd64.tar.gz
[root@k8s-master1 work]# cd kubernetes/
[root@k8s-master1 kubernetes]# tar -zxvf kubernetes-src.tar.gz
```

1.2：分发二进制文件

- 将解压后的二进制文件拷贝到所有的K8S-Master集群的节点服务器上
- 将`kuberlet`，`kube-proxy`分发给所有worker节点，存储目录/opt/k8s/bin

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-proxy,kube-scheduler,kubeadm,kubectl,kubelet,mounter} root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
 
[root@k8s-master1 work]# for node_ip in ${WORK_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kubernetes/server/bin/{kube-proxy,kubelet} root@${node_ip}:/opt/k8s/bin/
    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
  done
```

### 2、集群节点高可用访问 kube-apiserver

- 本文档讲解使用 nginx 4 层透明代理功能实现 K8S 所有节点高可用访问 kube-apiserver 集群的步骤。
- 注意：如果没有特殊指明，本文档的所有操作均在 **k8s-Master1** 节点上执行，然后远程分发文件和执行命令。

2.1：基于 nginx 代理的 kube-apiserver 高可用方案

- 控制节点的 `kube-controller-manager`、`kube-scheduler` 是多实例部署且连接本机的 `kube-apiserver`，所以只要有一个实例正常，就可以保证高可用；
- 集群内的 Pod 使用 K8S 服务域名 kubernetes 访问 `kube-apiserver`， `kube-dns` 会自动解析出多个` kube-apiserver` 节点的 IP，所以也是高可用的；
- 在每个节点起一个 nginx 进程，后端对接多个 apiserver 实例，nginx 对它们做健康检查和负载均衡；
- `kubelet`、`kube-proxy`、`controller-manager`、`scheduler` 通过本地的 nginx（监听 127.0.0.1）访问 `kube-apiserver`，从而实现 `kube-apiserver` 的高可用；

2.2：下载和编译 nginx

- 官方nginx下载地址：[https://nginx.org/download/nginx-1.16.1.tar.gz]
- 由于国内通过官方地址下载很慢，所以我这里使用国内源进行下载

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# wget https://mirrors.huaweicloud.com/nginx/nginx-1.16.1.tar.gz
 
[root@k8s-master1 work]# yum -y install gcc-c++
[root@k8s-master1 work]# tar -zxvf nginx-1.16.1.tar.gz
 
[root@k8s-master1 work]# cd nginx-1.16.1/
[root@k8s-master1 work]# mkdir nginx-prefix
[root@k8s-master1 nginx-1.16.1]# ./configure --with-stream --without-http --prefix=$(pwd)/nginx-prefix --without-http_uwsgi_module --without-http_scgi_module --without-http_fastcgi_module
 
[root@k8s-master1 nginx-1.16.1]# make && make install
```

2.4：所有节点部署 nginx

#### 2.4.1：所有节点创建目录

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
  done
```

#### 2.4.2：拷贝二进制程序

- 注意：根据自己配置的nginx编译安装的路径进行填写下面的路径
- 重命名二进制文件为 kube-nginx

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /opt/k8s/kube-nginx/{conf,logs,sbin}"
    scp /opt/k8s/work/nginx-1.16.1/nginx-prefix/sbin/nginx  root@${node_ip}:/opt/k8s/kube-nginx/sbin/kube-nginx
    ssh root@${node_ip} "chmod a+x /opt/k8s/kube-nginx/sbin/*"
  done
```

#### 2.4.3: 配置 nginx，开启 4 层透明转发功能

- **注意：**upstream backend中的 server 列表为集群中各 kube-apiserver 的节点 IP，需要根据实际情况修改

```shell
[root@k8s-master1 work]# cat > kube-nginx.conf <<EOF
worker_processes 1;
 
events {
    worker_connections  1024;
}
 
stream {
    upstream backend {
        hash $remote_addr consistent;
        server 192.168.66.62:6443        max_fails=3 fail_timeout=30s;
        server 192.168.66.63:6443        max_fails=3 fail_timeout=30s;
        server 192.168.66.64:6443        max_fails=3 fail_timeout=30s;
    }
 
    server {
        listen 127.0.0.1:8443;
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }
}
EOF
```

#### 2.4.4：分发配置文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.conf  root@${node_ip}:/opt/k8s/kube-nginx/conf/kube-nginx.conf
  done
```

2.5：配置 systemd unit 文件，启动服务

#### 2.5.1：配置 kube-nginx systemd unit 文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-nginx.service <<EOF
[Unit]
Description=kube-apiserver nginx proxy
After=network.target
After=network-online.target
Wants=network-online.target
 
[Service]
Type=forking
ExecStartPre=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -t
ExecStart=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx
ExecReload=/opt/k8s/kube-nginx/sbin/kube-nginx -c /opt/k8s/kube-nginx/conf/kube-nginx.conf -p /opt/k8s/kube-nginx -s reload
PrivateTmp=true
Restart=always
RestartSec=5
StartLimitInterval=0
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
```

#### 2.5.2：分发 systemd unit 文件

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-nginx.service  root@${node_ip}:/etc/systemd/system/
  done
```

#### 2.5.3：启动 kube-nginx 服务

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-nginx && systemctl restart kube-nginx"
  done
```

2.6：检查 kube-nginx 服务运行状态

```shell
[root@k8s-master1 work]# for node_ip in ${NODE_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-nginx |grep 'Active:'"
  done
```

### 3、部署kube-apiserver集群

#### 3.1、创建 kubernetes-master 证书和私钥

- hosts 字段指定授权使用该证书的 IP 和域名列表，这里列出了 master 节点 IP、kubernetes 服务的 IP 和域名；

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work/
[root@k8s-master1 work]# cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes-master",
  "hosts": [
    "127.0.0.1",
    "192.168.66.62",
    "192.168.66.63",
    "192.168.66.64",
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local.",
    "kubernetes.default.svc.${CLUSTER_DNS_DOMAIN}."
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

- 生成证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
 
[root@k8s-master1 work]# ls kubernetes*pem
kubernetes-key.pem  kubernetes.pem
```

- 将生成的证书和私钥文件拷贝到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert"
    scp kubernetes*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

#### 3.2、创建加密配置文件

```shell
[root@k8s-master1 work]# cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

- 将加密配置文件拷贝到 master 节点的 `/etc/kubernetes` 目录下

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp encryption-config.yaml root@${node_ip}:/etc/kubernetes/
  done
```

#### 3.3、创建审计策略文件

```shell
[root@k8s-master1 work]# cat > audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
  # The following requests were manually identified as high-volume and low-risk, so drop them.
  - level: None
    resources:
      - group: ""
        resources:
          - endpoints
          - services
          - services/status
    users:
      - 'system:kube-proxy'
    verbs:
      - watch
 
  - level: None
    resources:
      - group: ""
        resources:
          - nodes
          - nodes/status
    userGroups:
      - 'system:nodes'
    verbs:
      - get
 
  - level: None
    namespaces:
      - kube-system
    resources:
      - group: ""
        resources:
          - endpoints
    users:
      - 'system:kube-controller-manager'
      - 'system:kube-scheduler'
      - 'system:serviceaccount:kube-system:endpoint-controller'
    verbs:
      - get
      - update
 
  - level: None
    resources:
      - group: ""
        resources:
          - namespaces
          - namespaces/status
          - namespaces/finalize
    users:
      - 'system:apiserver'
    verbs:
      - get
 
  # Don't log HPA fetching metrics.
  - level: None
    resources:
      - group: metrics.k8s.io
    users:
      - 'system:kube-controller-manager'
    verbs:
      - get
      - list
 
  # Don't log these read-only URLs.
  - level: None
    nonResourceURLs:
      - '/healthz*'
      - /version
      - '/swagger*'
 
  # Don't log events requests.
  - level: None
    resources:
      - group: ""
        resources:
          - events
 
  # node and pod status calls from nodes are high-volume and can be large, don't log responses
  # for expected updates from nodes
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    users:
      - kubelet
      - 'system:node-problem-detector'
      - 'system:serviceaccount:kube-system:node-problem-detector'
    verbs:
      - update
      - patch
 
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    userGroups:
      - 'system:nodes'
    verbs:
      - update
      - patch
 
  # deletecollection calls can be large, don't log responses for expected namespace deletions
  - level: Request
    omitStages:
      - RequestReceived
    users:
      - 'system:serviceaccount:kube-system:namespace-controller'
    verbs:
      - deletecollection
 
  # Secrets, ConfigMaps, and TokenReviews can contain sensitive & binary data,
  # so only log at the Metadata level.
  - level: Metadata
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps
      - group: authentication.k8s.io
        resources:
          - tokenreviews
  # Get repsonses can be large; skip them.
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
    verbs:
      - get
      - list
      - watch
 
  # Default level for known APIs
  - level: RequestResponse
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
      
  # Default level for all other requests.
  - level: Metadata
    omitStages:
      - RequestReceived
EOF
```

- 分发审计策略文件

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp audit-policy.yaml root@${node_ip}:/etc/kubernetes/audit-policy.yaml
  done
```

#### 3.4、创建后续访问 metrics-server 或 kube-prometheus 使用的证书

##### 3.4.1：创建证书签名请求

```shell
[root@k8s-master1 work]# cat > proxy-client-csr.json <<EOF
{
  "CN": "aggregator",
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
      "O": "k8s",
      "OU": "dqz"
    }
  ]
}
EOF
```

##### 3.4.2：生成证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -ca=/etc/kubernetes/cert/ca.pem \
  -ca-key=/etc/kubernetes/cert/ca-key.pem  \
  -config=/etc/kubernetes/cert/ca-config.json  \
  -profile=kubernetes proxy-client-csr.json | cfssljson -bare proxy-client
 
[root@k8s-master1 work]# ls proxy-client*.pem
proxy-client-key.pem  proxy-client.pem
```

##### 3.4.3：将生成的证书和私钥文件拷贝到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp proxy-client*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

#### 3.5、创建 kube-apiserver systemd unit 模板文件

```shell
[root@k8s-master1 work]# cat > kube-apiserver.service.template <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
 
[Service]
WorkingDirectory=${K8S_DIR}/kube-apiserver
ExecStart=/opt/k8s/bin/kube-apiserver \\
  --advertise-address=##MASTER_IP## \\
  --default-not-ready-toleration-seconds=360 \\
  --default-unreachable-toleration-seconds=360 \\
  --feature-gates=DynamicAuditing=true \\
  --max-mutating-requests-inflight=2000 \\
  --max-requests-inflight=4000 \\
  --default-watch-cache-size=200 \\
  --delete-collection-workers=2 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  --etcd-certfile=/etc/kubernetes/cert/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/cert/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --bind-address=##MASTER_IP## \\
  --secure-port=6443 \\
  --tls-cert-file=/etc/kubernetes/cert/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kubernetes-key.pem \\
  --insecure-port=0 \\
  --audit-dynamic-configuration \\
  --audit-log-maxage=15 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-truncate-enabled \\
  --audit-log-path=${K8S_DIR}/kube-apiserver/audit.log \\
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \\
  --profiling \\
  --anonymous-auth=false \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --enable-bootstrap-token-auth \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --service-account-key-file=/etc/kubernetes/cert/ca.pem \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all=true \\
  --enable-admission-plugins=NodeRestriction \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --event-ttl=168h \\
  --kubelet-certificate-authority=/etc/kubernetes/cert/ca.pem \\
  --kubelet-client-certificate=/etc/kubernetes/cert/kubernetes.pem \\
  --kubelet-client-key=/etc/kubernetes/cert/kubernetes-key.pem \\
  --kubelet-https=true \\
  --kubelet-timeout=10s \\
  --proxy-client-cert-file=/etc/kubernetes/cert/proxy-client.pem \\
  --proxy-client-key-file=/etc/kubernetes/cert/proxy-client-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=${NODE_PORT_RANGE} \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=10
Type=notify
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF
```

#### 3.6、Master节点创建和分发kube-apiserver systemd模板文件

##### 3.6.1：创建systemd unit 文件

```shell
[root@k8s-master1 work]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##MASTER_IP##/${MASTER_IPS[i]}/" kube-apiserver.service.template > kube-apiserver-${MASTER_IPS[i]}.service 
  done
 
[root@k8s-master1 work]# ls kube-apiserver*.service
kube-apiserver-192.168.66.62.service  kube-apiserver-192.168.66.64.service
kube-apiserver-192.168.66.63.service
```

##### 3.6.2：分发生成的 systemd unit 文件

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-apiserver-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-apiserver.service
  done
```

#### 3.7、启动 kube-apiserver 服务

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-apiserver"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver"
  done
```

#### 3.8、检查 kube-apiserver 运行状态

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-apiserver |grep 'Active:'"
  done
```

#### 3.9、检查集群状态

```shell
[root@k8s-master1 work]# kubectl cluster-info
Kubernetes master is running at https://127.0.0.1:8443
 
To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

![image-20230712195109797](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/1.png)

```shell
[root@k8s-master1 work]# kubectl get all --all-namespaces
NAMESPACE   NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
default     service/kubernetes   ClusterIP   10.254.0.1   <none>        443/TCP   56s
[root@k8s-master1 work]# kubectl get componentstatuses
```

![image-20230712222439204](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/2.png)

- 上图中`scheduler`与`controller-manager`显示`Unhealthy`，是因为我们还没有部署这两个组件，部署后再次检查显示`ok`

### 4、部署高可用kube-controller-manager集群

该集群包含 3 个节点，启动后将通过竞争选举机制产生一个 leader节点，其它节点为阻塞状态。当 leader 节点不可用时，阻塞的节点将再次进行选举产生新的 leader 节点，从而保证服务的可用性。

为保证通信安全，本文档先生成 x509 证书和私钥，kube-controller-manager 在如下两种情况下使用该证书：

1. 与 kube-apiserver 的安全端口通信;
2. 在 **`安全端口`** (https，10252) 输出 prometheus 格式的 metrics；

#### 4.1、创建 kube-controller-manager 证书和私钥

##### 4.1.1：创建证书签名请求

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "192.168.66.62",
      "192.168.66.63",
      "192.168.66.64"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "system:kube-controller-manager",
        "OU": "dqz"
      }
    ]
}
EOF
```

##### 4.1.2：生成证书和私钥

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
 
 
[root@k8s-master1 work]# ls kube-controller-manager*pem
kube-controller-manager-key.pem  kube-controller-manager.pem
```

##### 4.1.3：将生成的证书和私钥分发到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

#### 4.2、创建和分发 kubeconfig 文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
 
[root@k8s-master1 work]# kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/work/ca.pem \
  --embed-certs=true \
  --server="https://##NODE_IP##:6443" \
  --kubeconfig=kube-controller-manager.kubeconfig
 
[root@k8s-master1 work]# kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.pem \
  --client-key=kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig
 
[root@k8s-master1 work]# kubectl config set-context system:kube-controller-manager \
  --cluster=kubernetes \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig
 
[root@k8s-master1 work]# kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
```

- 分发 kubeconfig 到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" kube-controller-manager.kubeconfig > kube-controller-manager-${node_ip}.kubeconfig
    scp kube-controller-manager-${node_ip}.kubeconfig root@${node_ip}:/etc/kubernetes/kube-controller-manager.kubeconfig
  done
```

#### 4.3、创建 kube-controller-manager systemd unit 模板文件

```shell
cat > kube-controller-manager.service.template <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
 
[Service]
WorkingDirectory=${K8S_DIR}/kube-controller-manager
ExecStart=/opt/k8s/bin/kube-controller-manager \\
  --profiling \\
  --cluster-name=kubernetes \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kube-api-qps=1000 \\
  --kube-api-burst=2000 \\
  --leader-elect \\
  --use-service-account-credentials\\
  --concurrent-service-syncs=2 \\
  --bind-address=0.0.0.0 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-controller-manager.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-controller-manager-key.pem \\
  --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --cluster-signing-cert-file=/etc/kubernetes/cert/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --experimental-cluster-signing-duration=876000h \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --concurrent-deployment-syncs=10 \\
  --concurrent-gc-syncs=30 \\
  --node-cidr-mask-size=24 \\
  --allocate-node-cidrs=true \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --pod-eviction-timeout=6m \\
  --terminated-pod-gc-threshold=10000 \\
  --root-ca-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-private-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
 
[Install]
WantedBy=multi-user.target
EOF
```

##### 4.3.1、为各Master节点创建和分发 kube-controller-mananger systemd unit 文件

- 替换模板文件中的变量

```shell
[root@k8s-master1 work]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${MASTER_IPS[i]}/" kube-controller-manager.service.template > kube-controller-manager-${NODE_IPS[i]}.service 
  done
```

- 分发至给Master节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-controller-manager-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-controller-manager.service
  done
```

#### 4.4、启动kube-controller-manager服务

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-controller-manager"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl restart kube-controller-manager"
  done
```

#### 4.5、检查服务运行状态

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-controller-manager|grep Active"
  done
```

- kube-controller-manager 监听 10252 端口，接收 https 请求

```shell
[root@k8s-master1 work]# netstat -lnpt | grep kube-cont
tcp        0      0 192.168.66.62:10252     0.0.0.0:*               LISTEN      37321/kube-controll
```

4.6、查看输出的 metrics

**注意：**以下命令在 kube-controller-manager 节点上执行。

- 由于在kube-controller-manager启动文件中关掉了`--port=0`和`--secure-port=10252`这两个参数，则只能通过http方式获取到kube-controller-manager 输出的metrics信息。

```shell
curl -s http://192.168.66.62:10252/metrics|head
curl -s --cacert /opt/k8s/work/ca.pem --cert /opt/k8s/work/admin.pem --key /opt/k8s/work/admin-key.pem http://192.168.66.62:10252/metrics |head
```

- 如果你启动配置文件中添加了这2个参数，那么请以下面的方式进行访问。

```shell
curl -s --cacert /opt/k8s/work/ca.pem --cert /opt/k8s/work/admin.pem --key /opt/k8s/work/admin-key.pem https://192.168.66.62:10252/metrics |head
```

![image-20230712222737295](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/3.png)

4.7、查看当前的 leader

```shell
[root@k8s-master1 work]# kubectl get endpoints kube-controller-manager --namespace=kube-system  -o yaml
```

- 可以看到当前的leader为k8s-master1

![image-20230712222839789](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/4.png)

- 检查集群状态

```shell
[root@k8s-master1 work]# kubectl get cs
```

![image-20230712222954422](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/5.png)

### 5、部署高可用 kube-scheduler 集群

#### 5.1、创建 kube-scheduler 证书和私钥

##### 5.1.1：创建证书签名请求

- 注意hosts填写自己服务器master集群IP

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
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
        "O": "system:kube-scheduler",
        "OU": "dqz"
      }
    ]
}
EOF
```

##### 5.1.2：生成证书和私钥

```shell
[root@k8s-master1 work]# cfssl gencert -ca=/opt/k8s/work/ca.pem \
  -ca-key=/opt/k8s/work/ca-key.pem \
  -config=/opt/k8s/work/ca-config.json \
  -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
 
[root@k8s-master1 work]# ls kube-scheduler*pem
kube-scheduler-key.pem  kube-scheduler.pem
```

##### 5.1.3：将生成的证书和私钥分发到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler*.pem root@${node_ip}:/etc/kubernetes/cert/
  done
```

#### 5.2、创建和分发 kubeconfig 文件

kube-scheduler 使用 kubeconfig 文件访问 apiserver，该文件提供了 apiserver 地址、嵌入的 CA 证书和 kube-scheduler 证书

##### 5.2.1：创建kuberconfig文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work

[root@k8s-master1 work]# kubectl config set-cluster kubernetes \
--certificate-authority=/opt/k8s/work/ca.pem \
--embed-certs=true \
--server="https://##NODE_IP##:6443" \
--kubeconfig=kube-scheduler.kubeconfig

 
[root@k8s-master1 work]# kubectl config set-credentials system:kube-scheduler \
--client-certificate=kube-scheduler.pem \
--client-key=kube-scheduler-key.pem \
--embed-certs=true \
--kubeconfig=kube-scheduler.kubeconfig

 
[root@k8s-master1 work]# kubectl config set-context system:kube-scheduler \
--cluster=kubernetes \
--user=system:kube-scheduler \
--kubeconfig=kube-scheduler.kubeconfig

[root@k8s-master1 work]# kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
```

##### 5.2.2：分发 kubeconfig 到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    sed -e "s/##NODE_IP##/${node_ip}/" kube-scheduler.kubeconfig > kube-scheduler-${node_ip}.kubeconfig
    scp kube-scheduler-${node_ip}.kubeconfig root@${node_ip}:/etc/kubernetes/kube-scheduler.kubeconfig
  done
```

#### 5.3、创建 kube-scheduler 配置文件

##### 5.3.1：创建kube-scheduler配置文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat <<EOF | sudo tee kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF
```

##### 5.3.2：分发 kube-scheduler 配置文件到所有 master 节点

- 分发 kube-scheduler 配置文件到所有 master 节点

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler.yaml root@${node_ip}:/etc/kubernetes/
  done
```

#### 5.4、创建 kube-scheduler systemd unit 模板文件

```shell
[root@k8s-master1 ~]# cd /opt/k8s/work
[root@k8s-master1 work]# cat > kube-scheduler.service.template <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
[Service]
WorkingDirectory=${K8S_DIR}/kube-scheduler
ExecStart=/opt/k8s/bin/kube-scheduler \\
--config=/etc/kubernetes/kube-scheduler.yaml \\
--bind-address=0.0.0.0 \\
--tls-cert-file=/etc/kubernetes/cert/kube-scheduler.pem \\
--tls-private-key-file=/etc/kubernetes/cert/kube-scheduler-key.pem \\
--authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
--client-ca-file=/etc/kubernetes/cert/ca.pem \\
--requestheader-allowed-names="aggregator" \\
--requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
--requestheader-extra-headers-prefix="X-Remote-Extra-" \\
--requestheader-group-headers=X-Remote-Group \\
--requestheader-username-headers=X-Remote-User \\
--authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
--logtostderr=true \\
--v=2
Restart=always
RestartSec=5
StartLimitInterval=0
[Install]
WantedBy=multi-user.target
EOF
```

#### 5.5、为各节点创建和分发 kube-scheduler systemd unit 文件

```shell
[root@k8s-master1 work]# for (( i=0; i < 3; i++ ))
  do
    sed -e "s/##NODE_NAME##/${NODE_NAMES[i]}/" -e "s/##NODE_IP##/${MASTER_IPS[i]}/" kube-scheduler.service.template > kube-scheduler-${MASTER_IPS[i]}.service 
  done
[root@k8s-master1 work]# ls kube-scheduler*.service
```

- 分发 systemd unit 文件到所有 master 节点：

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    scp kube-scheduler-${node_ip}.service root@${node_ip}:/etc/systemd/system/kube-scheduler.service
  done
```

#### 5.6、启动kube-scheduler 服务

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "mkdir -p ${K8S_DIR}/kube-scheduler"
    ssh root@${node_ip} "systemctl daemon-reload && systemctl enable kube-scheduler && systemctl restart kube-scheduler"
  done
```

#### 5.7、检查服务运行状态

```shell
[root@k8s-master1 work]# for node_ip in ${MASTER_IPS[@]}
  do
    echo ">>> ${node_ip}"
    ssh root@${node_ip} "systemctl status kube-scheduler|grep Active"
  done
```

#### 5.8、查看输出的 metrics

**注意：**以下命令在 kube-scheduler 节点上执行。

kube-scheduler 监听 10251 和 10259 端口：

- 10251：接收 http 请求，非安全端口，不需要认证授权；
- 10259：接收 https 请求，安全端口，需要认证授权；

两个接口都对外提供 `/metrics` 和 `/healthz` 的访问。

```shell
[root@k8s-master1 work]# netstat -lnpt |grep kube-sch
tcp6       0      0 :::10251                :::*                    LISTEN      75717/kube-schedule 
tcp6       0      0 :::10259                :::*                    LISTEN      75717/kube-schedule
 
[root@k8s-master1 work]# curl -s http://192.168.66.62:10251/metrics |head
[root@k8s-master1 work]# curl -s --cacert /opt/k8s/work/ca.pem --cert /opt/k8s/work/admin.pem --key /opt/k8s/work/admin-key.pem https://192.168.66.62:10259/metrics |head
```

#### 5.9、查看当前的 leader

```shell
[root@k8s-master1 work]# kubectl get endpoints kube-scheduler --namespace=kube-system  -o yaml
```

- 可以看到当前的集群leader是k8s-master1节点

![image-20230712223116180](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/6.png)

- 查看集群状态

```shell
[root@k8s-master1 work]# kubectl get cs
```

![image-20230712223150332](https://mc.wsh-study.com/mkdocs/二进制部署K8S集群之部署Master集群/7.png)