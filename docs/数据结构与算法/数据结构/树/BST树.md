# BST树

## 一、前言

Binary Search Tree历史，二叉搜索树算法是由包括 PF Windley、Andrew Donald Booth、Andrew Colin、Thomas N. Hibbard 在内的几位研究人员独立发现的。该算法归功于 Conway Berners-Lee 和 David Wheeler ，他们在 1960 年使用它在磁带中存储标记数据。最早和流行的二叉搜索树算法之一是 Hibbard 算法。

## 二、二叉搜索树数据结构

二叉搜索树（Binary Search Tree），也称二叉查找树。如果你看见有序二叉树（Ordered Binary tree）、排序二叉树（Sorted Binary Tree）那么说的都是一个东西。

![img](https://mc.wsh-study.com/mkdocs/BST树/1.png)

- 若任意节点的左子树不空，则左子树上所有节点的值均小于它的根节点的值；
- 若任意节点的右子树不空，则右子树上所有节点的值均大于它的根节点的值；
- 任意节点的左、右子树也分别为二叉查找树；

二叉搜索树在日常开发中使用的场景还是比较多的，例如基于组合模式实现的规则引擎，它就是一颗二叉搜索树。但类似这样的开发中用到的二叉树场景，都是基于配置生成，所以组合出来的节点也更加方便控制树高和平衡性。这与 Java API HashMap 中的红黑树这样为了解决插入节点后仍保持树的平衡性是有所不同的。

所以二叉搜索树也是一颗没有经过调衡的基础性数据结构，在一定概率上它完全有可能退化成链表，也就是从近似O(logn)的时间复杂度退化到O(n)。关于二叉搜索树的平衡解决方案，包括；AVL树、红黑树等。

## 三、二叉搜索树结构实现

二叉搜索树是整个树结构中最基本的树，同时也是树这个体系中实现起来最容易的数据结构。但之所以要使用基于二叉搜索树之上的其他树结构，主要是因为使用数据结构就是对数据的存放和读取。那么为了提高吞吐效率，则需要尽可能的平衡元素的排序，体现在树上则需要进行一些列操作，所以会有不同的结构树实现。而实现二叉搜索树是最好的基础学习，了解基本的数据结构后才更容易扩展学习其他树结构。

### 1. 节点定义

```java
public class Node<K extends Comparable<K>, V> {

    public K key;

    public V value;

    public Node<K, V> parent;

    public Node<K, V> left;

    public Node<K, V> right;

    public Node(K key, V value) {
        this.key = key;
        this.value = value;
    }
}
```

- 用于组成一颗树的节点，则需要包括值和与之关联的三角结构，一个父节点、两个孩子节点。如果是AVL树还需要树高，红黑树还需要染色标记。

### 2. 插入节点

```java
        if (root == null) {
            root = new Node(key, value);
            return;
        }

        // 1. 索引出待插入元素位置，也就是插入到哪个父元素下
        Node<K, V> parent = root;
        Node<K, V> search = root;
        while (search != null) {
            parent = search;
            if (key.compareTo(search.key) == 0) {
                search.value = value;
                return;
            }

            search = key.compareTo(search.key) < 0 ? search.left : search.right;
        }

        // 2. 创建节点并将节点设置为红色
        Node<K, V> node = new Node(key, value);
        if (key.compareTo(parent.key) < 0) {
            parent.left = node;
        } else {
            parent.right = node;
        }
        node.parent = parent;
```

- 首先判断插入元素时候是否有树根，没有则会把当前节点创建出一颗树根来。
- 如果当前树是有树根的，则对插入元素与当前树进行一个节点遍历操作，找到元素可以插入的索引位置 parent（挂到这个父节点下），也就是 search 搜索过程。
- 最后就是插入元素，通过给插入值创建一个 Node 节点，并绑定它的父元素，以及把新元素挂到索引到的 parent 节点下。

### 3. 索引节点

```java
    public Node<K, V> search(K key) {
        if (key == null) {
            return null;
        }
        Node<K, V> search = root;
        while (search != null) {
            if (key.compareTo(search.key) == 0) {
                return search;
            }
            search = key.compareTo(search.key) < 0 ? search.left : search.right;
        }
        return null;
    }
```

- 值查找的过程，就是对二叉搜索树的遍历，不断的循环节点，按照节点值的左右匹配，找出最终相当的值节点。

### 4. 删除节点

```java
    public void remove(K key) {

        // 检索待删除节点
        Node<K, V> search = search(key);

        if (search == null) {
            return;
        }

        delete(search);
    }

    public void delete(Node<K, V> node) {
        if (node == null) {
            return;
        }

        if (node.left == null && node.right == null) {
            if (node == root) {
                root = null;
                return;
            }

            if (node == node.parent.left) {
                node.parent.left = null;
            }

            if (node == node.parent.right) {
                node.parent.right = null;
            }

            node.left = null;
            node.right = null;
            node.parent = null;
            return;
        }

        if (node.left != null && node.right != null) {
            Node<K, V> successor = node.right;
            while (successor.left != null) {
                successor = successor.left;
            }
            node.key = successor.key;
            node.value = successor.value;
            delete(successor);
            return;
        }

        Node<K, V> replace = node.left == null ? node.right : node.left;
        transplant(node, replace);
    }

    protected void transplant(Node node, Node replace) {
        if (node == root) {
            root = replace;
        } else if (node.key.compareTo(node.parent.left.key) == 0) {
            node.parent.left = replace;
        } else {
            node.parent.right = replace;
        }

        // 设置父节点
        if (replace != null) {
            replace.parent = node.parent;
        }
    }
```

* 首先查找key对应的节点，若key不存在直接返回即可。
* 若key对应的节点是一个叶子节点，直接删除即可；若对应的节点只有一个孩子节点，可以用它的直接孩子节点替换掉该节点的位置，也就是上述代码中的`transplant`方法。

## 四、二叉搜索树完整代码

```java
package com.tree;

public class BinarySearchTree<K extends Comparable<K>, V> implements BinaryTreeInfo {

    public Node<K, V> root;

    public void put(K key, V value) {
        insert(key, value);
    }

    public void insert(K key, V value) {
        if (root == null) {
            root = new Node(key, value);
            return;
        }

        Node<K, V> parent = root;
        Node<K, V> search = root;
        while (search != null) {
            parent = search;
            if (key.compareTo(search.key) == 0) {
                search.value = value;
                return;
            }

            search = key.compareTo(search.key) < 0 ? search.left : search.right;
        }

        Node<K, V> node = new Node(key, value);
        if (key.compareTo(parent.key) < 0) {
            parent.left = node;
        } else {
            parent.right = node;
        }
        node.parent = parent;
    }

    public V get(K key) {
        Node<K, V> Node = search(key);
        return Node == null ? null : Node.value;
    }

    public Node<K, V> search(K key) {
        if (key == null) {
            return null;
        }
        Node<K, V> search = root;
        while (search != null) {
            if (key.compareTo(search.key) == 0) {
                return search;
            }
            search = key.compareTo(search.key) < 0 ? search.left : search.right;
        }
        return null;
    }

    public void remove(K key) {

        // 检索待删除节点
        Node<K, V> search = search(key);

        if (search == null) {
            return;
        }

        delete(search);
    }

    public void delete(Node<K, V> node) {
        if (node == null) {
            return;
        }

        if (node.left == null && node.right == null) {
            if (node == root) {
                root = null;
                return;
            }

            if (node == node.parent.left) {
                node.parent.left = null;
            }

            if (node == node.parent.right) {
                node.parent.right = null;
            }

            node.left = null;
            node.right = null;
            node.parent = null;
            return;
        }

        if (node.left != null && node.right != null) {
            Node<K, V> successor = node.right;
            while (successor.left != null) {
                successor = successor.left;
            }
            node.key = successor.key;
            node.value = successor.value;
            delete(successor);
            return;
        }

        Node<K, V> replace = node.left == null ? node.right : node.left;
        transplant(node, replace);
    }

    protected void transplant(Node node, Node replace) {
        if (node == root) {
            root = replace;
        } else if (node.key.compareTo(node.parent.left.key) == 0) {
            node.parent.left = replace;
        } else {
            node.parent.right = replace;
        }

        // 设置父节点
        if (replace != null) {
            replace.parent = node.parent;
        }
    }
}

```

## 五、常见面试题

- 二叉搜索树结构简述&变T的可能也让手写
- 二叉搜索树的插入、删除、索引的时间复杂度
- 二叉搜索树删除含有双子节点的元素过程叙述
- 二叉搜索树的节点都包括了哪些信息
- 为什么Java HashMap 中说过红黑树而不使用二叉搜索树
