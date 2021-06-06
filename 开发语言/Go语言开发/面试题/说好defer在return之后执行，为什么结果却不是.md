## 说好defer在return之后执行，为什么结果却不是

```
package main

import (
 "fmt"
)

func hello(i *int) int {
 defer func() {
  *i = 19
 }()
 return *i
}

func main() {
 i := 10
 j := hello(&i)
 fmt.Println(i, j)
}
```

答题结果如下：

![图片](./images/说好defer在return之后执行/1.jpg)

正确答案：19 10，正确率堪忧，才 32%。

这篇文章简单解释下。

我们先看 i 的值。因为 hello 接收的是指针，因此里面对参数值的修改会改变传递的值，这个不需要关心是不是在 defer 里面。所以，i 最终的值是 19。从投票结果看，i = 19 答对人数较多。

再来看 j 的值，即 hello 函数的返回值，在这个函数中，return 语句处，`*i` 的值是 10，迷惑点在于 defer 中的 `*i = 19`。大家都知道 defer 语句在 return 语句之后执行，相信很多人也看到过类似的题目，defer 修改了函数返回的值。但那是针对命名返回值。比如 hello 改为这样：

```
func hello(i *int) (j int) {
  defer func() {
    j = 19
  }()
  j = *i
  return j
}
```

这时候，虽然 return 时，j 的值是 10，但在 defer 语句中 j 被改为 19 了，而且这个 j 是函数的命名返回值，因此会影响最终函数的返回值。甚至这样写，函数的返回值依然是 19：

```
func hello(i *int) (j int) {
  defer func() {
    j = 19
  }()
  return *i
}
```

当然，通过汇编也可以看到这两者的写法的区别。但其实大家只需要知道，命名返回值，就好比函数参数一样，函数体内对命名返回值的任何修改，都会影响它。而非命名返回值，取决于 return 时候的值。

看似一道简单的题目，但却有迷惑性，因此需要大家对原理有所掌握。
