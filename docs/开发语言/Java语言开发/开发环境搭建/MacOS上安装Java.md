# MacOS上安装Java

# 1.下载安装包

**[oracle官网jdk下载地址](https://link.juejin.cn/?target=https%3A%2F%2Fwww.oracle.com%2Fjava%2Ftechnologies%2Fdownloads%2F)**

目前jdk版本已经到`Java 20`，不过`Java 20`不是长期支持版本，所以选择 **Java 17** 版本作为示范，注意一下区分mac芯片版本， **`M1芯片选择Arm 64，Intel芯片选择x64`** 。

![image-20230613103112727](https://mc.wsh-study.com/mkdocs/MacOS上安装Java/1.png)

# 2.安装到本机

下载好后直接双击打开,一直下一步安装即可

![image-20230613103345246](https://mc.wsh-study.com/mkdocs/MacOS上安装Java/2.png)

可通过以下命令查看安装路径

```shell
/usr/libexec/java_home
```

本机路径示例( **/Library/Java/JavaVirtualMachines/jdk-17.0.3.1.jdk/Contents/Home** )

# 3.环境变量

## 3.1检查环境变量

打开终端，输入`java -version`命令，如果能正常显示版本信息，就说明`Java`环境已经安装完成啦

![image-20230613111037507](https://mc.wsh-study.com/mkdocs/MacOS上安装Java/3.png)

如果显示没有找到`java`命令，则需要再执行后续操作

## 3.2编辑启动脚本

`MacOS` 默认的 `shell` 是`bash`， **启动脚本** 是 `~/.bash_profile`, 如果 `shell` 是`zsh`，那么启动脚本就是 `~/.zshrc`

以`bash`为例，使用`vim`编辑器编辑启动脚本

```shell
vim ~/.zshrc
```

在启动脚本中添加如下两行，`JAVA_HOME`路径填写本机安装路径

```shell
export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-17.0.3.1.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
```

第一行是将` Java`安装目录设置了一个名为`JAVA_HOME`的环境变量

第二行是将安装目录下的`bin`目录加到系统的`PATH`目录下，这样就可以在任何位置都加载`java`命令了

## 3.3保存环境变量

为了让我们刚刚添加的环境变量生效，使用`source`命令加载环境变量

```shell
source ~/.zshrc
```