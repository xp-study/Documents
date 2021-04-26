# Docker - 实现本地镜像的导出、导入（export、import、save、load）

 有时我们需要将一台电脑上的镜像复制到另一台电脑上使用，除了可以借助仓库外，还可以直接将镜像保存成一个文件，再拷贝到另一台电脑上导入使用。

  对于镜像的导出和导入，**Docker** 提供了两种方案，下面分别进行介绍。

## 一、使用 export 和 import

### 1，查看本机的容器

这两个命令是通过容器来导入、导出镜像。首先我们使用 **docker ps -a** 命令查看本机所有的容器。

[![原文:Docker - 实现本地镜像的导出、导入（export、import、save、load）](./images/Docker%20-%20实现本地镜像的导出、导入（export、import、save、load）/1.jpg)


### 2，导出镜像

（1）使用 **docker export** 命令根据容器 **ID** 将镜像导出成一个文件。

```
docker export f299f501774c > hangger_server.tar
```


（2）上面命令执行后，可以看到文件已经保存到当前的 **docker** 终端目录下。

[![原文:Docker - 实现本地镜像的导出、导入（export、import、save、load）](./images/Docker%20-%20实现本地镜像的导出、导入（export、import、save、load）/2.jpg)



### 3，导入镜像

（1）使用 **docker import** 命令则可将这个镜像文件导入进来。

```
docker import - new_hangger_server < hangger_server.tar
```


（2）执行 **docker images** 命令可以看到镜像确实已经导入进来了。

[![原文:Docker - 实现本地镜像的导出、导入（export、import、save、load）](./images/Docker%20-%20实现本地镜像的导出、导入（export、import、save、load）/3.jpg)



## 二、使用 save 和 load

### 1，查看本机的容器

这两个命令是通过镜像来保存、加载镜像文件的。首先我们使用 **docker images** 命令查看本机所有的镜像。

[![原文:Docker - 实现本地镜像的导出、导入（export、import、save、load）](./images/Docker%20-%20实现本地镜像的导出、导入（export、import、save、load）/4.jpg)



### 2，保存镜像

（1）下面使用 **docker save** 命令根据 **ID** 将镜像保存成一个文件。

```
docker save 0fdf2b4c26d3 > hangge_server.tar
```


（2）我们还可以同时将多个 **image** 打包成一个文件，比如下面将镜像库中的 **postgres** 和 **mongo** 打包：

```
docker save -o images.tar postgres:9.6 mongo:3.4
```



### 3，载入镜像

使用 **docker load** 命令则可将这个镜像文件载入进来。

```
docker load < hangge_server.tar
```



## 附：两种方案的差别

**特别注意：两种方法不可混用。**
如果使用 **import** 导入 **save** 产生的文件，虽然导入不提示错误，但是启动容器时会提示失败，会出现类似"**docker: Error response from daemon: Container command not found or does not exist**"的错误。



### 1，文件大小不同

**export** 导出的镜像文件体积小于 **save** 保存的镜像

### 2，是否可以对镜像重命名

- **docker import** 可以为镜像指定新名称
- **docker load** 不能对载入的镜像重命名



### 3，是否可以同时将多个镜像打包到一个文件中

- **docker export** 不支持
- **docker save** 支持



### 4，是否包含镜像历史

- **export** 导出（**import** 导入）是根据容器拿到的镜像，再导入时会丢失镜像所有的历史记录和元数据信息（即仅保存容器当时的快照状态），所以无法进行回滚操作。
- 而 **save** 保存（**load** 加载）的镜像，没有丢失镜像的历史，可以回滚到之前的层（**layer**）。

### 5，应用场景不同

- **docker export 的应用场景**：主要用来制作基础镜像，比如我们从一个 **ubuntu** 镜像启动一个容器，然后安装一些软件和进行一些设置后，使用 **docker export** 保存为一个基础镜像。然后，把这个镜像分发给其他人使用，比如作为基础的开发环境。
- **docker save 的应用场景**：如果我们的应用是使用 **docker-compose.yml** 编排的多个镜像组合，但我们要部署的客户服务器并不能连外网。这时就可以使用 **docker save** 将用到的镜像打个包，然后拷贝到客户服务器上使用 **docker load** 载入。
