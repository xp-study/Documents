# JAVA8 中 关于Map 新增 computeIfAbsent 方法的使用

#### 方法定义

```java
 /* 
    * @since 1.8
     */
    default V computeIfAbsent(K key,
            Function<? super K, ? extends V> mappingFunction) {
        Objects.requireNonNull(mappingFunction);
        V v;
        if ((v = get(key)) == null) {
            V newValue;
            if ((newValue = mappingFunction.apply(key)) != null) {
                put(key, newValue);
                return newValue;
            }
        }

        return v;
    }
```

可以看到，该方法为java8 新增，具体怎么使用呢？下面以几个例子来说明下：

java8 之前 我们判断 map中一个对象是否存在，如果不存在实例化 一个新的，实现如下：

```java
public class ComputeIfAbsentTest01 {
    
    public static void main(String[] args) {

        List<String> list;

        Map<String, List> map = Maps.newHashMap();

        //java8 之前操作
        list = map.get("list");
        if (list == null) {
            list = new ArrayList<>();
        }
        list.add("Hello");

    }
}
```

必须首先获取然后再做一步非空判断，那么 java8之后我们该如何实现了呢？

```java
public class ComputeIfAbsentTest02 {
    public static void main(String[] args) {

        List<String> list;

        Map<String, List> map = Maps.newHashMap();

        //java8 之后的骚操作
        list = map.computeIfAbsent("list", (key) -> new ArrayList<>());
        list.add("World");

    }
}

```

一行代码搞定 哈哈哈， 怎么理解上述的执行过程呢，下面来解读一下

```java
If the specified key is not already associated with a value (or is mapped to null, attempts to compute its value using the given mapping function and enters it into this map unless null.

如果指定的key 不存在关联的值或者返回 Null,那么就会试着去执行传入的mappingFunction。

对照上面的例子就是，如果从map中获取对应键值 list ，获取不到则执行Function, Function 的结果放入map中，并将该结果返回。

default V computeIfAbsent(K key,Function<? super K, ? extends V> mappingFunction) {
        Objects.requireNonNull(mappingFunction);
        V v;
        //获取的的value不存在
        if ((v = get(key)) == null) {
            V newValue;
            //对传入key 应用 Function
            if ((newValue = mappingFunction.apply(key)) != null) {
                //新value放入map
                put(key, newValue);
                //返回新的value
                return newValue;
            }
        }
        //map中存在则直接返回
        return v;
    }
```

简单的应用场景：我们经常会遇到统计的问题，加入现在有一个字符串集合，需要统计其中字符串出现的次数，该如何实现呢？参照如下代码：

```java
public class ComputeIfAbsentTest03 {
    
    public static void main(String[] args) {

        //java8 实现计算功能统计字符串出现次数
        Map<String, AtomicInteger> countMap = Maps.newHashMap();
        List<String> source = Arrays.asList("hello", "world", "hello", "welcome", "hello", "hello", "welcome", "simon");
        for (String s : source) {
            countMap.computeIfAbsent(s, key -> new AtomicInteger()).getAndIncrement();
        }
        System.out.println(countMap);
    }
}
```

```java
}
```

#### 总结

java8 最大的改变就是引入了函数式编程，使得方法中可以传入了函数，极大的方便了代码的简洁性，但这也给代码的可读性带来了一定难度，希望你能越来越习惯这种 函数式的编程。