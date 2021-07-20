# Golang集合操作

# gset

集合，即不可重复的一组元素，元素项可以为任意类型。

同时，`gset`支持可选的并发安全参数选项，支持并发安全的场景。

**使用场景**：

集合操作。

**使用方式**：

```go
import "github.com/gogf/gf/g/container/gset"
```

**接口文档**：

[https://godoc.org/github.com/gogf/gf/g/container/gset](https://links.jianshu.com/go?to=https%3A%2F%2Fgodoc.org%2Fgithub.com%2Fgogf%2Fgf%2Fg%2Fcontainer%2Fgset)

```go
func New(unsafe ...bool) *Set
func NewSet(unsafe ...bool) *Set
func NewFrom(items interface{}, unsafe...bool) *Set
func (set *Set) Add(item ...interface{}) *Set
func (set *Set) Clear() *Set
func (set *Set) Contains(item interface{}) bool
func (set *Set) Equal(other *Set) bool

func (set *Set) IsSubsetOf(other *Set) bool
func (set *Set) Iterator(f func(v interface{}) bool) *Set
func (set *Set) Join(glue string) string
func (set *Set) Remove(item interface{}) *Set
func (set *Set) Size() int
func (set *Set) Slice() []interface{}
func (set *Set) String() string
func (set *Set) Sum() (sum int)
func (set *Set) Merge(others ...*Set) *Set

func (set *Set) Intersect(others ...*Set) (newSet *Set)
func (set *Set) Diff(others ...*Set) (newSet *Set)
func (set *Set) Union(others ...*Set) (newSet *Set)
func (set *Set) Complement(full *Set) (newSet *Set)

func (set *Set) LockFunc(f func(m map[interface{}]struct{})) *Set
func (set *Set) RLockFunc(f func(m map[interface{}]struct{})) *Set
```

## 使用示例1，基本使用

```go
package main

import (
    "github.com/gogf/gf/g/container/gset"
    "fmt"
)

func main() {
    // 创建一个非并发安全的集合对象
    s := gset.New(true)

    // 添加数据项
    s.Add(1)

    // 批量添加数据项
    s.Add([]interface{}{1, 2, 3}...)

    // 集合数据项大小
    fmt.Println(s.Size())

    // 集合中是否存在指定数据项
    fmt.Println(s.Contains(2))

    // 返回数据项slice
    fmt.Println(s.Slice())

    // 删除数据项
    s.Remove(3)

    // 遍历数据项
    s.Iterator(func(v interface{}) bool {
        fmt.Println("Iterator:", v)
        return true
    })

    // 将集合转换为字符串
    fmt.Println(s.String())

    // 并发安全写锁操作
    s.LockFunc(func(m map[interface{}]struct{}) {
        m[4] = struct{}{}
    })

    // 并发安全读锁操作
    s.RLockFunc(func(m map[interface{}]struct{}) {
        fmt.Println(m)
    })

    // 清空集合
    s.Clear()
    fmt.Println(s.Size())
}
```

执行后，输出结果为：

```go
3
true
[1 2 3]
Iterator: 1
Iterator: 2
[1 2]
map[1:{} 2:{} 4:{}]
0
```

## 使用示例2，交差并补集

我们可以使用以下方法实现交差并补集，并返回一个新的结果集合，

```go
func (set *Set) Intersect(others ...*Set) (newSet *Set)
func (set *Set) Diff(others ...*Set) (newSet *Set)
func (set *Set) Union(others ...*Set) (newSet *Set)
func (set *Set) Complement(full *Set) (newSet *Set)
```

1. `Intersect`: 交集，属于set或属于others的元素为元素的集合。
2. `Diff`: 差集，属于set且不属于others的元素为元素的集合。
3. `Union`: 并集，属于set或属于others的元素为元素的集合。
4. `Complement`: 补集，(前提: set应当为full的子集)属于全集full不属于集合set的元素组成的集合。如果给定的full集合不是set的全集时，返回full与set的差集.

通过集合方法我们可以发现，交差并集方法支持多个集合参数进行计算。以下为简化示例，只使用一个参数集合。

```go
package main

import (
    "fmt"
    "github.com/gogf/gf/g"
    "github.com/gogf/gf/g/container/gset"
)

func main() {
    s1 := gset.NewFrom(g.Slice{1, 2, 3})
    s2 := gset.NewFrom(g.Slice{4, 5, 6})
    s3 := gset.NewFrom(g.Slice{1, 2, 3, 4, 5, 6, 7})

    // 交集
    fmt.Println(s3.Intersect(s1).Slice())
    // 差集
    fmt.Println(s3.Diff(s1).Slice())
    // 并集
    fmt.Println(s1.Union(s2).Slice())
    // 补集
    fmt.Println(s1.Complement(s3).Slice())
}
```

执行后，输出结果为：

```go
[1 2 3]
[4 5 6 7]
[1 2 3 4 5 6]
[7 4 5 6]
```

