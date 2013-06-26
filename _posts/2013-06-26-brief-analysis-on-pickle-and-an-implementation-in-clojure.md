---
layout: post
title: "pickle模块简介与一个简单的clojure实现"
description: ""
categories: python
tags: [python, pickle, clojure, implementation]
---


有段时间突然对二进制的数据产生了强烈的兴趣（具体原因可能是因为解析坦克世界的`dossier.dat`可以获得平时看不到的数据），寒假在家也闲不住，就跑去研究了一下pickle这个模块（坦克世界的那些数据实际上也就是pickle之后的东西）。然后用clojure做了一个[简易的unpickle库](https://github.com/mad4alcohol/naive-unpickler-clj )，未来可能在有时间的时候会添加pickle的功能。

准备工作
---

如何去了解一个不了解的东西？Google。Google不到怎么破？源码。

翻了一下python的`Lib`文件夹，发现了两个有关的东西：`pickle.py`，`pickletools.py`。打开`pickletools.py`看一下，`"Executable documentation" for the pickle module`，看来是找对地方了。


pickle的简介
---

文档说的总会比我说的清楚，这里就摘抄几段文档了。

一个"pickle"是一个给pickle虚拟机（PM）使用的程序。它是一系列的操作码（opcode），被PM解释后，用来创建任意复杂的Python对象。总体来说PM非常简单：操作码每个被执行一次，从第一个到最后一个，直到碰到了`STOP`操作码。

PM有两个数据域：栈（stack）和备忘（memo）。

许多操作码把Python对象压到栈里，比如`INT`把一个Python整数对象压到栈里，这个整数对象的值从一个在pickle字节流中紧跟在`INT`操作码后面的十进制字符串字面量中取得。另外有一些操作码把Python对象弹出栈中。unpickling的结果就是当执行到`STOP`操作码时，留在栈顶的那个东西了。

备忘仅仅只是一个存放对象的数组，或者也能被实现成一个从小整数映射到对象的字典。备忘是PM的“长期记忆”，那些为备忘提供索引的小整数类似于变量名。有些操作码把对象从栈顶弹出后放入备忘的一个指定索引里，另外一些把给定索引处的备忘对象再压回栈里。

以上基本上就是pickle的工作原理了。

具体的pickle操作码的定义被称为pickle协议，由于历史原因pickle协议存在多个版本，但是令人感到安心的是，pickle操作码的意义永远不变，即高版本兼容低版本，令人感到不安的是，对于实现者工作量就会大些了。

最原始的pickle现在被称为“协议0”，并且在Python 2.3前被称为“文字模式（text mode）”。整个pickle字节流由可打印的7位ASCII字符加上换行符组成。这也是它被称为文字模式的原因。协议0小且优雅，但是有时极其低效。

第二个主要的协议版本现在被称为“协议1”，并且在Python 2.3前被称为“二进制模式（binary mode）”。增加了许多参数可以包含任意长度字节的操作码。通常二进制模式的pickle比文字模式的占用的空间要小，有时也会更快。协议1也添加了几个立即操作多个栈上元素的操作码（如`APPENDS`和`SETITEMS`）和“快捷”操作码（如`EMPTY_DICT`和`EMPTY_TUPLE`）。

第三个主要的协议版本在Python 2.3中被引入，被称作“协议2”。具体内容这里就略去了。因为这篇文章只会用clojure实现协议1（当然也包括了协议0），协议2等我熟悉了clojure的面向对象编程再说吧。

在开始实现之前
---

先阅读一下`pickletools.py`的其他部分，翻了一下，在883行发现了一个叫`opcodes`的list，可以说是pickle协议的可执行版本，讲解了操作码的名称，码值，参数，执行前后栈的变化情况，提供该操作码的协议版本和该操作码的文档。

比如
{% highlight python linenos %}
I(name='LONG',
  code='L',
  arg=decimalnl_long,
  stack_before=[],
  stack_after=[pylong],
  proto=0,
  doc="""...""")
{% endhighlight %}
告诉我们`LONG`这个操作码，实际的码值（在字节流中的值）是'L'，即76，参数是`decimalnl_long`，在执行这个操作码后，栈上会多一个pylong对象，协议0提供这个操作码。

再看`decimalnl_long`是什么玩意，
{% highlight python linenos %}
decimalnl_long = ArgumentDescriptor(
                     name='decimalnl_long',
                     n=UP_TO_NEWLINE,
                     reader=read_decimalnl_long,
                     doc="""A newline-terminated decimal integer literal.
                            ...""")
{% endhighlight %}
看doc说，`decimalnl_long`是一个以换行符结尾的十进制整数字面量。而且看它的`reader`项目可以看到这个参数的读取的具体实现，也就是`read_decimalnl_long`，如下
{% highlight python linenos %}
def read_decimalnl_long(f):
    s = read_stringnl(f, decode=False, stripquotes=False)
    if not s.endswith("L"):
        raise ValueError("trailing 'L' required in %r" % s)
    return long(s)
{% endhighlight %}
这个函数实际上是很简单的，用`read_stringnl`读取一个以换行结尾的字符串，并且判断它尾巴上有没有一个`L`，如果有`L`就用built-in函数`long`把这个字符串转换成一个`long`对象。

如果总结一下，对字节流的操作可以综合成以下几个操作：

* 读下一个字节
* 读下一行
* 读下四个字节
* 读下n个字节

这也是会在clojure里实现的几个基本操作。

开始实现
---

如果仿照`pickletools.py`里的写法，在clojure里我们可以自己定义一个`defxxx`，比如`defopcode`，当然这个`defopcode`得用宏来实现。

`defopcode`的基本操作就是修改维护的一个`map`，码值做键，具体的操作函数做值，这个操作函数接受三个参数，即字节流对象、栈对象和备忘对象，其中栈对象用`vector`实现，备忘对象用`map`实现，在函数内部对按照协议操作后，返回新的栈和备忘，作为下次执行所使用的栈和备忘。

在unpickle的时候，每次读入一个字节，然后通过这个`map`获得对应的操作函数，把需要的参数传递进去，并且接收好返回值，在loop的时候注意`STOP`操作码的判断，如果操作码是`STOP`，则立即停止recur，并返回栈顶元素。

在这个实现中有一个遗憾就是不能很好的实现`defopcode`这个宏，以至于每个操作码的定义后面都需要显式地写出返回值（即stack和memo）。

这里举一个例子
{% highlight clojure linenos %}
(defopcode BINUNICODE \X
  (let [len (from-byte-vector-lendian (next-4-byte))
        data (next-n-byte len)]
    [(conj stack
           (String. (to-java-byte-array data)
                    "utf-8"))
     memo]))
{% endhighlight %}
首先将字节流当前位置的后面4个字节读出来并且按小端（little endian）转换成一个`int`，使用的是自己写的函数`from-byte-vector-lendian`（python可以直接使用`struct.unpack`），绑定给`len`，随后又读取`len`个字节绑定给`data`，最后将`data`按`utf-8`解码为unicode的`String`后，压栈并返回。

这里不得不提的是java的`byte`类型很奇怪，竟然是带符号的，所以如果某个字节大于128（`0b10000000`）需要转换成`byte`，需要减掉256，把它变成负数，比如129（`0b10000001`）直接赋给`byte`是不行的，但是如果把它减掉256，变成-127，在补码下它的二进制表示仍然是`0b10000001`，这样就既没有破坏数据又可以被java接受了。

后记
---

感觉上用clojure实现协议1（包括部分协议2）的PM，要说的就是这么多（篇幅上来说比想象中的要短不少啊）。这回使用的编辑器依然是<font color=red>THE MIGHTY EMACS</font>，插件是很好用的nrepl，也算是体验了一下Lisp的开发方式，非常快捷方便，但是由于我个人的原因，开发起来还不是很熟练，最近买了O'reilly的《Clojure编程》打算系统地学习一下clojure。另外一个感觉是clojure的文档有些地方对于我来说不是很好用，比如clojure 1.4里面很多包名都从contrib里面移出去了，我找这方面的文档找了半天还是没找到（以前找到过一次貌似，但是寒假里没找到），还有就是clojure的错误信息有些时候很难读懂，这个可能跟经验有关，以后再慢慢积累吧。

