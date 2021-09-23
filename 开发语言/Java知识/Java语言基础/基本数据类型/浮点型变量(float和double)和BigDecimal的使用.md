# 浮点型变量(float和double)和BigDecimal的使用

1、浮点型变量(float和double)

带小数的变量在Java中称为浮点型，**Java的浮点型有两种：float和double。**

float类型代表单精度浮点数，占4个字节、32位。double类型代表双精度浮点数，占8个字节、64位。

**Java语言的浮点数有两种表示形式：**

**1）十进制数形式**：例如3.14、314.0、0.314。浮点数必须包含一个小数点，否则会被当成int类型处理。

**2）科学计数法形式**：例如3.14e2（即3.14*102），31.4e-2（即314*10-2）。

 必须指出的是，只有浮点型的数值才可以使用科学计数法形式表示。例如31400是一个int类型的值，但314E2则是浮点类型的值。

**Java语言的浮点类型默认是double类型**，如果希望Java把一个浮点类型值当成float类型处理，应该在这个浮点类型值的后面紧跟F或f。例如3.14代表一个double类型的值，占64位的内存空间；3.14F才表示一个float类型的值，占32位的内存空间。当然也可以在一个浮点数后添加D或d后缀，强制指定double类型，但通常没必要。

**Java还提供了三个特殊的浮点数值：正无穷大、负无穷大和非数，用于表示溢出和出错**。例如，使用一个正数除以0将得到正无穷大，使用负数除以0将得到负无穷大，0.0除以0.0或对一个负数开方将得到一个非数。正无穷大通过Double或Float类的POSITIVE_INFINITY表示；负无穷大通过Double或Float类的NEGATIVE_INFINITY表示，非数通过Double或Float类的NaN表示。

必须指出的是，所有的正无穷大数值都是相等的，所有的负无穷大数值都是相等的；而NaN不与任何数值相等，甚至和NaN都不相等。

 注：只有浮点数除以0才可以得到正无穷大或负无穷大，如果一个整数除以0则会抛出一个异常：ArithmeticException:/by zero（除以0异常）。

2、BigDecimal

　由于Java浮点数使用二进制数据的科学计数法表示，所以可能不能精确表示一个浮点数。如果需要进行不产生误差的精确数字计算，需要使用BigDecimal类。

先看如下程序：

**1）浮点数的比较一** 

```java
float f = 0.1f;
double d = 1.0/10;
//结果为false
System.out.println(f==d);
```

**2）浮点数的比较二**

```java
float d1 = 423432423f;
float d2 = d1+1;
if(d1==d2){
   //输出结果为 d1==d2     
   System.out.println("d1==d2"); 
}else{
         System.out.println("d1!=d2");
      }
```

上面程序运行结果表明，Java的浮点数会发生精度丢失，尤其在算术运算时更易发生这种情况，所以，不要使用浮点数进行运算和比较！

创建BigDecimal对象的构造器有很多，建议使用**BigDecimal(String val)**这个构造器，因为这个结果是可以预知的，例如，new BigDecimal("0.2")将创建一个BigDecimal，它正好等于预期的0.2，因此通常建议优先使用基于BigDecimal的构造器。

如果必须使用double浮点数作为BigDecimal构造器的参数时，不要直接将该double浮点数作为构造器参数创建BigDecimal对象，而是通过**BigDecimal.valueOf(double value)**静态方法来创建BigDecimal对象。



**总结：**

**老鸟建议**：浮点类型float，double的数据不适合在不容许舍入误差的金融计算领域。如果需要进行不产生舍入误差的精确数字计算，需要使用BigDecimal类。

**菜鸟雷区**：不要使用浮点数进行比较！很多新人甚至很多理论不扎实的有工作经验的程序员也会犯这个错误！需要比较请使用BigDecimal类。