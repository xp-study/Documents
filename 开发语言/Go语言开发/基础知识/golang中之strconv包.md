# golang中之strconv包

在编程过程中，我们常常需要用到字符串与其它类型的转换，strconv包可以帮我们实现此功能。

# 1.string -> int

- 使用方法：`func Atoi(s string) (i int, err error)`
- 测试代码：

```go
numStr := "999"
num, err := strconv.Atoi(numStr)
if err != nil {
    fmt.Println("can't convert to int")
} else {
    fmt.Printf("type:%T value:%#v\n", num, num)
}
```

输出：type:int value:999

* 另外还可以用：

  ```go 
  func ParseInt(s string, base int, bitSize int) (i int64, err error)
  ```

  或

  ```go
  func ParseUint(s string, base int, bitSize int) (n uint64, err error)
  ```

base指定进制（2到36），如果base为0，则会从字符串前置判断，”0x”是16进制，”0”是8进制，否则是10进制；

bitSize指定结果必须能无溢出赋值的整数类型，0、8、16、32、64 分别代表 int、int8、int16、int32、int64；

# 2. int -> string

- 使用方法：`func Itoa(i int) string`

- 测试代码：

```go
num := 200
numStr := strconv.Itoa(num)
fmt.Printf("type:%T value:%#v\n", numStr, numStr)
```

输出：type:string value:"200"

# 3. string->bool

* 使用方法：`func ParseBool(str string) (bool, error)`

  当str为：1，t，T，TRUE，true，True中的一种时为真值

  当str为：0，f，F，FALSE，false，False中的一种时为假值

- 测试代码

```go
fmt.Println(strconv.ParseBool("t"))
fmt.Println(strconv.ParseBool("TRUE"))
fmt.Println(strconv.ParseBool("true"))
fmt.Println(strconv.ParseBool("True"))
fmt.Println(strconv.ParseBool("0"))
fmt.Println(strconv.ParseBool("f"))
```

# 4.string->float

* 使用方法：`func ParseFloat(s string, bitSize int) (f float64, err error)`

  bitSize：32或64 对应系统的位数

* 测试代码

```go
strF := "250.56"
str, err := strconv.ParseFloat(strF, 64)
if err != nil {
    fmt.Println(err)
}
fmt.Printf("type:%T value:%#v\n", str, str)
```

输出：type:float64 value:250.56

# 5. float -> string

* 使用方法：`func FormatFloat(f float64, fmt byte, prec, bitSize int) string`

  bitSize表示f的来源类型（32：float32、64：float64），会据此进行舍入。

fmt表示格式：’f’（-ddd.dddd）、’b’（-ddddp±ddd，指数为二进制）、’e’（-d.dddde±dd，十进制指数）、’E’（-d.ddddE±dd，十进制指数）、’g’（指数很大时用’e’格式，否则’f’格式）、’G’（指数很大时用’E’格式，否则’f’格式）。

prec控制精度（排除指数部分）：对’f’、’e’、’E’，它表示小数点后的数字个数；对’g’、’G’，它控制总的数字个数。如果prec 为-1，则代表使用最少数量的、但又必需的数字来表示f。

- 测试代码：

```go
num := 250.56
str := strconv.FormatFloat(num, 'f', 4,64)
fmt.Printf("type:%T value:%#v\n", str, str)
```

输出：type:string value:"250.5600"

当然，以上类型转string的话，可以直接用`fmt.Sprintf`实现。

举个例子：

```go
num := 250.56
str := fmt.Sprintf("%.2f", num)
fmt.Printf("type:%T value:%#v\n", str, str)
```

输出：type:string value:"250.56"