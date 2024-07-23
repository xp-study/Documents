# `TopK`问题

## 问题描述

给定整数数组 `nums` 和整数 `k`，请返回数组中第 `k` 个最大的元素。

请注意，你需要找的是数组排序后的第 `k` 个最大的元素，而不是第 `k` 个不同的元素。

你必须设计并实现时间复杂度为 `O(n)` 的算法解决此问题。

**提示：** 

- `1 <= k <= nums.length <= 105`
- `-104 <= nums[i] <= 104`

## 简单排序算法

思路：使用排序算法，将数组排序，然后取出`nums[n-k]`即可。

代码：

```java
    public int findKthLargest(int[] nums, int k) {
        int n = nums.length;
        shellSort(nums);
        return nums[n - k];
    }

    // 希尔排序
    public void shellSort(int[] arr) {
        int n = arr.length;
        // 进行分组,最开始时的增量(gap)为数组长度的一半
        for (int gap = n / 2; gap > 0; gap--) {
            // 对各个分组进行插入排序
            for (int i = gap; i < n; i++) {
                // 将arr[i]插入到所在分组的正确位置上
                insertI(arr, gap, i);
            }
        }
    }

    public void insertI(int[] arr, int gap, int i) {
        int inserted = arr[i];
        int j = i - gap;
        for (; j >= 0 && arr[j] > inserted; ) {
            arr[j + gap] = arr[j];
            j -= gap;
        }
        arr[j + gap] = inserted;
    }
```

**时间复杂度：** `O(n^1.3)`

**空间复杂度：** `O(1)`

## 局部排序

思路：不再全局排序，只对最大的`k`个排序。

![图片](https://mc.wsh-study.com/mkdocs/TopK问题/1.png)

冒泡是一个很常见的排序方法，每冒一个泡，找出最大值，冒`k`个泡，就得到`TopK`。

代码：

```java
    public int findKthLargest(int[] nums, int k) {
        int n = nums.length;
        bubbleSort(nums, k);
        return nums[n - k];
    }

    public int[] bubbleSort(int[] arr, int k) {
        if (arr == null || arr.length < 2) {
            return arr;
        }

        // 当前指针从数组最后一个值开始冒泡
        // 先将当前数组中的最大值冒泡到最后一位
        // 然后当前数组长度减1，在该长度数组中继续寻找最大值
        // 依次类推，直到数组长度为1
        for (int cur = arr.length - 1; cur > arr.length - k; cur--) {
            for (int i = 0; i < cur; i++) {
                if (arr[i] > arr[i + 1]) {
                    swap(arr, i, i + 1);
                }
            }
        }

        return arr;
    }

    // 根据异或运算的交换律和结合律实现交换
    // 其中x ^ x == 0
    // x ^ 0 == x
    public void swap(int[] arr, int i, int j) {
        if (arr[i] == arr[j]) {
            return;
        }
        arr[i] = arr[i] ^ arr[j];
        arr[j] = arr[i] ^ arr[j];
        arr[i] = arr[i] ^ arr[j];
    }
```

**时间复杂度：** `O(nk)`

**空间复杂度：** `O(1)`

**分析** ：冒泡，将全局排序优化为了局部排序，非`TopK`的元素是不需要排序的，节省了计算资源。不少朋友会想到，需求是`TopK`，是不是这最大的`k`个元素也不需要排序呢？这就引出了第三个优化方法。

## 堆排序

思路：只找到`TopK`，不排序`TopK`。

![图片](https://mc.wsh-study.com/mkdocs/TopK问题/2.png)

先用前`k`个元素生成一个小顶堆，这个小顶堆用于存储，当前最大的`k`个元素。

![图片](https://mc.wsh-study.com/mkdocs/TopK问题/3.png)

接着，从第`k+1`个元素开始扫描，和堆顶（堆中最小的元素）比较，如果被扫描的元素大于堆顶，则替换堆顶的元素，并调整堆，以保证堆内的`k`个元素，总是当前最大的`k`个元素。

![图片](https://mc.wsh-study.com/mkdocs/TopK问题/4.png)

直到，扫描完所有`n-k`个元素，最终堆中的`k`个元素，就是求的`TopK`。

代码：

```java
    public int findKthLargest(int[] nums, int k) {
        int n = nums.length;

        int[] arr = new int[k];
        for (int i = 0; i < k; i++) {
            arr[i] = nums[i];
            heapInsert(arr, i);
        }

        for (int i = k; i < n; i++) {
            if (nums[i] > arr[0]) {
                arr[0] = nums[i];
                heapify(arr, 0, k);
            }
        }
        return arr[0];
    }

    // 不断往小根堆添加数的过程
    public void heapInsert(int[] arr, int index) {
        // 若当前节点比父节点大，则将当前节点与父节点交换
        // 并将该节点移动到父节点
        // 依次类推，直到当前节点不比父节点大为止
        while (arr[index] < arr[(index - 1) / 2]) {
            swap(arr, index, (index - 1) / 2);
            index = (index - 1) / 2;
        }
    }

    public void heapify(int[] arr, int index, int size) {
        // 当前节点的左孩子
        // left+1为当前节点的右孩子
        int left = index * 2 + 1;
        while (left < size) {
            // 当前节点的右孩子存在，并且右孩子小于左孩子，选取右孩子，否则选择左孩子
            // 选择当前节点孩子中的最大节点
            int smallest = left + 1 < size && arr[left + 1] < arr[left] ? left + 1 : left;
            // 在当前节点以及当前节点的孩子中选择最小值
            smallest = arr[smallest] < arr[index] ? smallest : index;
            // 若当前节点和当期节点的孩子中的最小值是当前节点自身就退出循环
            if (smallest == index) {
                break;
            }
            // 否则交换当前节与最小值
            swap(arr, smallest, index);
            // 继续往下遍历
            index = smallest;
            left = index * 2 + 1;
        }
    }


    // 根据异或运算的交换律和结合律实现交换
    // 其中x ^ x == 0
    // x ^ 0 == x
    public void swap(int[] arr, int i, int j) {
        if (arr[i] == arr[j]) {
            return;
        }
        arr[i] = arr[i] ^ arr[j];
        arr[j] = arr[i] ^ arr[j];
        arr[i] = arr[i] ^ arr[j];
    }
```

**时间复杂度：** `O(nlogk)`

**空间复杂度：** `O(k)`

## 快速选择算法

思路：利用快排的`partition`过程，不断的分治查找最大的`k`个数，期望时间复杂度可以做到`O(n)`。

代码：
```java
    public int findKthLargest(int[] nums, int k) {
        int n = nums.length;
        return quickSelect(nums, 0, n - 1, n - k);
    }

    public int quickSelect(int[] nums, int left, int right, int k) {
        int[] indexes = partition(nums, left, right);

        // 如果刚刚好查找的数就在中间位置，直接返回arr[k]
        if (k >= indexes[0] && k <= indexes[1]) {
            return nums[k];
        }

        // 如果k位置小于less，则向左进行递归调用
        if (k < indexes[0]) {
            return quickSelect(nums, left, indexes[0] - 1, k);
        }

        // 如果k位置大于more，则向右进行递归调用
        return quickSelect(nums, indexes[1] + 1, right, k);
    }

    // 快速排序过程中的num一般使用数组中的最后一个值
    // 所以不用指定num的值
    // 在使用荷兰国旗问题切割数组的时候，数组的最后一个值是等于num的值
    // 遍历的时候从num的下一个值作为大于区域的边界开始遍历
    // num不作遍历,待数组划分完成后,需要将num放到正确的位置上
    // 此时将大于区域的第一个值与num交换,同时大于区域返回大于区域的第一个值的下标
    public int[] partition(int[] arr, int l, int r) {
        swap(arr, l + (int) (Math.random() * (r - l + 1)), r);
        int less = l - 1;
        int more = r;
        while (l < more) {
            if (arr[l] < arr[r]) {
                less = less + 1;
                swap(arr, less, l);
                l = l + 1;
            } else if (arr[l] > arr[r]) {
                more = more - 1;
                swap(arr, more, l);
            } else {
                l++;
            }
        }
        swap(arr, more, r);
        return new int[]{less + 1, more};
    }

    // 根据异或运算的交换律和结合律实现交换
    // 其中x ^ x == 0
    // x ^ 0 == x
    public void swap(int[] arr, int i, int j) {
        if (arr[i] == arr[j]) {
            return;
        }
        arr[i] = arr[i] ^ arr[j];
        arr[j] = arr[i] ^ arr[j];
        arr[i] = arr[i] ^ arr[j];
    }
```

**时间复杂度：** `O(n)`

**空间复杂度：** `O(1)`

## `BFPRT`算法

思路：`BFPRT`算法是基于快速选择算法的改进，可以做到时间复杂度从期望`O(n)`到稳定的`o(n)`， **`BFPRT`算法的主体过程和快速选择算法一致，只是在`partition`过程中，`pivot`的选择有变化** ；快速选择算法每次`partition`都是在待排序部分数组中随机选择一个数作为轴数`(pivot)`，而`BFPRT`算法每次`partition`都是在待排序部分数组中选择中位数的中位数作为轴数`(pivot)`。 **所谓中位数的中位数就是在待排序数组中，每`5`个数选为一组，最后不足的`5`个数也当作一组，选出每组的中位数组成一个新的数组，然后递归调用`BFPRT`算法，求出这个新数组的中位数，并将这个中位数当作`partition`的轴数`(pivot)`** 。

代码：

```java
    public int findKthLargest(int[] nums, int k) {
        int n = nums.length;
        return BFPRT(nums, 0, n - 1, n - k);
    }


    public int BFPRT(int[] nums, int left, int right, int k) {
        if (left == right) {
            return nums[left];
        }

        // 实现了一个递归调用，获取中位数（全局最好的pivot）
        int pivot = medianOfMedians(nums, left, right);

        // 用这个中位数实现快排
        int[] indexes = partition(nums, left, right, pivot);

        // 如果刚刚好查找的数就在中间位置，直接返回arr[k]
        if (k >= indexes[0] && k <= indexes[1]) {
            return nums[k];
        }

        // 如果k位置小于less，则向左进行递归调用
        if (k < indexes[0]) {
            return BFPRT(nums, left, indexes[0] - 1, k);
        }

        // 如果k位置大于more，则向右进行递归调用
        return BFPRT(nums, indexes[1] + 1, right, k);
    }

    // medianOfMedians 获取中位数的中位数
    public int medianOfMedians(int[] nums, int left, int right) {
        // 数组总长度
        int num = right - left + 1;
        // 每五个一组，查看是否有多余的数，有的话则单独成一位
        int offset = num % 5 == 0 ? 0 : 1;
        // 创建存储每五个数据排序后中位数的数组
        int[] midNums = new int[num / 5 + offset];
        // 遍历此数组
        for (int i = 0; i < midNums.length; i++) {
            // 当前midNums来源自原来数组中的起始位置
            int beginI = left + i * 5;
            // 当前midNums来源自原来数组中的终止位置
            int endI = beginI + 4;
            // 计算出当前k位置5个数排序后的中位数
            midNums[i] = getMedian(nums, beginI, Math.min(right, endI));
        }

        // 在这些中位数的点中，挑选出排好序之后的中位数返回
        return BFPRT(midNums, 0, midNums.length - 1, midNums.length / 2);
    }

    // 快速排序过程中的num一般使用数组中的最后一个值
    // 所以不用指定num的值
    // 在使用荷兰国旗问题切割数组的时候，数组的最后一个值是等于num的值
    // 遍历的时候从num的下一个值作为大于区域的边界开始遍历
    // num不作遍历,待数组划分完成后,需要将num放到正确的位置上
    // 此时将大于区域的第一个值与num交换,同时大于区域返回大于区域的第一个值的下标
    public int[] partition(int[] arr, int l, int r, int pivot) {
        int less = l - 1;
        int more = r + 1;
        while (l < more) {
            if (arr[l] < pivot) {
                less = less + 1;
                swap(arr, less, l);
                l = l + 1;
            } else if (arr[l] > pivot) {
                more = more - 1;
                swap(arr, more, l);
            } else {
                l++;
            }
        }
        return new int[]{less + 1, more - 1};
    }

    // 获取中位数
    public int getMedian(int[] arr, int left, int right) {
        insertionSort(arr, left, right);
        return arr[left + (right - left + 1) / 2];
    }

    // 简单插入排序
    public void insertionSort(int[] arr, int left, int right) {
        for (int i = left + 1; i <= right; i++) {
            // 将 arr[i] 插入到正确的位置
            inserToRightPosition(arr, i);
        }
    }

    // 将 arr[i] 插入到正确的位置
    private void inserToRightPosition(int[] arr, int i) {
        // 备份待插元素
        int inserted = arr[i];
        int j = i - 1;
        for (; j >= 0 && arr[j] > inserted; ) {
            arr[j + 1] = arr[j]; // 将比待插元素大的元素后移
            j--;
        }
        // 将待插元素插入正确的位置
        arr[j + 1] = inserted;
    }

    // 根据异或运算的交换律和结合律实现交换
    // 其中x ^ x == 0
    // x ^ 0 == x
    public void swap(int[] arr, int i, int j) {
        if (arr[i] == arr[j]) {
            return;
        }
        arr[i] = arr[i] ^ arr[j];
        arr[j] = arr[i] ^ arr[j];
        arr[i] = arr[i] ^ arr[j];
    }
```

**时间复杂度：** `O(n)`

**空间复杂度：** `O(n)`
