# Golang 深度剖析 -- 理解Golang依赖注入

用过Java的都知道Spring框架，Spring核心是一个Ioc容器，各个模块都会注入到容器中，带来的优势是解耦，这样使得修改各个模块时不用管模块之间的依赖关系。

举个例子，一个服务里面有日志模块，配置模块，DB模块，业务模块等，其中日志模块依赖配置模块，DB模块依赖日志模块，配置模块，业务模块依赖所有基础模块。这样带来的一个问题是，如果有模块要修改，势必会影响其他模块，如果模块很多，还需要人为的规定初始化顺序，这对大型项目的维护来说是一件很恐怖的事，因此依赖注入的引入可以减少维护依赖关系的精力，专心使开发人员投入到业务开发中来。
Golang没有Java那种生态很全的框架，导致Golang中的init被滥用。但是Golang社区有很多提供依赖注入(DI)的框架，比如：

```go
"github.com/facebookgo/inject"
"go.uber.org/fx"
"go.uber.org/dig"
```

这里我们以 fx 为例 :

比如我们有一个 Boy 对象 和 Girl 对象 ，他们都在Class对象中。

```go
// go.uber.org/fx
type Boy struct {
  Name string
}

func InitBoy() *Boy {
  return &Boy{Name: "xiaoming"}
}

type Girl struct {
  Name string
}

func InitGirl() *Girl {
  return &Girl{Name: "xiaohong"}
}

type Class struct {
  b *Boy
  g *Girl
}

func InitClass(b *Boy, g *Girl) *Class {
  return &Class{
    b: b,
    g: g,
  }
}
```

在这里Class 对象 依赖Boy对象和Girl对象，所有Boy对象和Girl对象的初始化必须在Class对象初始化之前调用，否则会发生错误。我们可以通过依赖注入的方式解决这个问题：

```go
// go.uber.org/fx
app := fx.New(
    fx.Provide(InitGirl, InitBoy),

    fx.Invoke(InitClass),
  )
app.Start(context.Background())
```

fx 通过两个接口解决依赖，fx包的执行顺序是先执行Invoke里面的函数列表，按照写的顺序一个个执行，fx.Provide提供了一系列的构造函数，如果Invoke里面的函数如果有用到Provide的参数，就调用它的构造函数。

比如Class的初始函数执行时，发现它需要Boy和Girl两个对象，就会通过参数的类型去调用这两个对象的初始化函数。这是通过反射的方式去实现的，类似于一种懒加载的方式。但是fx有个缺点就是如果有多个初始化函数依赖同一个初始化构造函数，那么这个初始化构造函数会调用多遍，感觉这是一个不太合理的设计。

有人可能会问如果有两个对象循环引用了怎么办，那么fx怎么处理。如果出现循环引用fx是没法处理的，而且在Golang中如果模块循环引用是会报错的，这是代码结构不合理的表现。

很多模块在初始化之后会有一个启动函数，比如很多微服务框架初始化一些配置之后会调用它的Start或者Run接口启动服务，在fx里面是通过lifecycle实现的。

比如:

```go
fx.New(
  fx.Invoke(NewHandler)
)
fx.Start(context.Background())  // 启动fx
defer fx.Stop(context.Background())  // 关闭fx


func NewHandler(lc fx.Lifecycle)  {
  // do some thing
  lc.Append(fx.Hook{
    OnStart:func(context.Context) error {
        //  启动模块
        return err
    },
    OnStop: func(context.Context) error{
        // 做一些回收工作
        return err
    }
  })
}
```

在每个被Invoke的函数定义OnStart和OnStop函数，会在fx.Start 和 fx.Stop执行时按定义顺序执行相应的启动函数，用起来还是很方便的。