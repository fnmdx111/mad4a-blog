---
layout: post
title: "Emacs总结（续）之YASnippet"
description: ""
category: emacs
tags: [emacs, summary, configure, yasnippet]
---

这里我不建议用pac-ins装它，因为无论怎么按照网上给出的方法配置，重启之后都没有YASnippet这个菜单出现。我推荐的安装方法是去[YASnippet的主页](https://github.com/capitaomorte/yasnippet)，按照README里的第一种方法安装，重启后成功出现了YASnippet菜单。

YASnippet的配置是非常简单的，只需要在`.emacs`中加入

{% highlight cl linenos %}
(add-to-list 'load-path
             "your path to yasnippet")
(require 'yasnippet)
(yas/global-mode 1)
{% endhighlight %}

要说的一点是展开模板的快捷键Tab的设置，在主模式markdown-mode下，Tab被绑定到markdown-cycle，而辅模式yas-minor-mode下，Tab是yas/expand，被markdown-cycle覆盖了。这样非常不方便。解决的办法有两种：

* 取消markdown-mode对tab的占用，代码出处： [这篇博客](http://calas.github.com/2009/11/20/using-yasnippets-in-markdown-mode.html )
{% highlight cl linenos %}
(defun markdown-unset-tab ()
  (define-key markdown-mode-map (kbd "<tab>") nil))
(add-hook 'markdown-mode-hook 'markdown-unset-tab)
{% endhighlight %}
* 将yas/expand绑定到其他快捷键上
{% highlight cl linenos %}
(global-set-key (kbd "C-;") 'yas/expand)
{% endhighlight %}
考虑到markdown里用tab的次数还是挺多的，我采用的是第二种方法。

再说下YASnippet的自定义模板吧，这么方便的工具不会自定义真是太浪费了。
我们从实例来说明。

### 第一个例子：post的meta信息模板 ###

大家知道，jekyll的post是由markdown编译而来的，而这些markdown文件（即post源文件）必须有一些可以为jekyll所用的meta信息（比如title，category之类的）才能被识别为一篇博客。本着[DRY原则](http://en.wikipedia.org/wiki/Don't_repeat_yourself)（是的，代码里的原则不光码代码的时候很受用，从字面上看，干别的事也是），现将这些meta信息做成一个snippet。


使用命令`M-x yas/new-snippet`来进入新建snippet的buffer，可以看到以下的内容

	# -*- mode: snippet -*-
	# name:
	# key: 
	# binding: direct-keybinding
	# expand-env: ((some-var some-value))
	# type: command
	# --

其中

+ `name`是在YASnippet中显示的名字
+ `key`是触发这个snippet所用的关键字
+ `binding`和`expand-env`是两个高级特性，这里不做说明

接下来，将上面的信息改为（不需要的行可以删掉）

	# name: post-meta
	# key: pm

值得注意的是，这个new snippet的buffer的初始内容就是YASnippet的一个snippet，按tab可以自动跳到下一个要填内容的地方。

接着在`# --`后面一行按照要求的格式写下我们需要的meta信息

{% raw %}
	---
	layout: post
	title: "${1:Title}"
	description: ""
	category: $2
	tags:[$3]
	---
	{% include JB/setup %}
	$0
{% endraw %}

这其中形如${N:Some Text}的内容被称为字段，N是tab stop序号（顺序是从$1到$N的），冒号后面的文字（如Title）则是其中的默认值。最后$0被称为YASnippet的退出点，即一个key被展开为snippet，并按顺序走完所有tab stop之后光标停留的点。


现在这个snippet就写好了。别忘了_保存_！如果你是按照github上的安装方法安装的，可以用`C-x C-s ~/.emacs.d/plugins/yasnippet/snippets/markdown/post-meta`把这个snippet保存在YASnippet的markdown分类下。

重启之后，新建一个md文件，emacs会自动进入markdown-mode和yas-minor-mode以及其他的一些minor-mode，这时你可以在空白处输入`pm`，然后用命令`M-x yas/expand`或者用它的快捷键（我的是`C-;`），就可以看到pm被扩展成了上面那几句，如图

![post-meta-screenshot.png](/assets/images/emacs-summary-cont/post-meta-screenshot.png)

如果不能展开，那么就要注意一下展开时你的光标的位置：光标不能处于key上，只能在你正常打完key的时候光标的那个位置（即key的最后一个字母之后）。同时key也有要求，除了空白符（空格，tab等）周围不能有其他字符。


然后就可以按tab，依次输入信息了。

### 第二个例子：高亮代码tag模板 ###

用jekyll写博客时，插入代码片段要用到liquid的tag（准确地说是jekyll给liquid写的扩展tag）如下

{% raw %}
	{% highlight lang linenos %}
	{% endhighlight %}
{% endraw %}

这里的`lang`是一个语言的缩写形式，比如Common Lisp是`cl`，Python是`python`（其他语言的名字可以查 [Pygments的Lexer页面](http://pygments.org/docs/lexers) ）。本着DRY原则，应该将这些重复性的操作给抽取出来。

跟上一个例子的操作一样，进入new snippet的buffer，其中

+ `name`设为`highlight`
+ `key`设为`hl`

其他的meta可以删掉，snippet正文如下

{% raw %}
	{% highlight ${1:cl} linenos %}
	$0
	{% endhighlight %}
{% endraw %}

保存并重启之后，在markdown-mode下就可以把`hl`展开为上面那一段了，基本消灭了重复操作。

### 最后一个例子，也是最复杂的一个，但是也是最好玩的一个 ###

markdown中的img标签语法为

	![ALT TEXT](URL)

很明显这个语法可以做成如下的snippet

	![${1:ALT TEXT}](${2:URL }) $0

但是这还不够。还可以更简单。

在开始之前，我想说一下这个博客的文件布局（同时也是jekyll blog的默认布局）

	root
	  | --- _posts
	  |       | --- 2012-07-31-hello-world-again.md
	  | 	  | --- 2012-08-01-emacs-summary.md
	  | 	  | --- 2012-08-02-emacs-summary-cont.md
	  |
	  | --- assets
	  |       | --- images
	  |       |       | --- emacs-summary
	  |       |       |       | --- emacs-screenshot.png
	  |       |       |
	  |       |       | --- emacs-summary-cont
	  |       |       |       | --- post-meta-screenshot.png

可以看到，图片可以用`/assets/images/post-name/xxx.extension`来访问（`post-name`是文章的名字，比如这篇博客的是`emacs-summary-cont`）。

观察了一下路径，发现`/assets/images/`是确定的，而实际上`post-name/`也是确定的，因为它实际上是文章源代码的路径去掉多余的修饰值（日期，扩展名）后的值，也就是这个post的实际名称，而且在emacs里编辑的时候，就已经知道路径了。然后`xxx.extension`原本是要手填的，但是可以用YASnippet的`yas/choose-value`特性把`/assets/images/post-name/`里是图片的文件名列出来，由我们来选择一个填入（为什么这样是可行的，因为我的习惯是先放图进去再接着写）。还剩一个要填的Alt Text，就把图片文件名填到Alt Text里去好了。这么一看，我们的录入量从**整个的路径**减少到了**只用上下键选择**的程度。__这正是emacs的魅力所在__。

为什么上面的设想是可行的？因为YASnippet支持在snippet中*嵌入elisp*代码！

整理一下已知量：

+ post的绝对路径，通过 [GNU Emacs Lisp Reference Manual](http://www.gnu.org/software/emacs/manual/elisp.html ) 的相关章节可以知道函数`buffer-file-name`返回形如`d:/workspace/2012-08-02-emacs-summary-cont.md`的绝对路径
+ url的前缀，即`/assets/images/post-name/`
+ Alt Text，即图片url里的文件名（这里只是知道了Alt Text与文件名相同，实际上在这个时候文件名是不知道的）

整理一下要求的量：

+ post的实际名称，如这篇文章的实际名称为`emacs-summary-cont`
+ `/assets/images/post-name/`里的图片文件的列表


接下来求解第一个问题，求一个post的实际名称。

首先把路径去掉，扩展名去掉，通过manual可以查得有两个函数可以用，于是代码如下
{% highlight cl linenos %}
(defun mfa/extract-file-name (file-name)
  (file-name-nondirectory (file-name-sans-extension file-name)))
{% endhighlight %}

然后可以发现实际名称是把上一步得到的值，用`-`打散之后，去掉前3个，再用`-`合起来，手册可以查到有`concat`、`split-string`和`cdddr`（`cdr`的变形），但是没有查到类似python里的`join`的函数，只能自己写了
{% highlight cl linenos %}
(defun mfa/join (l separator)
  (apply 'concat
         (car l)
         (mapcar #'(lambda (str) (concat separator str))
                 (cdr l))))

(defun mfa/remove-date (file-name)
  (mfa/join (cdddr (split-string file-name "-"))
            "-"))

(defun mfa/get-directory-from-bufname (file-name)
  (mfa/remove-date (mfa/extract-file-name file-name)))
{% endhighlight %}

稍微解释一下`mfa/join`（如果你懂一些lisp，以下内容可以跳过）：

- 首先把参数之一的列表l分成两份，l1表示`(car l)`，即l的第一个元素，lr（l-rest）表示`(cdr l)`，即去掉了l的头元素的剩下的列表。
- 然后对lr做运算：每个元素的前面都加一个separator，例如若lr是`'("a" "b" "c")`，经过运算之后就是`'("-a" "-b" "-c")`了。这个运算用`mapcar`函数来实现，`mapcar`接受两个参数：一个函数，一个列表；`mapcar`把这个函数按顺序应用到这个列表的每一个元素上，并且把每一个函数应用的返回值按顺序收集起来，做成一个新列表，`mapcar`的运算结果就是这个新列表。
- 把l1和lr拼起来。
- 如果还是有问题可以用`M-x ielm`命令打开elisp的repl，自己去试验一下。

（事后突然发现其实没必要那么麻烦。因为日期是固定长度的`xxxx-xx-xx`，可以直接去掉`file-name`的前11个字符（比日期多加了一个杠，所以是11个））


接下来求图像文件列表

要求一个文件列表，首先得知道文件的目录在哪，如果用绝对路径，这个目录是很好知道的，但是如果要保证跨平台性，只能使用相对路径，手册里查到一个函数`expand-file-name`可以完成相对路径展开到绝对路径的工作，
然后可以发现从我当前的编辑目录`./_posts`到`./assets`需要向上走一级目录，所求的目录用elisp表达出来即

{% highlight cl linenos %}
(defun mfa/get-images-directory (file-name)
  (concat (file-name-as-directory (expand-file-name "" "../assets/images/"))
          (mfa/get-directory-from-bufname file-name)))
{% endhighlight %}

如果调用`(mfa/get-images-directory (buffer-file-name))`在我的电脑上可得返回值为`d:/workspace/blog-content/assets/images/emacs-summary-cont`

接下来就可以用`directory-files`求得某个目录下的文件列表了，而且`directory-files`有个参数`:match-regexp`用来guard文件名。注意：这个函数返回的文件列表里的元素是绝对路径的，而我们只需要文件名，所以需要用`mapcar`处理一下，代码如下

{% highlight cl linenos %}
(defun mfa/list-image-files (directory)
  (mapcar 'file-name-nondirectory
          (directory-files directory
                           :match-regexp "\\.\\(png\\|jpg\\|jpeg\\|gif\\)")))
{% endhighlight %}

Emacs Lisp用的正则表达式的语法是posix风格的（与vim一样），熟悉perl风格的同学们可能会觉得很奇怪（比如括号要转义了才有分组的作用）。

最后一步，弄一个函数把上面的函数拼起来，首先在脑袋里想好输入输出：输入是一个带绝对路径的文件名，输出是这个文件名对应的图片文件夹下的图片文件名列表。

{% highlight cl linenos %}
(defun mfa/yield-choices (file-name)
  (mfa/list-image-files (mfa/get-images-directory file-name)))
{% endhighlight %}

这样一来，我们所有的elisp编码工作就完成了（可以看出来所有代码都是由函数拼起来的，这也是[函数式编程](http://en.wikipedia.org/wiki/Functional_programming)的主要编码方式），可以把以上代码存入一个elisp文件中（注意，最后一行要写`(provide 'your-file-name)`），并在`.emacs`里配置一下，把这个文件像插件一样加载进来。

接下来，我们开始snippet的编码，这部分就相对来说容易很多了

{% raw %}
	![${1:$$(yas/choose-value (mfa/yield-choices (buffer-file-name)))}](/assets/images/`(mfa/get-directory-from-bufname (buffer-file-name))`/$1)$0
{% endraw %}

_注意_：里面是一行，不能折行。

这里主要用到了三个特性：`yas/choose-value`，内嵌elisp和镜像。

- 在扩展形如`${N:$$(yas/choose-value your-list)}`的snippet的时候，可以显示一个下拉菜单来选择要填入的内容；
- 可以在snippet的任意地方嵌入用_反引号_括起来的elisp代码；
- 在前面定义的tab stop，如果在后面有对它的引用，则会直接copy到后面的引用处，在上面的snippet里，前面作为Alt Text的文件名被镜像到后面的路径里去了。

这样一来，我们所有的编码工作就完成了，将这个snippet保存至上面的markdown的snippet目录下，重启emacs之后就可以看效果了。

附效果截图一张：

![snippet-screenshot.png](/assets/images/emacs-summary-cont/snippet-screenshot.png)


这样就基本介绍了YASnippet的配置和自定义snippet（中间还穿插了一点elisp）。

### 后记 ###

要知道YASnippet这个插件自身就是elisp写的，emacs的超高可配置性可见一斑，无怪乎说 [**emacs就是一个操作系统**](http://c2.com/cgi/wiki?EmacsAsOperatingSystem)了。

就我个人来看，虽然vim的编辑效率可以爆emacs几条街（我之前可以算是个坚定的vim党，额，可能没那么坚定，我更喜欢在ide里用vim插件，而不是直接用gvim），但是如果emacs加上扩展再去和vim比（哪怕vim也加扩展），那真是不好说了。

我开始体会到emacs的强大，也是自己摸索出来上面那个图片文件列表snippet之后了，而elisp正是emacs强大的根源所在。elisp开发（或者说lisp类的语言的开发）的过程也是非常愉悦的过程，你在主buffer里写着代码，写了两个函数，想试一下效果，可以直接eval一下buffer，然后在旁边的repl里立即进行测试，基本上等于_所写即所得编程_（好像是废话，但是你懂我说的），我想目前还没有别的语言能这么做，对于我这个不会单元测试（也不喜欢，如果是好lisp代码的话，应该是不需要单元测试的，因为本身就完全是[声明式](http://en.wikipedia.org/wiki/Declarative_programming)的，要干什么一目了然）的人来说，真是救星一般的东西。另：elisp的文档也写得非常好，朴素且实用，就像emacs自己。

如果想进一步了解lisp这种**神奇**的东西，可以看看 [黑客与画家](http://book.douban.com/subject/6021440/ )。Paul Graham写的很精彩，但是我觉得略微有点太夸大lisp了（虽然lisp确实很强大） :)
