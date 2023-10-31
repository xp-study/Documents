

# MacOS上使用Jenv管理多个JDK版本

基本使用: 在`Mac OS`下使用`Homebrew`安装`JEnv`：

```shell
brew install jenv
```

安装成功后需要进行一下简单的配置，让它可以起作用：

```shell
echo 'export PATH="$HOME/.jenv/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(jenv init -)"' >> ~/.zshrc
```

好了，`JEnv`已经安装好了，让我们来看一下它找见哪个`Java`版本了：

```shell
jenv versions
```

![image-20230613111312332](https://mc.wsh-study.com/mkdocs/MacOS上使用Jenv管理多个JDK版本/1.png)

它只找到了系统默认的Java，表示当前选择的版本。尽管我已经下载了其他版本的`Java`， **但是它并不会自动发现**

`JEnv`不能自己安装任何版本的`Java`，所以需要我们手动安装好之后再用`JEnv`指向它们，具体安装步骤参考[MacOS上安装Java](./MacOS上安装Java.md)

使用`jenv add`将`Java 11`、`Java 17`加入`jenv`中：

```shell
jenv add /Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home/
jenv add /Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home/
```

现在运行`jenv versions`会显示：

![image-20230613111338982](https://mc.wsh-study.com/mkdocs/MacOS上使用Jenv管理多个JDK版本/2.png)

对于多余的版本使用`jenv remove`可以从`jEnv`中去掉不需要的`Java`版本：

选择一个`Java`版本，运行`jenv local`，例如：

```shell
 jenv local 11.0
 java -version
# java version "1.8.0_25"
# Java(TM) SE Runtime Environment (build 1.8.0_25-b17)
# Java HotSpot(TM) 64-Bit Server VM (build 25.25-b02, mixed mode)
```

`OK`，我们已经成功地指定了某文件夹中`local`的`Java`版本。我们也可以运行`jenv global`设置一个默认的Java版本，运行`jenv which java`显示可执行的Java的完整路径。