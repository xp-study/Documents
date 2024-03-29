# ElasticSearch客户端的实现

## 1.介绍

`Elasticsearch（ES）`是一个基于`Lucene`构建的开源、分布式、`RESTful`接口的全文搜索引擎。`Elasticsearch`还是一个分布式文档数据库，其中每个字段均可被索引，而且每个字段的数据均可被搜索，`ES`能够横向扩展至数以百计的服务器存储以及处理 **PB** 级的数据。可以在极短的时间内存储、搜索和分析大量的数据。通常作为具有复杂搜索场景情况下的核心发动机。根据`DB-Engines`的排名显示，`Elasticsearch`是最受欢迎的企业搜索引擎。

在`Go`语言中经常使用的包有以下两个,截止到(2021.07.10):

|            包            |                    文档                     | Star 数量 |    说明    |
| :----------------------: | :-----------------------------------------: | :-------: | :--------: |
|     olivere/elastic      |     https://olivere.github.io/elastic/      |   6.1k    |  社区开源  |
| elastic/go-elasticsearch | https://github.com/elastic/go-elasticsearch |   3.5k    | ES官方提供 |

## 2.安装

这里使用`olivere/elastic`， **@注意: 下载包的版本需要和ES版本相同，如我们这里使用的ES是7.13.3的版本，那么我们就需要下载`olivere/elastic/v7`。**

```go
# 安装v7的版本
go get github.com/olivere/elastic/v7
```

## 3. 使用

### 3.1 创建客户端

```go
package test

import (
 "context"
 "fmt"
 "github.com/olivere/elastic/v7"
 "log"
 "os"
 "testing"
 "time"
)

// 连接Es
func connectEs() (*elastic.Client, error) {
 return elastic.NewClient(
  // 设置Elastic服务地址
  elastic.SetURL("http://127.0.0.1:9200"),
  // 是否转换请求地址，默认为true,当等于true时 请求http://ip:port/_nodes/http，将其返回的url作为请求路径
  elastic.SetSniff(false),
  // 心跳检查,间隔时间
  elastic.SetHealthcheckInterval(time.Second*5),
  // 设置错误日志
  elastic.SetErrorLog(log.New(os.Stderr, "ES-ERROR ", log.LstdFlags)),
  // 设置info日志
  elastic.SetInfoLog(log.New(os.Stdout, "ES-INFO ", log.LstdFlags)),
 )
}
// 测试连接
func TestConnectES(t *testing.T) {
 client, err := connectEs()
 if err != nil {
  t.Error(err)
  return
 }
 // 健康检查
 do, _ := client.ClusterHealth().Index().Do(context.TODO())
 fmt.Println("健康检查:",do)
}
/** 输出
=== RUN   TestConnectES
ES-ERROR 2021/07/04 11:41:02 Deprecation warning: 299 Elasticsearch-7.13.3-5d21bea28db1e89ecc1f66311ebdec9dc3aa7d64 "Elasticsearch built-in security features are not enabled. Without authentication, your cluster could be accessible to anyone. See https://www.elastic.co/guide/en/elasticsearch/reference/7.13/security-minimal-setup.html to enable security."
ES-INFO 2021/07/04 11:41:02 GET http://127.0.0.1:9200/_cluster/health [status:200, request:0.007s]
健康检查: &{laradock-cluster yellow false 1 1 8 8 0 0 1 0 0 0  0  88.88888888888889 map[]}
--- PASS: TestConnectES (0.02s)
PASS
*/
```

**a.参数设置整理**

```go
// 用来设置ES服务地址，如果是本地，就是127.0.0.1:9200。支持多个地址，用逗号分隔即可
elastic.SetURL(url)
// 基于http base auth验证机制的账号和密码
elastic.SetBasicAuth("user", "secret")
// 启用gzip压缩
elastic.SetGzip(true),
// 设置监控检查时间间隔
elastic.SetHealthcheckInterval(10*time.Second),
// 允许指定弹性是否应该定期检查集群，默认为true,会把请求http://ip:port/_nodes/http，
// 并将其返回的publish_address作为请求路径
elastic.SetSniff(false)
// 设置错误日志
elastic.SetErrorLog(log.New(os.Stderr, "ELASTIC-ERROR ", log.LstdFlags)),
// 设置info日志
elastic.SetInfoLog(log.New(os.Stdout, "ELASTIC-INFO ", log.LstdFlags)),
```

> **@注意：如果你的ElasticSearch是通过docker安装，若不设置`elastic.SetSniff(false)`，会报错: `no active connection found: no Elasticsearch node available`**

### 3.2 创建索引

```go
// 创建索引(指定mapping)
func TestCreateIndexMapping(t *testing.T) {
 userMapping := `{
    "mappings":{
        "properties":{
            "name":{
                "type":"keyword"
            },
            "age":{
                "type":"byte"
            },
            "birth":{
                "type":"date"
            }
        }
    }
}`
 client, _ := connectEs()
 // 检测索引是否存在
 indexName := "go-test"
 // 创建上下文
 ctx := context.Background()
 exist, err := client.IndexExists(indexName).Do(ctx)
 if err != nil {
  t.Errorf("检测索引失败:%s", err)
  return
 }
 if exist {
  t.Error("索引已经存在，无需重复创建！")
  return
 }
 res, err := client.CreateIndex(indexName).BodyString(userMapping).Do(ctx)
 if exist {
  t.Errorf("创建索引失败:%s", err)
  return
 }
 fmt.Println("创建成功:", res)
}
/**输出
=== RUN   TestCreateIndexMapping
创建成功: &{true true go-test}
--- PASS: TestCreateIndexMapping (0.13s)
PASS
*/
```

**如果想直接创建索引，只需删除`BodyString(userMapping)`,如下:**

```go
// 指定userMapping创建
res, err := client.CreateIndex(indexName).BodyString(userMapping).Do(ctx)
// 直接创建
res, err := client.CreateIndex(indexName).Do(ctx)
```

### 3.3 添加数据

#### 1. 单条添加

```go
type UserInfo struct {
 Name  string `json:"name"`
 Age   int    `json:"age"`
 Birth string `json:"birth"`
}

// 单条添加
func TestAddOne(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()
 // 创建userInfo
 userInfo := UserInfo{
  Name:  "张三",
  Age:   18,
  Birth: "1991-03-04",
 }
 res, err := client.Index().Index("go-test").Id("1").BodyJson(userInfo).Do(ctx)
 if err != nil {
  t.Errorf("添加失败:%s",err)
 }
 fmt.Println("添加成功",res)
}
/**输出
=== RUN   TestAddOne
添加成功 &{go-test _doc 1 1 created 0xc000212100 0 1 0 false}
--- PASS: TestAddOne (0.01s)
PASS
*/
```

#### 2. 批量添加

```go
// 批量添加
func TestBatchAdd(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()
 // 创建用户
 userNames := map[string]string{
  "李四": "1992-04-25",
  "张亮": "1994-07-15",
  "小明": "1991-12-03",
 }
 rand.Seed(time.Now().Unix())
 // 创建bulk
 userBulk := client.Bulk().Index("go-test")
 id := 4
 for n, b := range userNames {
  userTmp := UserInfo{Name: n, Age: rand.Intn(50), Birth: b}
  // 批量添加到bulk
  doc := elastic.NewBulkIndexRequest().Id(strconv.Itoa(id)).Doc(userTmp)
  userBulk.Add(doc)
  id++
 }
 // 检查被添加数据是否为空
 if userBulk.NumberOfActions() < 1 {
  t.Error("被添加的数据不能为空！")
  return
 }
 // 保存
 res, err := userBulk.Do(ctx)
 if err != nil {
  t.Errorf("保存失败:%s", err)
  return
 }
 fmt.Println("保存成功: ", res)
}
/** 输出
=== RUN   TestBatchAdd
保存成功:  &{3 false [map[index:0xc000136100] map[index:0xc000136180] map[index:0xc000136200]]}
--- PASS: TestBatchAdd (0.01s)
PASS
```

### 3.4 单条更新

#### 1. 单字段更新(`Script`)

```go
// 通过Script方式更新
func TestUpdateOneByScript(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()

 // 根据id更新
 res, err := client.Update().Index("go-test").Id("1").
  Script(elastic.NewScript("ctx._source.birth='1999-09-09'")).Do(ctx)
 if err != nil {
  t.Errorf("根据ID更新单条记录失败:%s", err)
  return
 }
 fmt.Println("根据ID更新成功:", res.Result)
 
 // 根据条件更新, update .. where name = '阿三'
 res2, err := client.UpdateByQuery("go-test").Query(elastic.NewTermQuery("name", "小明")).
  Script(elastic.NewScript("ctx._source.age=22")).ProceedOnVersionConflict().Do(ctx)
 if err != nil {
  t.Errorf("根据条件更新单条记录失败:%s", err)
  return
 }
 fmt.Println("根据条件更新成功:", res2.Updated)
}
/**输出
=== RUN   TestUpdateOneByScript
根据ID更新成功: updated
根据条件更新成功: 1
--- PASS: TestUpdateOneByScript (0.02s)
PASS
*/
```

#### 2. 多字段更新(`doc`)

```go
// 使用Doc更新多个字段
func TestUpdateOneByDoc(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()
 res, _ := client.Update().Index("go-test").Id("5").Doc(map[string]interface{}{
  "name": "小白", "age": 30,
 }).Do(ctx)
 fmt.Println("更新结果:", res.Result)
}
/**输出
=== RUN   TestUpdateOneByDoc
更新结果: updated
--- PASS: TestUpdateOneByDoc (0.01s)
PASS
*/
```

### 3.5 批量更新

```go
// 批量修改
func TestBatchUpdate(t *testing.T) {
 client,_ := connectEs()
 ctx := context.Background()
 bulkReq := client.Bulk().Index("go-test")
 for _, id := range []string{"4","5","6","7"} {
  doc := elastic.NewBulkUpdateRequest().Id(id).Doc(map[string]interface{}{"age": 18})
  bulkReq.Add(doc)
 }
 // 被更新的数量不能小于0
 if bulkReq.NumberOfActions() < 0 {
  t.Error("被更新的数量不能为空")
  return
 }
 // 执行操作
 do, err := bulkReq.Do(ctx)
 if err != nil {
  t.Errorf("批量更新失败:%v",err)
  return
 }
 fmt.Println("更新成功:",do.Updated())
}
/**输出
=== RUN   TestBatchUpdate
更新成功: [0xc000266000 0xc000266080 0xc000266100 0xc000266180]
--- PASS: TestBatchUpdate (0.01s)
PASS
*/
```

### 3.6 查询

#### 1. 单条查询

```go
// 查询单条
func TestSearchOneEs(t *testing.T) {
 client,_ := connectEs()
 ctx := context.Background()
 // 查找一条
 getResult, err := client.Get().Index("go-test").Id("1").Do(ctx)
 if err != nil {
  t.Errorf("获取失败: %s",err)
  return
 }
 // 提取查询结果(json格式)
 json, _ := getResult.Source.MarshalJSON()
 fmt.Printf("查询单条结果:%s \n",json)
}
/**输出
=== RUN   TestSearchEs
结果:{"name":"阿三","birth":"1999-09-09","age":20} 
--- PASS: TestSearchEs (0.01s)
PASS
*/
```

#### 2. 批量查询

```go
// 查询多条
func TestSearchMoreES(t *testing.T) {
 client,_ := connectEs()
 ctx := context.Background()
 searchResult, err := client.Search().Index("go-test").
  Query(elastic.NewMatchQuery("age", 18)).
  From(0). //从第几条开始取
  Size(10). // 取多少条
  Pretty(true).
  Do(ctx)
 if err != nil {
  t.Errorf("获取失败: %s",err)
  return
 }
 // 定义用户结构体
 var userList []UserInfo
 for _, val := range searchResult.Each(reflect.TypeOf(UserInfo{})) {
  tmp := val.(UserInfo)
  userList = append(userList,tmp)
 }
 fmt.Printf("查询结果:%v\n",userList)
}
/**输出
=== RUN   TestSearchMoreES
查询结果:[{小明 18 1991-12-03} {小白 18 1995-11-11} {李四 18 1992-04-25} {李亮 18 1994-07-15}]
--- PASS: TestSearchMoreES (0.01s)
PASS
*/
```

### 3.7 删除

#### 1. 根据ID删除

```go
//  根据ID删除
func TestDelById(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()
 // 根据ID删除
 do, err := client.Delete().Index("go-test").Id("1").Do(ctx)
 if err != nil {
  t.Errorf("删除失败:%s",err)
  return
 }
 fmt.Println("删除成功: ",do.Result)
}
/**输出
=== RUN   TestDelById
删除成功:  deleted
--- PASS: TestDelById (0.02s)
PASS
*/
```

#### 2. 根据条件删除

```go
// 根据条件删除
func TestDelByWhere(t *testing.T) {
 client, _ := connectEs()
 ctx := context.Background()
 // 根据条件删除
 do, err := client.DeleteByQuery("go-test").Query(elastic.NewTermQuery("age", 18)).
  ProceedOnVersionConflict().Do(ctx)
 if err != nil {
  t.Errorf("删除失败:%s",err)
  return
 }
 fmt.Println("删除成功: ",do.Deleted)
}
/**输出
=== RUN   TestDelByWhere
删除成功:  4
--- PASS: TestDelByWhere (0.02s)
PASS
*/
```