# Nginx可视化工具部署

## 一、背景

​		对于想自己搭建网站的朋友，使用自己个性化域名的朋友，使用`Nginx`的不在少数，可能也会使用`Apache`来管理自己的网站，但`Nginx`轻量又好用，还支持正向/反向代理，谁不喜欢呢？

​		但喜欢是一回事，跟"爱"还是有一定区别的，`Nginx`的配置就是一大难点，对于才入门又想配置好一个自己的网站着实要花费很大的功夫，但是我们广大和程序员就是做着一件事的-把事情简单化！难的东西总有简单化的工具。

​		`Nginx Proxy Manager`就是一款让你能通过网页的一些设置，完成网站的代理配置，无需自己再手动安装`Nginx`修改配置文件了，大大提高了效率。项目也是开源的，不用担心项目的安全性。

​		本文采用`docker-compose`的方式部署，所以在部署前需要提前安装好`docker`与`docker-compose`	。

## 二、部署	

1. 创建一个`docker-compose.yaml`文件

```yaml 
## docker-compose示例文件
version: '3'
services:
  app:
    image: harbor.wsh-study.com/public/nginx:latest
    # image: 'jc21/nginx-proxy-manager:latest'
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun
    container_name: nginx-proxy
    hostname: nginx-proxy
    networks:
      - middleware-net
    privileged: true
    restart: always
    ports:
     # - '8081:81'
      - '80:80'
      - '443:443'
    volumes:
      - /opt/nginx/data:/data
      - /opt/nginx/letsencrypt:/etc/letsencrypt
      - /opt/nginx/config/nginx.conf:/etc/nginx/nginx.conf
      - /etc/localtime:/etc/localtime:ro
networks:
  middleware-net:
    external: true

```

2. 创建完`docker-compose.yaml`文件后，在文件所在目录执行`docker-compose up -d`指令即可。

## 三、访问控制页面

使用`ip:8081`访问,如果有防火墙，可在服务器上临时放通`8081`的tcp端口。

![image-20230612211842187](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/1.png)

初始用户名和密码：

```shell
Email: admin@example.com
Password: changeme
```

登录后请修改默认的账户和密码，这里的邮箱是在证书快过期的时候发邮件提醒用的。

![image-20230612212143734](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/2.png)

![image-20230612212202912](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/3.png)

![image-20230612212224591](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/4.png)

在主面板上，常用的为第一项目反向代理和第二项目重定向，其它也可以自行设置。

![image-20230612212305958](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/5.png)

## 四、配置ssl证书

配置`ssl`证书前，需要在容器内安装必要的插件：
```shell
docker exec -it nginx-proxy /bin/bash

pip config set global.index-url https://mirrors.aliyun.com/pypi/simple 

pip install zope 
```

证书添加流程如下：

1. 点击如图所示按钮：

![image-20230612213019880](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/6.png)

2. 根据自己的实际情况填写相关信息：

![image-20230612213219792](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/7.png)

我使用的是腾讯云`DNSPod`提供的`DNS`解析，相应的`key,id`在腾讯云`DNSPod`控制台的账户中心中创建 **API秘钥** 即可。

![image-20230612213713256](https://mc.wsh-study.com/mkdocs/nginx可视化工具部署/8.png)

## 五、配置反向代理

1. 点击代理服务：

![Alt text](https://mc.wsh-study.com/mkdocs/Nginx可视化工具部署/9.png)

2. 接着点击添加代理服务，弹出如下对话框:

![Alt text](https://mc.wsh-study.com/mkdocs/Nginx可视化工具部署/10.png)

3. 接着就是添加代理操作，示例如下：

![Alt text](https://mc.wsh-study.com/mkdocs/Nginx可视化工具部署/11.png)

![Alt text](https://mc.wsh-study.com/mkdocs/Nginx可视化工具部署/12.png)