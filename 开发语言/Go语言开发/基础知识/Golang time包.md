# Golang time包

##### 一、定义

不同于 java 饱受诟病的各种乱七八糟的时间处理相关的包，golang 的 time 包的设计可谓相当精巧。time 包用来描述“时刻”的类型为 Time，其定义如下：

```go
type Time struct {
    // sec gives the number of seconds elapsed since
    // January 1, year 1 00:00:00 UTC.
    sec int64

    // nsec specifies a non-negative nanosecond
    // offset within the second named by Seconds.
    // It must be in the range [0, 999999999].
    nsec int32

    // loc specifies the Location that should be used to
    // determine the minute, hour, month, day, and year
    // that correspond to this Time.
    // The nil location means UTC.
    // All UTC times are represented with loc==nil, never loc==&utcLoc.
    loc *Location
}
```

如其注释所述，sec 记录其距离 UTC 时间0年1月1日0时的秒数， nsec 记录一个 0~999999999 的纳秒数，loc 记录所在时区。事实上，仅需要 sec 和 nsec 就完全可以描述一个时间点了——“该时间点是距离 UTC 时间0年1月1日0时 sec 秒、nsec 纳秒的时间点”——非常准确且非常不容易引起歧义，但这并不符合人们日常生活中描述时间点的方式，我们只会说是某年某月某日，几点几分几秒，然而，一旦要这样说，事实上就涉及到时区了。

当一个 golang 的 Time 实例被程序员问：你记录的是几时几分？这个实例可以说是相当无语的，因为又没说清是在哪个时区下的几点几分，我 TM 怎么知道是几点几分？然而程序员并不买账，因为一个时间点能准确得说出自己是几点几分似乎是天经地义的事，**于是 Time 类不得不自己记一个时区，默认就是这个无脑的程序员所在地的时区（这个值可以向操作系统索要）**，当再次被问几点几分的时候，便可以作答了，而记的地方便是 loc 字段。

2.坑点

站在计算机冰冷的角度来看，“某时区某年某月某日几点几分几秒”是对时间点的人性化描述，而“距离一个众所周知的时间点多少秒、多少纳秒”才是对时间点的准确记录。这一点，在 Time 类型的实现中展现的淋漓尽致。所以，基于对 Time 类型的了解，我们反观一下对时间的一些操作，看看时区在影响着哪些。

时间的比较、求差操作，很明显这类操作是与时区无关的，无论 loc 记录的是什么，只要对 sec 和 nsec 进行比较、求差，就能得出正确的结果。时间的取时、取分操作，不用说了，肯定是需要时区信息参与的。

时间的 format 操作，这里仅指 format 成年月日时分秒的形式，显然也是需要时区参与的。时间的 parse 操作，即 format 的逆向操作，同样需要时区参与。

**而坑点就在这里，一方面，format 操作使用 Time 实例记录的时区，大多数情况下是本地时区；另一方面，parse 操作在并不会默认使用本地时区。**

time.Parse() 会尝试从 value 里读出时区信息，当且仅当：有时区信息、时区信息以 zone offset 形式（如+0800）表示、表示结果与本地时区等价时，才会使用本地时区，否则使用读出的时区。若 value 里没有时区信息，则使用 UTC 时间。这便是第一个坑点。

相比之下，第二个坑点便算不上什么大事了——不要使用 == 去比较时间是否相等。golang 可没有什么重载运算符的说法，**使用 == 比较两个 Time 实例时，事实上就是比较 sec、nsec、loc 三个字段是否都相等**。然而如我所述，仅需要 sec 和 nsec 就完全可以描述一个时间点了，所以只要这两个字段相等，两个 Time 实例就是指的同一个时间点。而仅因为 loc 值的不同，便判定两个 Time 实例不相等，这是非常荒谬的。这就是为什么应该使用 Equal 比较时间点是否相等的原因。

```go
func main() {
    // format 字符串为 年月日时分秒，没有时区信息
    format := "20060102150405"

    // t1 没有写 time.Now() 是为了避免秒以下单位的时间的影响
    // 除此之外和写 time.Now() 是一样的
    t1 := time.Date(2017, time.November, 30, 0, 0, 0, 0, time.Local)

    // t1 使用本地时区进行 format，结果是 "20171130000000"
    // 由进行 parse，由于没有指定时区，结果是 UTC 时间 2017/11/30 00:00:00
    t2, _ := time.Parse(format, t1.Format(format))
    
    // t1 使用本地时区进行 format，结果是 "20171130000000"
    // t2 使用 UTC 时间进行 format，结果是 "20171130000000"
    // 所以输出 true
    println("1-1 ", t1.Format(format) == t2.Format(format))
    
    // 很显然不相等，既不是指同一个时间点，时区信息也不一样，所以输出 false
    println("1-2 ", t1 == t2)
    
    // 显然不相等，t1 和 t2 不是指同一个时间点，所以输出 false
    println("1-3 ", t1.Equal(t2))

    // t1 使用本地时区进行 format，结果是 "20171130000000"
    // 由进行 parse，指定了本地时区，结果是本地时间 2017/11/30 00:00:00
    t2, _ = time.ParseInLocation(format, t1.Format(format), time.Local)
    
    // 显然相等，输出 true
    println("2-1 ", t1.Format(format) == t2.Format(format))
    // 既指同一个时间点，时区信息也一样，输出 true
    println("2-2 ", t1 == t2)
    // 显然相等，输出 true
    println("2-3 ", t1.Equal(t2))

    // 原本 t2 与 t1 完全相等，现在将 t2 改为 UTC 时间 
    t2 = t2.UTC()
    
    // t1 使用本地时区进行 format，结果是 "20171130000000"
    // t2 使用 UTC 时间进行 format，结果是 "20171129160000"
    // 所以输出 false
    println("3-1 ", t1.Format(format) == t2.Format(format))
    
    // t1 和 t2 表示了相同的时间点，但各自时区信息不同，所以输出 false
    println("3-2 ", t1 == t2)
    
    // 由于 t1 和 t2 表示了相同的时间点，所以输出 true
    println("3-3 ", t1.Equal(t2))
}
```

3.在docker中

很明显，若要避免不必要的麻烦，就要正确地使用 time 包——而这句话的大前提是操作系统的时区设置是正确的，否则一切都是空谈。

显然绝大多数的 PC、服务器的时区设置肯定是正确（是吧？要不你检查下？）。需要提高警惕的是 docker 用户，docker 在编译镜像、启动容器时均不会继承宿主机的时区设置。如果容器内的服务对时间不敏感，可能仅是输出日志的时间不是本地时间的问题，而如果服务对时间敏感，比如每天早上九点执行某任务，可能就要出错了。以设为上海时区为例，解决方法有两个，可视情况取舍。

要么在镜像编译时指定好时区：

```go
...
RUN rm /etc/localtime && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
...
```

要`么在容器启动时指定好时区：

```go
docker run -e TZ="Asia/Shanghai" -v /etc/localtime:/etc/localtime:ro ...
```

##### 二、[golang时间戳和时间的转化](https://blog.csdn.net/feiwutudou/article/details/81001453)

```go
 //获取当前时间
   //2018-07-11 15:07:51.8858085 +0800 CST m=+0.004000001
   t := time.Now() 
   fmt.Println(t)
 
   //获取当前时间戳
   fmt.Println(t.Unix()) //1531293019
 
   //获得当前的时间
    //2018-7-15 15:23:00
   fmt.PrintIn(t.Uninx().Format("2006-01-02 15:04:05"))  
 
   //时间 to 时间戳
   //设置时区
   loc, _ := time.LoadLocation("Asia/Shanghai")        
   //2006-01-02 15:04:05是转换的格式如php的"Y-m-d H:i:s"
   tt, _ := time.ParseInLocation("2006-01-02 15:04:05", "2018-07-11 15:07:51", loc) 
   fmt.Println(tt.Unix())                             //1531292871
 
   //时间戳 to 时间
   tm := time.Unix(1531293019, 0)
   //2018-07-11 15:10:19
   fmt.Println(tm.Format("2006-01-02 15:04:05")) 
 
   //获取当前年月日,时分秒
   y := t.Year()                 //年
   m := t.Month()                //月
   d := t.Day()                  //日
   h := t.Hour()                 //小时
   i := t.Minute()               //分钟
   s := t.Second()               //秒
   //2018 July 11 15 24 59
   fmt.Println(y, m, d, h, i, s) 
}
```

##### 三、[GO-time.after 用法](https://www.cnblogs.com/qggg/p/8571808.html)

```go
// After waits for the duration to elapse and then sends the current time
// on the returned channel.
// It is equivalent to NewTimer(d).C.
// The underlying Timer is not recovered by the garbage collector
// until the timer fires. If efficiency is a concern, use NewTimer
// instead and call Timer.Stop if the timer is no longer needed.
func After(d Duration) <-chan Time {
    return NewTimer(d).C
}
```

直译就是：

等待参数duration时间后，向返回的chan里面写入当前时间。和NewTimer(d).C效果一样，直到计时器触发，垃圾回收器才会恢复基础计时器。如果担心效率问题, 请改用 NewTimer, 然后调用计时器. 不用了就停止计时器。

解释一下，是什么意思呢？

就是调用time.After(duration)，此函数马上返回，返回一个time.Time类型的Chan，不阻塞。后面你该做什么做什么，不影响。到了duration时间后，自动塞一个当前时间进去。你可以阻塞的等待，或者晚点再取。因为底层是用NewTimer实现的，所以如果考虑到效率低，可以直接自己调用NewTimer。

```go
package main

import (
    "time"
    "fmt"
)

func main()  {
    tchan := time.After(time.Second*3)
    fmt.Printf("tchan type=%T\n",tchan)
    fmt.Println("mark 1")
    fmt.Println("tchan=",<-tchan)
    fmt.Println("mark 2")
}
```

上面的例子运行结果如下

```go
tchan type=<-chan time.Time
mark 1
tchan= 2018-03-15 09:38:51.023106 +0800 CST m=+3.015805601
mark 2
```

首先瞬间打印出前两行，然后等待3S，打印后后两行。