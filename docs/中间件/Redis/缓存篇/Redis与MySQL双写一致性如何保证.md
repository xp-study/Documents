# Redis与MySQL双写一致性如何保证


![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/1.jpg)

一致性就是数据保持一致，在分布式系统中，可以理解为多个节点中数据的值是一致的。


- Cache-Aside Pattern
- Read-Through/Write-through
- Write-behind

### Cache-Aside Pattern

#### Cache-Aside读流程

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/2.jpg)

1. 读的时候，先读缓存，缓存命中的话，直接返回数据
2. 缓存没有命中的话，就去读数据库，从数据库取出数据，放入缓存后，同时返回响应。

#### Cache-Aside 写流程

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/3.jpg)

### Read-Through/Write-Through（读写穿透）

 **Read/Write-Through** 模式中，服务端把缓存作为主要数据存储。应用程序跟数据库缓存交互，都是通过 **抽象缓存层** 完成的。

#### Read-Through

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/4.jpg)

1. 从缓存读取数据，读到直接返回
2. 如果读取不到的话，从数据库加载，写入缓存后，再返回响应。

这个简要流程是不是跟 **Cache-Aside** 很像呢？其实 **Read-Through** 就是多了一层 **Cache-Provider** 而已，流程如下：

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/5.jpg)Read-Through流程

#### Write-Through

 **Write-Through** 模式下，当发生写请求时，也是由 **缓存抽象层** 完成数据源和缓存数据的更新,流程如下：

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/6.jpg)

### Write-behind （异步缓存写入）

 **Write-behind**  跟Read-Through/Write-Through有相似的地方，都是由 **Cache Provider** 来负责缓存和数据库的读写。它们又有个很大的不同： **Read/Write-Through** 是同步更新缓存和数据的， **Write-Behind** 则是只更新缓存，不直接更新数据库，通过 **批量异步** 的方式来更新数据库。

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/7.jpg)

这种方式下，缓存和数据库的一致性不强， **对一致性要求高的系统要谨慎使用** 。但是它适合频繁写的场景，MySQL的 **InnoDB Buffer Pool机制** 就使用到这种模式。

日常开发中，我们一般使用的就是 **Cache-Aside** 模式。有些小伙伴可能会问，  **Cache-Aside** 在写入请求的时候，为什么是 **删除缓存而不是更新缓存** 呢？

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/8.jpg)

我们在操作缓存的时候，到底应该删除缓存还是更新缓存呢？我们先来看个例子：

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/9.jpg)

1. 线程A先发起一个写操作，步先更新数据库
2. 线程B再发起一个写操作，第二步更新了数据库
3. 由于网络等原因，线程B先更新了缓存
4. 线程A更新缓存。

这时候，缓存保存的是A的数据（老数据），数据库保存的是B的数据（新数据），数据 **不一致** 了，脏数据出现啦。如果是 **删除缓存取代更新缓存** 则不会出现这个脏数据问题。


- 如果你写入的缓存值，是经过复杂计算才得到的话。更新缓存频率高的话，就浪费性能啦。
- 在写数据库场景多，读数据场景少的情况下，数据很多时候还没被读取到，又被更新了，这也浪费了性能呢(实际上，写多的场景，用缓存也不是很划算的,哈哈)


`Cache-Aside`缓存模式中，有些小伙伴还是会有疑问，在写请求过来的时候，为什么是 **先操作数据库呢** ？为什么 **不先操作缓存** 呢？

假设有A、B两个请求，请求A做更新操作，请求B做查询读取操作。![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/10.jpg)

1. 线程A发起一个写操作，步del cache
2. 此时线程B发起一个读操作，cache miss
3. 线程B继续读DB，读出来一个老数据
4. 然后线程B把老数据设置入cache
5. 线程A写入DB新的数据


- 个别小伙伴可能会问，先操作数据库再操作缓存，不一样也会导致数据不一致嘛？它俩又不是原子性操作的。这个是 **会的** ，但是这种方式，一般因为删除缓存失败等原因，才会导致脏数据，这个概率就很低。小伙伴们可以画下操作流程图，自己先分析下哈。接下来我们再来分析这种 **删除缓存失败** 的情况， **如何保证一致性** 。

- 分布式锁

其实，这是由 **CAP理论** 决定的。缓存系统适用的场景就是非强一致性的场景，它属于CAP中的AP。 **个人觉得，追求一致性的业务场景，不适合引入缓存** 。

> CAP理论，指的是在一个分布式系统中， Consistency（一致性）、 Availability（可用性）、Partition tolerance（分区容错性），三者不可得兼。”

### 缓存延时双删

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/11.jpg)

1. 先删除缓存
2. 再更新数据库
3. 休眠一会（比如1秒），再次删除缓存。

这个休眠一会，一般多久呢？都是1秒？

> 这个休眠时间 =  读业务逻辑数据的耗时 + 几百毫秒。为了确保读请求结束，写请求可以删除读请求可能带来的缓存脏数据。”

这种方案还算可以，只有休眠那一会（比如就那1秒），可能有脏数据，一般业务也会接受的。但是如果 **第二次删除缓存失败** 呢？缓存和数据库的数据还是可能不一致，对吧？给Key设置一个自然的expire过期时间，让它自动过期怎样？那业务要接受 **过期时间** 内，数据的不一致咯？还是有其他更佳方案呢？

### 删除缓存重试机制

不管是 **延时双删** 还是 **Cache-Aside的先操作数据库再删除缓存** ，都可能会存在第二步的删除缓存失败，导致的数据不一致问题。可以使用这个方案优化：删除失败就多删除几次呀,保证删除缓存成功就可以了呀~ 所以可以引入 **删除缓存重试机制**  

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/12.jpg)

1. 写请求更新数据库
2. 缓存因为某些原因，删除失败
3. 把删除失败的key放到消息队列
4. 消费消息队列的消息，获取要删除的key
5. 重试删除缓存操作

### 读取biglog异步删除缓存

重试删除缓存机制还可以吧，就是会造成好多 **业务代码入侵** 。其实，还可以这样优化：通过数据库的 **binlog来异步淘汰key** 。

![img](https://mc.wsh-study.com/mkdocs/Redis与MySQL双写一致性如何保证/13.jpg)

以mysql为例吧

- 可以使用阿里的canal将binlog日志采集发送到MQ队列里面
- 然后通过ACK机制确认处理这条更新消息，删除缓存，保证数据缓存一致性
