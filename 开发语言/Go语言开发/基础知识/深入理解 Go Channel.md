# 深入理解 Go Channel

### 0. 引言

channel 是 Go 语言中的一个非常重要的特性，这篇文章来深入了解一下 channel。

### 1. CSP

要想理解 channel 要先知道 CSP 模型。CSP 是 Communicating Sequential Process 的简称，中文可以叫做通信顺序进程，是一种并发编程模型，由 [Tony Hoare](https://en.wikipedia.org/wiki/Tony_Hoare) 于 1977 年提出。简单来说，CSP 模型由并发执行的实体（线程或者进程）所组成，实体之间通过发送消息进行通信，这里发送消息时使用的就是通道，或者叫 channel。CSP 模型的关键是关注 channel，而不关注发送消息的实体。Go 语言实现了 CSP 部分理论，goroutine 对应 CSP 中并发执行的实体，channel 也就对应着 CSP 中的 channel。

### 2. channel 基础知识

##### 2.1 创建 channel

channel 使用之前需要通过 make 创建。

```go
unBufferChan := make(chan int)  // 1
bufferChan := make(chan int, N) // 2
```

上面的方式 1 创建的是无缓冲 channel，方式 2 创建的是缓冲 channel。如果使用 channel 之前没有 make，会出现 dead lock 错误。至于为什么是 dead lock，下文我们从源码里面看看。

```go
func main() {
    var x chan int
    go func() {
        x <- 1
    }()
    <-x
}
```

```go
$ go run channel1.go
fatal error: all goroutines are asleep - deadlock!

goroutine 1 [chan receive (nil chan)]:
main.main()
    /Users/kltao/code/go/examples/channl/channel1.go:11 +0x60

goroutine 4 [chan send (nil chan)]:
main.main.func1(0x0)
```

##### 2.2 channel 读写操作

```go
ch := make(chan int, 10)

// 读操作
x <- ch

// 写操作
ch <- x
```

##### 2.3 channel 种类

channel 分为无缓冲 channel 和有缓冲 channel。两者的区别如下：

* 无缓冲：发送和接收动作是同时发生的。如果没有 goroutine 读取 channel （<- channel），则发送者 (channel <-) 会一直阻塞。

* 缓冲：缓冲 channel 类似一个有容量的队列。当队列满的时候发送者会阻塞；当队列空的时候接收者会阻塞。

##### 2.4 关闭 channel

channel 可以通过 built-in 函数 close() 来关闭。

```go
ch := make(chan int)

// 关闭
close(ch)
```

关于关闭 channel 有几点需要注意的是：

- 重复关闭 channel 会导致 panic。
- 向关闭的 channel 发送数据会 panic。
- 从关闭的 channel 读数据不会 panic，读出 channel 中已有的数据之后再读就是 channel 类似的默认值，比如 chan int 类型的 channel 关闭之后读取到的值为 0。

对于上面的第三点，我们需要区分一下：channel 中的值是默认值还是 channel 关闭了。可以使用 ok-idiom 方式，这种方式在 map 中比较常用。

```go
ch := make(chan int, 10)
...
close(ch)

// ok-idiom 
val, ok := <-ch
if ok == false {
    // channel closed
}
```

### 3. channel 的典型用法

##### 1. goroutine 通信

```go
func main() {
    x := make(chan int)
    go func() {
        x <- 1
    }()
    <-x
}
```

##### 2. select

select 一定程度上可以类比于 linux 中的 IO 多路复用中的 select。后者相当于提供了对多个 IO 事件的统一管理，而 Golang 中的 select 相当于提供了对多个 channel 的统一管理。当然这只是 select 在 channel 上的一种使用方法。

```go
select {
    case e, ok := <-ch1:
        ...
    case e, ok := <-ch2:
        ...
    default:  
}
```

值得注意的是 select 中的 break 只能跳到 select 这一层。select 使用的时候一般配合 for 循环使用，像下面这样，因为正常 select 里面的流程也就执行一遍。这么来看 select 中的 break 就稍显鸡肋了。所以使用 break 的时候一般配置 label 使用，label 定义在 for 循环这一层。

```go
for {
    select {
        ...
    }
}
```

##### 3. range channel

range channel 可以直接取到 channel 中的值。当我们使用 range 来操作 channel 的时候，一旦 channel 关闭，channel 内部数据读完之后循环自动结束。

```go
func consumer(ch chan int) {
    for x := range ch {
        fmt.Println(x)
        ...
    }
}

func producer(ch chan int) {
  for _, v := range values {
      ch <- v
  }  
}
```

##### 4. 超时控制

在很多操作情况下都需要超时控制，利用 select 实现超时控制，下面是一个简单的示例。

```go
select {
  case <- ch:
    // get data from ch
  case <- time.After(2 * time.Second)
    // read data from ch timeout
}
```

类似的，上面的 time.After 可以换成其他的任何异常控制流。

##### 5. 生产者-消费者模型

利用缓冲 channel 可以很轻松的实现生产者-消费者模型。上面的 range 示例其实就是一个简单的生产者-消费者模型实现。

### 4. 单向 channel

单向 channel，顾名思义只能写或读的 channel。但是仔细一想，只能写的 channel，如果不读其中的值有什么用呢？其实单向 channel 主要用在函数声明中。比如。

```go
func foo(ch chan<- int) <-chan int {...}
```

foo 的形参是一个只能写的 channel，那么就表示函数 foo 只会对 ch 进行写，当然你传入的参数可以是个普通 channel。foo 的返回值是一个只能读的 channel，那么表示 foo 的返回值规范用法就是只能读取。这种写法在 Golang 的原生代码库中有非常多的示例，感兴趣的可以去看一下。

```go
// Done returns a channel which is closed if and when this pipe is closed
// with CloseWithError.
func (p *http2pipe) Done() <-chan struct{} {
    p.mu.Lock()
    defer p.mu.Unlock()
    if p.donec == nil {
        p.donec = make(chan struct{})
        if p.err != nil || p.breakErr != nil {

            p.closeDoneLocked()
        }
    }
    return p.donec
}
```

也许你会说这么写在功能上和使用普通的 channel 并不会有什么差别。确实是这样的。但是使用单向 channel 编程体现了一种非常优秀的编程范式：**convention over configuration**，中文一般叫做 **约定优于配置**。这种编程范式在 Ruby 中体现的尤为明显。

### 5. 总结

Golang 的 channel 将 goroutine 隔离开，并发编程的时候可以将注意力放在 channel 上。在一定程度上，这个和消息队列的解耦功能还是挺像的。上面主要还是介绍了一些 channel 的常规操作，还有一些奇淫技巧放在参考资料里了。之后的一篇文章还是来看看 channel 的源码吧，对于更深入地理解 channel 还是挺有用的。