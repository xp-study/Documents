# 分布式ID解决方案

分布式ID的两大核心需求：

## UUID

基于 `UUID` 实现全球唯一的ID。用作订单号`UUID`这样的字符串没有丝毫的意义，看不出和订单相关的有用信息；而对于数据库来说用作业务`主键ID`，它不仅是太长还是字符串，存储性能差查询也很耗时，所以不推荐用作`分布式ID`。

- 生成足够简单，本地生成无网络消耗，具有唯一性
- 无序的字符串，不具备趋势自增特性
- 没有具体的业务含义，看不出和订单相关的有用信息
- 长度过长16 字节128位，36位长度的字符串，存储以及查询对MySQL的性能消耗较大，MySQL官方明确建议主键要尽量越短越好，作为数据库主键 `UUID` 的无序性会导致数据位置频繁变动，严重影响性能
- 可以用来生成如token令牌一类的场景，足够没辨识度，而且无序可读，长度足够
- 可以用于无纯数字要求、无序自增、无可读性要求的场景

## 数据库自增ID

基于数据库的 `auto_increment` 自增ID完全可以充当 `分布式ID` 。当我们需要一个ID的时候，向表中插入一条记录返回`主键ID`，但这种方式有一个比较致命的缺点，访问量激增时MySQL本身就是系统的瓶颈，用它来实现分布式服务风险比较大，不推荐。相关SQL如下：

```sql
 CREATE DATABASE `SEQ_ID`;
 CREATE TABLE SEQID.SEQUENCE_ID (
     id bigint(20) unsigned NOT NULL auto_increment, 
     value char(10) NOT NULL default '',
     PRIMARY KEY (id),
 ) ENGINE=MyISAM;
 
 insert into SEQUENCE_ID(value)  VALUES ('values');
```
- 实现简单，ID单调自增，数值类型查询速度快
- DB单点存在宕机风险，无法扛住高并发场景
- 小规模的，数据访问量小的业务场景
- 无高并发场景，插入记录可控的场景

## 数据库多主模式

单点数据库方式不可取，那对上述的方式做一些高可用优化，换成主从模式集群。一个主节点挂掉没法用，那就做双主模式集群，也就是两个Mysql实例都能单独的生产自增ID。

MySQL_1 配置：
```sql
 set @@auto_increment_offset = 1;     -- 起始值
 set @@auto_increment_increment = 2;  -- 步长
 -- 自增ID分别为：1、3、5、7、9 ...... 
```

MySQL_2 配置：
```sql
 set @@auto_increment_offset = 2;     -- 起始值
 set @@auto_increment_increment = 2;  -- 步长
 -- 自增ID分别为：2、4、6、8、10 ......
```

那如果集群后的性能还是扛不住高并发咋办？则进行MySQL扩容增加节点：
![MySQL数据库多主模式.jpg](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/1.png)
- 解决DB单点问题
- 不利于后续扩容，而且实际上单个数据库自身压力还是大，依旧无法满足高并发场景
- 数据量不大，数据库不需要扩容的场景

这种方案，除了难以适应大规模分布式和高并发的场景，普通的业务规模还是能够胜任的，所以这种方案还是值得积累。

## 数据库号段模式

号段模式是当下分布式ID生成器的主流实现方式之一，可以理解为从数据库批量的获取自增ID，每次从数据库取出一个号段范围，例如 (1,1000] 代表1000个ID，具体的业务服务将本号段，生成1~1000的自增ID并加载到内存。表结构如下：

```sql
 CREATE TABLE id_generator (
   id int(10) NOT NULL,
   max_id bigint(20) NOT NULL COMMENT '当前最大id',
   step int(20) NOT NULL COMMENT '号段的步长',
   biz_type  int(20) NOT NULL COMMENT '业务类型',
   version int(20) NOT NULL COMMENT '版本号',
   PRIMARY KEY (`id`)
 ) 
```
biz_type ：代表不同业务类型
max_id ：当前最大的可用id
step ：代表号段的长度
version ：是一个乐观锁，每次都更新version，保证并发时数据的正确性

| id   | biz_type | max_id | step | version |
| ---- | -------- | ------ | ---- | ------- |
| 1    | 101      | 1000   | 2000 | 0       |

等这批号段ID用完，再次向数据库申请新号段，对`max_id`字段做一次`update`操作，`update max_id= max_id + step`，update成功则说明新号段获取成功，新的号段范围是`(max_id ,max_id +step]`。

```sql
update id_generator set max_id=max_id+${step}, version = version+1 where version=${version} and biz_type=${XXX}
复制代码
```
由于多业务端可能同时操作，所以采用版本号`version`乐观锁方式更新，这种`分布式ID`生成方式不强依赖于数据库，不会频繁的访问数据库，对数据库的压力小很多。

## Redis模式

`Redis`也同样可以实现，原理就是利用`redis`的 `incr`命令实现ID的原子性自增。
```bash
  # 初始化自增ID为1
 127.0.0.1:6379> set seq_id 1
 OK
 
 # 增加1，并返回递增后的数值
 127.0.0.1:6379> incr seq_id
 (integer) 2
```

用`redis`实现需要注意一点，要考虑到`redis`持久化的问题。`redis`有两种持久化方式`RDB`和`AOF`：
- `RDB`：会定时打一个快照进行持久化，假如连续自增但`redis`没及时持久化，而这会`redis`挂掉了，重启`redis`后会出现ID重复的情况
- `AOF`：会对每条写命令进行持久化，即使`Redis`挂掉了也不会出现ID重复的情况，但由于incr命令的特殊性，会导致`Redis`重启恢复的数据时间过长
- 有序递增，可读性强
- 能够满足一定性能
- 强依赖于Redis，可能存在单点问题
- 占用宽带，而且需要考虑网络延时等问题带来地性能冲击
- 对性能要求不是太高，而且规模较小业务较轻的场景，而且Redis的运行情况有一定要求，注意网络问题和单点压力问题，如果是分布式情况，那考虑的问题就更多了，所以一帮情况下这种方式用的比较少

Redis的方案其实可靠性有待考究，毕竟依赖于网络，延时故障或者宕机都可能导致服务不可用，这种风险是不得不考虑在系统设计内的。

## 雪花算法（Snowflake）

雪花算法（Snowflake）是Twitter公司内部分布式项目采用的ID生成算法，开源后广受国内大厂的好评，在该算法影响下各大公司相继开发出各具特色的分布式生成器。

![雪花算法（SnowFlake）.jpg](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/2.png)

`Snowflake`生成的是Long类型的ID，一个Long类型占8个字节，每个字节占8比特，也就是说一个Long类型占64个比特。Snowflake ID组成结构：`正数位`（占1比特）+ `时间戳`（占41比特）+ `机器ID`（占5比特）+ `数据中心`（占5比特）+ `自增值`（占12比特），总共64比特组成的一个Long类型。

- 每秒能够生成百万个不同的ID，性能佳
- 时间戳值在高位，中间是固定的机器码，自增的序列在地位，整个ID是趋势递增的
- 能够根据业务场景数据库节点布置灵活挑战bit位划分，灵活度高
- 雪花算法有很明显的缺点就是时钟依赖，如果确保机器不存在时钟回拨情况的话，那使用这种方式生成分布式ID是可行的，当然小规模系统完全是能够使用的

## 百度uid-generator项目

UidGenerator项目基于snowflake原理实现，只是修改了机器ID部分的定义（实例重启的次数），并且64位bit的分配支持配置，官方提供的默认分配方式如下图：

![百度实现的默认snowflake结构](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/3.png)

Snowflake算法描述：指定机器 & 同一时刻 & 某一并发序列，是唯一的。据此可生成一个64 bits的唯一ID（long）。

- sign(1bit) 固定1bit符号标识，即生成的UID为正数。
- delta seconds (28 bits) 当前时间，相对于时间基点"2016-05-20"的增量值，单位：秒，最多可支持约8.7年。
- worker id (22 bits) 机器id，最多可支持约420w次机器启动。内置实现为在启动时由数据库分配，默认分配策略为用后即弃，后续可提供复用策略。
- sequence (13 bits) 每秒下的并发序列，13 bits可支持每秒8192个并发。

具体的实现有两种，一种是实时生成ID，另一种是预先生成ID方式

1. DefaultUidGenerator

- 启动时向数据库WORKER_NODE表插入当前实例的IP，Port等信息，再获取该数据的自增长ID作为机器ID部分。

简易流程图如下：

![UidGenerator启动过程](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/4.png)

- 提供获取ID的方法，并且检测是否有时钟回拨，有回拨现象直接抛出异常，当前版本不支持时钟顺拨后漂移操作。简易流程图如下：

![UidGenerator生成过程](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/5.png)

核心代码如下：
```java
     * Get UID
     *
     * @return UID
     * @throws UidGenerateException in the case: Clock moved backwards; Exceeds the max timestamp
     */
    protected synchronized long nextId() {
        long currentSecond = getCurrentSecond();

        // Clock moved backwards, refuse to generate uid
        if (currentSecond < lastSecond) {
            long refusedSeconds = lastSecond - currentSecond;
            throw new UidGenerateException("Clock moved backwards. Refusing for %d seconds", refusedSeconds);
        }

        // At the same second, increase sequence
        if (currentSecond == lastSecond) {
            sequence = (sequence + 1) & bitsAllocator.getMaxSequence();
            // Exceed the max sequence, we wait the next second to generate uid
            if (sequence == 0) {
                currentSecond = getNextSecond(lastSecond);
            }

        // At the different second, sequence restart from zero
        } else {
            sequence = 0L;
        }

        lastSecond = currentSecond;

        // Allocate bits for UID
        return bitsAllocator.allocate(currentSecond - epochSeconds, workerId, sequence);
    }
```

1. CachedUidGenerator

机器ID的获取方法与上一种相同，这种是预先生成一批ID，放在一个RingBuffer环形数组里，供客户端使用，当可用数据低于阀值时，再次调用批量生成方法，属于用空间换时间的做法，可以提高整个ID的吞吐量。
- 与DefaultUidGenerator相比较，初始化时多了填充RingBuffer环形数组的逻辑，简单流程图如下：

![CachedUidGenerator启动过程](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/6.png)

核心代码：
```java
     * Initialize RingBuffer & RingBufferPaddingExecutor
     */
    private void initRingBuffer() {
        // initialize RingBuffer
        int bufferSize = ((int) bitsAllocator.getMaxSequence() + 1) << boostPower;
        this.ringBuffer = new RingBuffer(bufferSize, paddingFactor);
        LOGGER.info("Initialized ring buffer size:{}, paddingFactor:{}", bufferSize, paddingFactor);

        // initialize RingBufferPaddingExecutor
        boolean usingSchedule = (scheduleInterval != null);
        this.bufferPaddingExecutor = new BufferPaddingExecutor(ringBuffer, this::nextIdsForOneSecond, usingSchedule);
        if (usingSchedule) {
            bufferPaddingExecutor.setScheduleInterval(scheduleInterval);
        }
        
        LOGGER.info("Initialized BufferPaddingExecutor. Using schdule:{}, interval:{}", usingSchedule, scheduleInterval);
        
        // set rejected put/take handle policy
        this.ringBuffer.setBufferPaddingExecutor(bufferPaddingExecutor);
        if (rejectedPutBufferHandler != null) {
            this.ringBuffer.setRejectedPutHandler(rejectedPutBufferHandler);
        }
        if (rejectedTakeBufferHandler != null) {
            this.ringBuffer.setRejectedTakeHandler(rejectedTakeBufferHandler);
        }
        
        // fill in all slots of the RingBuffer
        bufferPaddingExecutor.paddingBuffer();
        
        // start buffer padding threads
        bufferPaddingExecutor.start();
    }
public synchronized boolean put(long uid) {
        long currentTail = tail.get();
        long currentCursor = cursor.get();

        // tail catches the cursor, means that you can't put any cause of RingBuffer is full
        long distance = currentTail - (currentCursor == START_POINT ? 0 : currentCursor);
        if (distance == bufferSize - 1) {
            rejectedPutHandler.rejectPutBuffer(this, uid);
            return false;
        }

        // 1. pre-check whether the flag is CAN_PUT_FLAG
        int nextTailIndex = calSlotIndex(currentTail + 1);
        if (flags[nextTailIndex].get() != CAN_PUT_FLAG) {
            rejectedPutHandler.rejectPutBuffer(this, uid);
            return false;
        }

        // 2. put UID in the next slot
        // 3. update next slot' flag to CAN_TAKE_FLAG
        // 4. publish tail with sequence increase by one
        slots[nextTailIndex] = uid;
        flags[nextTailIndex].set(CAN_TAKE_FLAG);
        tail.incrementAndGet();

        // The atomicity of operations above, guarantees by 'synchronized'. In another word,
        // the take operation can't consume the UID we just put, until the tail is published(tail.incrementAndGet())
        return true;
    }
```
- ID获取逻辑，由于有RingBuffer这个缓冲数组存在，获取ID直接从RingBuffer取出即可，同时RingBuffer自身校验何时再触发重新批量生成即可，这里获取的ID值与DefaultUidGenerator的明显区别是，DefaultUidGenerator获取的ID，时间戳部分就是当前时间的，CachedUidGenerator里获取的是填充时的时间戳，并不是获取时的时间，不过关系不大，都是不重复的，一样用。简易流程图如下：

![CachedUidGenerator获取过程](https://mc.wsh-study.com/mkdocs/分布式ID解决方案/7.png)

核心代码：
```java
public long take() {
        // spin get next available cursor
        long currentCursor = cursor.get();
        long nextCursor = cursor.updateAndGet(old -> old == tail.get() ? old : old + 1);

        // check for safety consideration, it never occurs
        Assert.isTrue(nextCursor >= currentCursor, "Curosr can't move back");

        // trigger padding in an async-mode if reach the threshold
        long currentTail = tail.get();
        if (currentTail - nextCursor < paddingThreshold) {
            LOGGER.info("Reach the padding threshold:{}. tail:{}, cursor:{}, rest:{}", paddingThreshold, currentTail,
                    nextCursor, currentTail - nextCursor);
            bufferPaddingExecutor.asyncPadding();
        }

        // cursor catch the tail, means that there is no more available UID to take
        if (nextCursor == currentCursor) {
            rejectedTakeHandler.rejectTakeBuffer(this);
        }

        // 1. check next slot flag is CAN_TAKE_FLAG
        int nextCursorIndex = calSlotIndex(nextCursor);
        Assert.isTrue(flags[nextCursorIndex].get() == CAN_TAKE_FLAG, "Curosr not in can take status");

        // 2. get UID from next slot
        // 3. set next slot flag as CAN_PUT_FLAG.
        long uid = slots[nextCursorIndex];
        flags[nextCursorIndex].set(CAN_PUT_FLAG);

        // Note that: Step 2,3 can not swap. If we set flag before get value of slot, the producer may overwrite the
        // slot with a new UID, and this may cause the consumer take the UID twice after walk a round the ring
        return uid;
    }
```

另外有个细节可以了解一下，RingBuffer的数据都是使用数组来存储的，考虑CPU Cache的结构，tail和cursor变量如果直接用原生的AtomicLong类型，tail和cursor可能会缓存在同一个cacheLine中，多个线程读取该变量可能会引发CacheLine的RFO请求，反而影响性能,为了防止伪共享问题，特意填充了6个long类型的成员变量，加上long类型的value成员变量，刚好占满一个Cache Line（Java对象还有8byte的对象头），这个叫CacheLine补齐，有兴趣可以了解一下，源码如下：

```java
public class PaddedAtomicLong extends AtomicLong {
    private static final long serialVersionUID = -3415778863941386253L;

    public volatile long p1, p2, p3, p4, p5, p6 = 7L;

     * Constructors from {@link AtomicLong}
     */
    public PaddedAtomicLong() {
        super();
    }

    public PaddedAtomicLong(long initialValue) {
        super(initialValue);
    }

     * To prevent GC optimizations for cleaning unused padded references
     */
    public long sumPaddingToPreventOptimization() {
        return p1 + p2 + p3 + p4 + p5 + p6;
    }

}
```

以上是百度uid-generator项目的主要描述，我们可以发现，snowflake算法在落地时有一些变化，主要体现在机器ID的获取上，尤其是分布式集群环境下面，实例自动伸缩，docker容器化的一些技术，使得静态配置项目ID，实例ID可行性不高，所以这些转换为按启动次数来标识。

## 美团ecp-uid项目

在uidGenerator方面，美团的项目源码直接集成百度的源码，略微将一些Lambda表达式换成原生的java语法，例如：
```java
// com.myzmds.ecp.core.uid.baidu.impl.CachedUidGenerator类的initRingBuffer()方法
// 百度源码
this.bufferPaddingExecutor = new BufferPaddingExecutor(ringBuffer, this::nextIdsForOneSecond, usingSchedule);

// 美团源码
this.bufferPaddingExecutor = new BufferPaddingExecutor(ringBuffer, new BufferedUidProvider() {
    @Override
    public List<Long> provide(long momentInSecond) {
        return nextIdsForOneSecond(momentInSecond);
    }
}, usingSchedule);
```
并且在机器ID生成方面，引入了Zookeeper，Redis这些组件，丰富了机器ID的生成和获取方式，实例编号可以存储起来反复使用，不再是数据库单调增长这一种了。