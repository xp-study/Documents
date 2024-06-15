# 图解zab算法

ZAB协议，全称 Zookeeper Atomic Broadcast（Zookeeper 原子广播协议）。它是专门为分布式协调服务——Zookeeper，设计的一种支持 **崩溃恢复** 和 **原子广播** 的协议。

从设计上看，ZAB协议和 [Raft](https://www.tpvlog.com/article/66) 很类似。ZooKeeper集群中，只有一个Leader节点，其余均为Follower节点。整个ZAB协议一共定义了三个阶段： **发现（Discovery）** 、 **同步（Synchronization）** 、 **广播（Broadcast）** 。

三个阶段执行完为一个周期，在Zookeeper集群的整个生命周期中，这三个阶段会不断进行，如果Leader崩溃或因其它原因导致Leader缺失，ZAB协议会再次进入阶段一。

## 一、角色

在ZooKeeper中，一共有两类节点（一个Leader节点和N个Follower节点），每个节点都会在 **Looking** 、 **Following** 、 **Leading** 状态间不断转换：


![img](https://mc.wsh-study.com/mkdocs/图解zab算法/1.png)

## 二、发现（Discovery）

发现（Discovery），类似于Raft中的领导者选举，该阶段会要求zookeeper集群必须选出一个Leader节点，该Leader的ZXID是全局最大的。

### 2.1 ZXID

ZAB协议中，使用ZXID作为事务编号，针对每个客户端的一个请求，Leader都会产生一个Proposal事务，以ZXID作为全局唯一标识：

![img](https://mc.wsh-study.com/mkdocs/图解zab算法/2.png)

ZXID的低32位是一个递增的计数器，表示该事务的序号；高32位是Leader的任期编号（epoch）。每个新选举出的Leader节点，会取出本地日志中最大事务Proposal的ZXID，然后解析出对应的epoch，把该值加1作为该新Leader节点的epoch，然后将低32位重新从0开始计。

### 2.2 选举流程

在ZAB协议中，出现以下几种情况会开始进行Leader选举：

- Leader节点宕机；
- Leader节点失去了与过半Follower节点的心跳联系；
- 集群初始化时。

Leader的选举流程如下：

1. 每个Follower节点都向所有其它节点广播Vote投票请求，即请求自己成为Leader；
2. 如果Follower接受到的Vote请求中的ZXID比自身的大，则投票同意，并更新自身的Vote，否则拒绝；
3. 每个Follower都维护着一个投票记录表，当某个Follower节点收到过半的选票时，结束投票并把该Follower选为Leader。

## 三、同步（Synchronization）

当选举出Leader后，该Leader具有全局最大的ZXID，所以同步阶段的工作就是根据Leader的事务日志对Follower节点进行数据同步：

1. Leader节点根据Follower节点发送过来的FOllOWERINFO请求（包含Follower节点的最大ZXID），响应NEWLEADER消息告知自己已经成为它的新Leader；
2. Leader节点根据Follower的最大ZXID（lastZXID），向Follower发送更新指令：
   - SNAP ：如果Follower的数据太老，Leader将发送快照SNAP指令给Follower同步数据；
   - DIFF ：发送从Follolwer.lastZXID到Leader.lastZXID的DIFF指令给Follower同步数据；
   - TRUNC ：当Follower.lastZXID比Leader.lastZXID大时，Leader发送从Leader.lastZXID到Follower.lastZXID的TRUNC指令让Follower丢弃该段数据，即回滚；
3. Follower同步成功后回复ACKNETLEADER；
4. 最后，Leader会把该Follower节点添加到自己的可用Follower列表中。

## 四、广播（Broadcast）

ZAB 协议的消息广播过程使用的是一个原子广播协议，类似二阶段提交，大体流程如下：

1.对于客户端发送的写请求，全部由 Leader 接收，如果Follower接受到则会转发给Leader。

2.Leader将请求封装成一个事务 Proposal（每个Proposal都有一个全局单调递增的ID，即ZXID），然后广播给每个 Follwer节点。

![img](https://mc.wsh-study.com/mkdocs/图解zab算法/3.png)

> Leader会为每个Follower节点准备一个单独的队列，事务按照ZXID大小顺序排列入队，然后根据FIFO策略进行发送。这样做是为了保证事务的顺序一致性。

3.每个Follower节点收到事务Proposal后，会先写本地日志，成功后返回一个ACK响应；Follower节点如果无法处理，则直接抛弃请求。

![img](https://mc.wsh-study.com/mkdocs/图解zab算法/4.png)

4.Leader收到过半Follower节点的ACK响应后，就会广播一个Commit消息给所有Follower，通知它们进行事务的提交。与此同时，Leader节点自身也会进行事务的提交。

![img](https://mc.wsh-study.com/mkdocs/图解zab算法/5.png)

5.各个Follower节点收到Commit消息后，就会完成对事务的提交。

## 五、总结

Leslie Lamport的 Multi-Paxos 只考虑了如何实现共识，也就是如何就一系列值达成共识，未考虑如何实现各值（也就是操作）的顺序性。最终 ZooKeeper 实现了基于Master/Slave模式的ZAB协议，保证了操作的顺序性，而且，ZAB 协议的实现，影响到了后来的共识算法，也就是 Raft 算法，Raft 除了能就一些值达成共识，还能保证各值的顺序性。

