# Golang内存逃逸分析

## 1.堆&栈

在c语言中，应用程序的虚拟内存空间划分为堆空间和栈空间，两者都是合法的空间，那为什么还要专门区分开来呢？主要是为了内存空间的分配和管理的需要

栈内存分配非常快，是自动创建和销毁的，不需要开发人员的编程语言运行时过多的参与

看下面这样一段c程序：

```c
#include <stdio.h>

void foo() {
    int c = 11;
    printf("c = %d\n", c);
}

int main() {
    int a = 11;
 	printf("a = %d\n", a);
 	foo();
}
```

c编译器会自动把上面这段c程序里的变量分配到栈的内存空间上，无需关注何时创建和销毁，一切都是自动进行的。但是如果将变量的地址返回到函数的外部，那么运行下面的程序就会报错：

```c
#include <stdio.h>
  
int *foo() {
    int c = 11;
    return &c;
}

int main() {
    int *p = foo();
    printf("foo = %d\n", *p);
}

//结果：
cstack_dumpcore.c: In function ‘foo’:
cstack_dumpcore.c:5:12: warning: function returns address of local variable [-Wreturn-local-addr]
     return &c;
			^~
```

这样一来就需要一种内存对象，可以在全局（跨函数间）合法使用，这就是堆内存对象。但是和位于栈上的内存对象由程序自行创建销毁不同，堆内存对象需要通过专用API手工分配和释放，在C中对应的分配和释放方法就是malloc和free，如下面的代码，变量c在堆中开辟了空间：

```c
#include <stdio.h>
#include <stdlib.h>

int *foo() {
 	int *c = malloc(sizeof(int));
 	*c = 12;
	return c;
}

int main() {
 	int *p = foo();
 	printf("foo = %d\n", *p);
 	free(p);
}
```

可见在c语言中，对内存的分配和管理会占用程序员很多的时间和增加负担，所以GO语言这种带有自动垃圾回收的语言出现了，这种带有GC的语言会自动管理堆上的对象，当某个对象不可达（没有被引用）时会被自动回收，虽然自动GC减轻了程序员的压力，但是却带来了性能损耗，在堆上的数据越多，GC带来的性能损耗越大，于是人们开始想办法减少在堆上的内存分配，可以在栈上分配的变量尽量留在栈上

**逃逸分析：就是在程序编译阶段根据程序代码中的数据流，对代码中哪些变量需要在栈上分配，哪些变量需要在堆上分配进行静态分析的方法**

## 2.GO语言中的内存逃逸

上面讲了栈和堆的关系，也介绍了上面是逃逸分析，再看看GO语言中的内存逃逸

```go
package main

func foo(b int)(*int) {
    var a int = 11;
    return &a;
}

func main() {
    c := foo(666)
    println(*c)
}

//结果：
11
```

这里的foo函数返回了局部变量的地址到函数的外部，在上面c语言的例子中已经报错了，但是在GO语言中却没有报错

其实，GO语言这样设计可以释放程序员关于内存的使用限制，更多的让程序员关注于程序功能逻辑本身

GO语言编译器会自动决定把一个变量放在栈还是放在堆，编译器会做 **逃逸分析** ，当发现变量的作用域没有跑出函数范围，就可以在栈上，反之则必须分配在堆

比如下面这个例子：

```go
package main

func foo(b int) (*int) {
    var a1 int = 11;
    var a2 int = 12;
    var a3 int = 13;
    var a4 int = 14;
    var a5 int = 15;

    for i := 0; i < 5; i++ {
        println(&b, &a1, &a2, &a3, &a4, &a5)
    }

    return &a3;
}
func main() {
    p := foo(666)
    println(*p, p)
}
```

查看逃逸分析日志：

```bash
$ go build -gcflags=-m 1_example.go
# command-line-arguments
./1_example.go:3:6: can inline foo
./1_example.go:17:6: can inline main
./1_example.go:18:10: inlining call to foo
./1_example.go:6:2: moved to heap: a3
```

由 moved to heap: a3 可知发现确实发生了内存逃逸，a3是被runtime.newobject()在堆空间开辟的，而不是像其他几个是基于地址偏移开辟的栈空间

现在使用new来初始化变量，看看是否还会在堆中开辟内存

```go
package main

func fooss(b int) *int {
	a1 := new(int)
	a2 := new(int)
	a3 := new(int)
	a4 := new(int)
	a5 := new(int)

	for i := 0; i < 5; i++ {
		println(b, a1, a2, a3, a4, a5)
	}

	return a3
}

func main() {
	p := fooss(666)
	println(*p, p)
}
```

查看逃逸分析日志：

```bash
$ go build -gcflags=-m 1_new_example.go
# command-line-arguments
./1_new_example.go:3:6: can inline fooss
./1_new_example.go:17:6: can inline main
./1_new_example.go:18:12: inlining call to fooss
./1_new_example.go:4:11: new(int) does not escape
./1_new_example.go:5:11: new(int) does not escape
./1_new_example.go:6:11: new(int) escapes to heap
./1_new_example.go:7:11: new(int) does not escape
./1_new_example.go:8:11: new(int) does not escape
./1_new_example.go:18:12: new(int) does not escape
./1_new_example.go:18:12: new(int) does not escape
./1_new_example.go:18:12: new(int) does not escape
./1_new_example.go:18:12: new(int) does not escape
./1_new_example.go:18:12: new(int) does not escape
```

由 ./1_new_example.go:6:11: new(int) escapes to heap 这一行可以看到依然发生了内存逃逸

可以得出结论：Golang中一个函数内局部变量，不管是不是动态new出来的，它会被分配在堆还是栈，是由编译器做逃逸分析之后做出的决定

## 3.会出现内存逃逸的典型情况

① 第一种：如上面所描述的，在方法内返回局部变量的地址，局部变量原本应该在栈中分配，在栈中回收，但是由于返回时被外部引用，因此其生命周期大于栈，则溢出

② 第二种：当栈空间不足时，会把对象分配到堆中，此时也会发生内存逃逸

当创建1000长度的切片时：

```go
package main

func main() {
	s := make([]int, 1000, 1000)
	for index, _ := range s {
		s[index] = index
	}
}
$ go build -gcflags=-m 3_make1000_example.go 
# command-line-arguments
./3_make1000_example.go:4:11: make([]int, 1000, 1000) does not escape
```

由结果 does not escape 可知没有发生内存逃逸

当创建10000长度的切片时：

```go
package main

func main() {
	s := make([]int, 10000, 10000)
	for index, _ := range s {
		s[index] = index
	}
}
$ go build -gcflags=-m 3_make10000_example.go
# command-line-arguments
./3_make10000_example.go:4:11: make([]int, 10000, 10000) escapes to heap
```

由结果 escapes to heap 可知发生了内存逃逸

③ 第三种：发送指针或带有指针的值到 channel 中，在编译时，没有办法知道哪个 goroutine 会在 channel 上接收数据。所以编译器无法知道变量什么时候才会被释放

④ 第四种：在一个切片上存储指针或带指针的值。一个典型的例子就是 []*string ，这会导致切片的内容逃逸，尽管其后面的数组可能是在栈上分配的，但其引用的值一定是在堆上

⑤ 第五种：在 interface 类型上调用方法。 在 interface 类型上调用方法都是动态调度的 —— 方法的真正实现只能在运行时知道。想像一个 io.Reader 类型的变量 r , 调用 r.Read(b) 会使得 r 的值和切片b 的背后存储都逃逸掉，所以会在堆上分配

问：有时候面试会问，指针传递一定比值传递效率更高吗？

答案是：不是绝对的，在拷贝数据量大的时候，指针传递通过传递地址的方式确实可以提高传递效率；但是当传递数据量小的时候，如果还发生了内存逃逸，那么反而会增加性能消耗，降低效率

## 4.总结

- 堆上动态分配内存比栈上静态分配内存，开销大很多
- 变量分配在栈上需要能在编译期确定它的作用域，否则会分配到堆上
- 对于Go程序员来说，编译器的这些逃逸分析规则不需要掌握，只需通过go build -gcflags ‘-m’命令来观察变量逃逸情况就行
- 不要盲目使用变量的指针作为函数参数，虽然它会减少复制操作，但其实当参数为变量自身的时候，复制是在栈上完成的操作，开销远比变量逃逸后动态地在堆上分配内存少的多
- 逃逸分析在编译阶段完成