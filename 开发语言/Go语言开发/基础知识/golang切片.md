# Golang 切片Slice原理详解和使用技巧

最近用到`Golang`的切片比较多，使用过程中老是会犯些莫名其妙的错误。趁着这个机会好好学习了一下`Slice`，本文就记录下我学习`Slice`切片的心得和踩得一些坑。

## **一，什么是切片Slice**

所谓的切片，就是程序员梦想中的动态数组，可以动态的自动扩容，可以常量时间内知道数组内元素的数量，以及容量的大小。
想想以前用C语言的时候，都是静态大小数组，当数组不够用的时候，都是要`realloc`去手动扩容， 都是泪啊。后来用`C++`语言的时候，情况稍微变好了点，有了模块库，库中实现了动态数组`Array`。到了现在的`Golang`，语法中就开始支持动态数组了，简直是不能太爽。

我们可以非常方便的声明动态数组，也就是切片`Slice`

```go
var s1 []int        // 声明一个空的整数切片
var s2 []string     // 声明一个空的字符串切片
s1 = append(s1, 5)  // 使用append关键字在切片中插入一个整数
```

## **二，切片的底层实现**

在继续讲后面的内容之前，需要先了解下切片这个动态数组的底层实现。下面这个就是`Golang`中切片的实现结构体。

```go
type slice struct {
    array unsafe.Pointer   // 用来存储实际数据的数组指针，指向一块连续的内存
    len   int              // 切片中元素的数量
    cap   int              // array数组的长度
}
```

这个切片的底层实现一点都不出我们的意外，以前用C语言手动实现动态数组的时候也差不多是同样的方法。用一个结构体保存存放数据的数组`array`指针，以及数组的总长度`cap`，已经使用的长度`len`。之所以要保存`cap`，是用来在动态扩容时，计算扩容后的新`cap`用的，这些了解就行了，不用深究。

## **三，切片的赋值和函数传值**

### **1) 切片赋值**

讲了切片的实现，紧接着就要讲切片的赋值了。

```go
var s1 = []int{1, 2, 3}  // 初始化一个有3个元素的切片
var s2 = s1              // 将切片s1赋值给一个新的切片s2
s2[0] = 99               // 将s2的第一个元素设为99
fmt.Println(s1[0])       // 此时s1[0]是多少
```

如果以为`s1[0]`还是1，那么就错了。`s1[0]`也变成了99。这是因为即使现在有两个切片：`s1`和`s2`，但是在执行var s2 = s1赋值的时候，底层的数组`array`没有复制一份，也就是说两个切片指向的是同一个底层数组`array`，一个切片`s1`修改了底层数组内容，另一个切片`s2`也会看到

### **2）切片的函数传递**

再来看看函数传递切片，也是我刚开始很困惑的一个问题

```go
//定义一个函数，给切片添加一个元素
func addOne(s []int) {
    s = append(s, 1)
}
var s1 = []int{2}   // 初始化一个切片
addOne(s1)          // 调用函数添加一个切片
fmt.Println(s1)
```

此时打印`s1`是应该显示{2, 1}吗？答案错误。显示的还是{1}。
首先要明白`Golang`函数所有的参数传递都是值传递，也就是说将切片s1传递给函数`addOne`后，函数`addOne`其实是将切片s1复制了一份，然后在函数内部对复制出来的切片s进行`append`，`append`后切片`s`的`len`变成了2，打印切片`s`的话会显示{2, 1}。虽然切片`s1`的`array`和函数内切片`s`的`array`是同一份，都有两个元素，但是切片`s1`的`len`还是1，所以打印出来的`s1`也就只有一个元素{1}.

## **四，切片的插入和删除元素**

### **1）插入元素**

插入元素很简单，调用`append`无脑加就行了

```go
var s1 = []int{1, 2}     // 初始化一个切片
s1 = append(s1, 3)       // 在最后添加一个元素
```

### **2）删除元素**

删除就麻烦点，需要事先知道要删除的元素的下标`index`

```go
var s1 = []int{1, 2, 3, 4}                 // 初始化一个切片
var index = 2                              // 要删除的下标
s1 = append(s1[:index], s1[index+1:]...)   //删除下标为index的元素
```

稍微解释一下，上面删除的逻辑。`s1[:index]`指的是[0, index)区间的元素，注意是左闭右开，`s1[index+1:]`指的是[index+1, len)区间的元素，使用`append`将这两个区间合并后，刚好把`index`下标的元素给排除掉了。不得不说这是有点取巧的做法了。

## **五，切片的拷贝**

第三节看到，切片之间的赋值只会拷贝`cap`,`len`以及数组指针。如果想做深拷贝，即把数组的内容也复制一份，该怎么做呢，这就需要用到切片的拷贝。

```go
var s1 = []int{1, 2}        // 初始化一个切片
var s2 = make([]int, 2)     // 初始化一个空的切片，cap为2
copy(s2, s1)                // 将s1拷贝给s2
s2[0] = 99                  // 改变s2[0]
fmt.Println(s1[0])          // 打印s1[0]
```

上面这段代码中，使用`make`为`s2`分配了一段空的数组，类似与`C`语言中的`malloc`。
此时打印出来的`s1[0]`还是1，因为`s2`和`s1`现在是独立的`array`数组。

### **1）确保目的切片有足够的空间**

```go
var s1 = []int{1, 2}        // 初始化一个切片
var s2 []int                // 初始化一个空的切片，cap为0
copy(s2, s1)                // 将s1拷贝给s2
fmt.Println(s2)
```

此时打印出来的`s2`是空的，这是因为`s2`初始化时没有分配空间，并且`copy`也不会为`s2`分配空间。所以在使用`copy`时要确保目的切片`s2`是有足够空间的。

### **2）确保目的切片的空间不要太多**

```go
var s1 = []int{1, 2}                // 初始化一个切片
var s2 = []int{101, 102, 103}       // 初始化一个空的切片，cap为0
copy(s2, s1)                        // 将s1拷贝给s2
fmt.Println(s2)
```

上面代码中，打印出来的`s2`是{1, 2, 103}， 是不是以为是{1, 2}？
通过这两个例子可以想到，如果要确保`copy`后的目的切片与源切片一模一样，就的保证目的切片的大小`cap`与源切片一模一样。

## **六，二维切片的初始化**

想声明一个`n*n`大小的二维切片，刚开始以为很简单

```go
var n int = 10        // 要初始化的二维切片维度n
var s [n][n]int       // 错误的初始化二维切片方法
```

这段代码会报错"只能用常量去声明数组"，并且这声明的是一个固定的数组，而不是动态数组--切片。
然后尝试了如下办法

```go
var s = make([][]int, n, n)   // 错误的初始化二维切片方法
```

这行代码声明的是一个len=n，cap=n的二维切片，也就是说它只分配了二维数组的第一维度，第二维度都是空的。

最后正确的方法是，只能手动去为第二维度分配空间，手动无奈。。。

```go
var s = make([][]int, n)
for i := 0; i < n; i++ { s[i] = make([]int, n) }
```

