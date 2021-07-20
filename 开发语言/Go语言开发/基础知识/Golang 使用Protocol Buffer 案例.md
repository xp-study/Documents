## 1. 前言

工作几年了。[ITDragon龙](https://www.cnblogs.com/itdragon/) 的编程语言从熟悉的Java，到喜欢的Kotlin，最后到一言难尽的Golang。常用的数据交换格式也从xml到json，最后到现在的protobuf。因为底层驱动对数据的采集非常频繁，而且对数据的可读性并没有太高的要求。所以采用序列化体积更小、序列化和反序列化速度更快的protobuf。考虑到后期还会继续深入使用protobuf，先插个眼，方便后期的使用和问题排查。

## 2. Protobuf 简介

> Google Protocol Buffer(简称 Protobuf) 是Google 旗下的一款轻便高效的结构化数据存储格式，平台无关、语言无关、可扩展，可用于通讯协议和数据存储等领域。适合用做数据存储和作为不同应用，不同语言之间相互通信的数据交换格式。

### 2.1 Protobuf 优点

1.支持多种语言、跨平台，多平台之间只需要维护一套proto协议文件（当然还需要对应的配置）。

2.序列化后是二进制流，体积比Json和Xml小，适合数据量较大的传输场景。

3.序列化和反序列化速度很快，据说比Json和Xml快20~100倍。（[ITDragon龙](https://www.cnblogs.com/itdragon/) 本地测过，只有在数据达到一定量时才会有明显的差距）

小结：适合传输数据量较大，对响应速度有要求的数据传输场景。

### 2.2 Protobuf 缺点

1.序列化后的数据不具备可读性。

2.需要一定的额外开发成本（.proto 协议文件），每次修改都需要重新生成协议文件。

3.应用场景并没有Json和Xml广，相对于使用的工具也少。

小结：自解释性较差、通用性较差，不适合用于对基于文本的标记文档建模。

### 2.3 Protobuf Golang 安装使用

step1：下载protobuf 编译器protoc。[下载地址](https://github.com/protocolbuffers/protobuf/releases) 。

step2：下载对应的文件。Windows系统直接将解压后的protoc.exe放在GOPATH/bin目录下（该目录要放在环境变量中）；Linux系统需要make编译。

step3：安装protobuf库文件（因为protoc并没有直接支持go语言）。官方goprotobuf，执行成功后GOPATH/bin目录下会有protoc-gen-go.exe文件

```shell
go get github.com/golang/protobuf/proto
go get github.com/golang/protobuf/protoc-gen-go
```

据说gogoprotobuf库生成的代码质量和编解码性能都比官方的goprotobuf库强，而且完全兼容官方的protobuf。[ITDragon龙](https://www.cnblogs.com/itdragon/) 我们当然也不能放过它。

step4：安装gogoprotobuf库文件。执行成功后GOPATH/bin目录下会有protoc-gen-gofast.exe文件

```shell
go get github.com/gogo/protobuf/proto
go get github.com/gogo/protobuf/gogoproto
go get github.com/gogo/protobuf/protoc-gen-gofast
```

step5：使用protoc 生成go文件。先移步到xxx.proto文件所在目录，再执行以下任意一个命令

```shell
// 官方goprotobuf
protoc --go_out=. *.proto
// gogoprotobuf
protoc --gofast_out=. *.proto
```

step6：protoc是直接支持Java语言，下载后可以直接使用。

```shell
protoc xxx.proto --java_out=./
```

## 3. Protobuf 通讯案例

这里用Golang分别实现socket的服务端和客户端，最后通过protobuf进行数据传输，实现一个简单案例。

### 3.1 创建.proto协议文件

1.创建一个简单的models.proto协议文件

```protobuf
syntax = "proto3";
package protobuf;

message MessageEnvelope{
    int32 TargetId = 1;
    string ID = 2;
    bytes Payload = 3;
    string Type = 4;
}
```

2.通过protoc生成对应的models.pb.go文件（这个文件内容太多，可读性也差，就不贴出来了）

```shell
protoc --gofast_out=. *.proto
```

### 3.2 protobuf编解码

```go
package protobuf

import (
	"fmt"
	"github.com/golang/protobuf/proto"
	"testing"
)

func TestProtocolBuffer(t *testing.T) {
	// MessageEnvelope是models.pb.go的结构体
	oldData := &MessageEnvelope{
		TargetId: 1,
		ID:       "1",
		Type:     "2",
		Payload:  []byte("ITDragon protobuf"),
	}

	data, err := proto.Marshal(oldData)
	if err != nil {
		fmt.Println("marshal error: ", err.Error())
	}
	fmt.Println("marshal data : ", data)

	newData := &MessageEnvelope{}
	err = proto.Unmarshal(data, newData)
	if err != nil {
		fmt.Println("unmarshal err:", err)
	}
	fmt.Println("unmarshal data : ", newData)

}
-----------打印结果-----------
=== RUN   TestProtocolBuffer
marshal data :  [8 1 18 1 49 26 17 73 84 68 114 97 103 111 110 32 112 114 111 116 111 98 117 102 34 1 50]
unmarshal data :  TargetId:1 ID:"1" Payload:"ITDragon protobuf" Type:"2" 
--- PASS: TestProtocolBuffer (0.00s)
PASS
```

### 3.3 socket通讯

1.TCP Server端

```go
func TestTcpServer(t *testing.T) {
	// 为突出重点，忽略err错误判断
	addr, _ := net.ResolveTCPAddr("tcp4", "127.0.0.1:9000")
	listener, _ := net.ListenTCP("tcp4", addr)
	for {
		conn, _ := listener.AcceptTCP()
		go func() {
			for {
				buf := make([]byte, 512)
				_, _ = conn.Read(buf)
				newData := &MessageEnvelope{}
				_ = proto.Unmarshal(buf, newData)
				fmt.Println("server receive : ", newData)
			}
		}()
	}
}
```

2.TCP Client端

```go
func TestTcpClient(t *testing.T) {
	// 为突出重点，忽略err错误判断
	connection, _ := net.Dial("tcp", "127.0.0.1:9000")
	var targetID int32 = 1
	for {
		oldData := &MessageEnvelope{
			TargetId: targetID,
			ID:       strconv.Itoa(int(targetID)),
			Type:     "2",
			Payload:  []byte(fmt.Sprintf("ITDragon protoBuf-%d", targetID)),
		}
		data, _ := proto.Marshal(oldData)
		_, _ = connection.Write(data)
		fmt.Println("client send : ", data)
		time.Sleep(2 * time.Second)
		targetID++
	}
}
```

## 4. Protobuf 基础知识

这里记录工作中常用知识点和对应的注意事项，详细知识点可以通过官网查询：https://developers.google.com/protocol-buffers/docs/proto3

### 4.1 简单模板

举一个简单列子。不同的编程语言的语法差别主要体现在数据类型的不同。

```protobuf
syntax = "proto3"; 					// 指定使用proto3语法
package protobuf;  					// 指定包名

message MessageEnvelope{ 			// 定义一个消息模型
    uint32 TargetId = 1; 			// 定义一个无符号整数类型
    string ID = 2;					// 定义一个字符串类型
    bytes Payload = 3;				// 定义一个字节类型
    MessageType Type = 4;			// 定义一个枚举类型
	repeated Player Players = 5;	// 定义一个集合对象类型
}

enum MessageType {					// 定义一个枚举类型
	SYSTEM = 0;						// 第一个枚举值为零
	ALARM = 1;
}

message Player {
	...
}
```

### 4.2 简单语法

1.**syntax** : 指定使用proto版本的语法，缺省是proto2。若使用syntax语法，则必须位于文件的非空非注释的第一个行。若不指定proto3，却使用了proto3的语法，则会报错。

2.**package** : 指定包名。防止不同 .proto 项目间命名发生冲突。

3.**message** : 定义消息类型。

4.**enum** : 定义枚举类型。第一个枚举值设置为零。

5.**repeated** : 表示被修饰的变量允许重复，可以理解成集合、数组、切片。

6.**map** : 待补充

7.**Oneof** : 待补充

8.**定义变量** : (字段修饰符) + 数据类型 + 字段名称 = 唯一的编号标识符;

9.**编号标识符** ：在message中，每个字段都有唯一的编号标识符。用来在消息的二进制格式中识别各个字段，一旦使用就不能够再改变。[1,15]之内的标识符在编码时占用一个字节。[16,2047]之内的标识符占用2个字节。

10.**变量类型**：以下来源网络整理

|  .proto  | Notes                                                        |   Go    |    Java    |  C++   |     C#     |    Python    |
| :------: | :----------------------------------------------------------- | :-----: | :--------: | :----: | :--------: | :----------: |
|  double  |                                                              | float64 |   double   | double |   double   |    float     |
|  float   |                                                              | float32 |   float    | float  |   float    |    float     |
|  int32   | 使用变长编码，对于负值的效率很低，如果你的域有可能有负值，请使用sint64替代 |  int32  |    int     | int32  |    int     |     int      |
|  uint32  | 使用变长编码                                                 | uint32  |    int     | uint32 |    uint    |   int/long   |
|  uint64  | 使用变长编码                                                 | uint64  |    long    | uint64 |   ulong    |   int/long   |
|  sint32  | 使用变长编码，这些编码在负值时比int32高效的多                |  int32  |    int     | int32  |    int     |     int      |
|  sint64  | 使用变长编码，有符号的整型值。编码时比通常的int64高效。      |  int64  |    long    | int64  |    long    |   int/long   |
| fixed32  | 总是4个字节，如果数值总是比总是比228大的话，这个类型会比uint32高效。 | uint32  |    int     | uint32 |    uint    |     int      |
| fixed64  | 总是8个字节，如果数值总是比总是比256大的话，这个类型会比uint64高效。 | uint64  |    long    | uint64 |   ulong    |   int/long   |
| sfixed32 | 总是4个字节                                                  |  int32  |    int     | int32  |    int     |     int      |
| sfixed64 | 总是8个字节                                                  |  int64  |    long    | int64  |    long    |   int/long   |
|   bool   |                                                              |  bool   |  boolean   |  bool  |    bool    |     bool     |
|  string  | 一个字符串必须是UTF-8编码或者7-bit ASCII编码的文本。         | string  |   String   | string |   string   | str /unicode |
|  bytes   | 可能包含任意顺序的字节据。                                   | []byte  | ByteString | string | ByteString |     str      |

### 4.3 注意事项

1.整数数据类型区分好有符号和无符号类型，建议少用万金油式的int32。

2.将可能频繁使用的字段设置在[1,15]之内，也要注意预留几个，方便后期添加。
