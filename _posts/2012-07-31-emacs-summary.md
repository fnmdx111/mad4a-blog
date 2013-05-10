---
layout: post
title: "折腾了一天的emacs，现在来写点总结"
description: ""
category: emacs
tags: [emacs, summary, configure]
---

今天一起床，突然心血来潮，想配个emacs来玩玩。一来增加点见识，一个*编辑器*到底能做到什么水平；二来，如果真配好了，以后用起来也应该会很方便；再来，我本来就对lisp类的语言很感兴趣（其实只要不是命令式的都感兴趣，嘛，满大街都是imperative的，这不科学），而且最开始是想作为clojure的ide来弄的，配配emacs也算是增进对lisp的了解吧。

### 准备工作 ###

+ 过一遍emacs自带的tutorial，了解一下基本操作，后面的配置也就可以作为实际的练习了。另：有中文的，所以应该不是什么大问题，无奈的是emacs在windows下默认的字体渲染得很丑（ps: 这是可以解决的，详见后文）。
+ 了解lisp的基本知识，比如这种_奇怪_的语法（[S-expression](http://en.wikipedia.org/wiki/S-expression)）是怎么回事，最开始可能不习惯，但是习惯之后，你就会明白这种语法的表达力有多强大（通过宏来体现出数据即代码，代码即数据）。

接下来，开始*一块一块*地来看`.emacs`（即vim里的`.vimrc`）。

### 哦，对了，首先要说的是.emacs放哪。 ###

*nix就不说了，大家都知道。但是windows的情况就要复杂点了。
我先是稍微在网上搜了一下，说在`C:/Users/xxx/AppData/Roaming/.emacs.d`里建一个`init.el`。我试了，不行。（怎么试？就加一句`(tool-bar-mode -1)`，然后重启emacs看看有变化没。）百撕不得骑姐（大误）之后，还是打算换个关键字，用英语搜吧。果然搜到了一个关于windows的[faq](http://www.gnu.org/software/emacs/windows/Installing-Emacs.html#index-HOME-directory-49)，里面的3.5节对确定主文件夹的机制讲得很清楚：
> 1. 如果设置了`HOME`环境变量，那么就用`HOME`指代的文件夹。
> 2. 如果注册表有`HKCU\SOFTWARE\GNU\Emacs\HOME`这一项，那么就用它指代的文件夹。
> 3. 如果注册表有`HKLM\SOFTWARE\GNU\Emacs\HOME`这一项，那么就用它指代的文件夹。不推荐，因为它会让多个用户共享同一个主文件夹。
> 4. 如果存在`C:\.emacs`，那么就用`C:/`。这么做是为了向前兼容，因为如果没有设置`HOME`，以前的版本会默认将其设置为`C:/`。
> 5. 使用当前用户的`AppData`文件夹，通常是在当前用户的profile文件夹里一个叫做`Application Data`的文件夹，其路径根据Windows版本和计算机是否是域上的一部分而不同。

后面还有一句
> 在Emacs中，一个文件名开头处的<~>会被展开为你的主文件夹，所以你总是可以用`C-x C-f ~/.emacs`找到你的`.emacs`文件。

我是直接用的第一个方法弄的，果然好使（还是官方文档靠谱啊）。

### 外观部分 ###

首先得设置好语言环境（应该就是总编码的意思），
用以下代码设置
{% highlight cl linenos %}
(set-language-environment 'utf-8)
{% endhighlight %}
其中`'utf-8`表示的是一个引用（quote），表示一个唯一确定的标识，跟java里的枚举类型有点类似。

然后设置汉字的渲染，
我在google上搜过，得到的结论是强制设定一个字体应该能解决问题，在[这篇文章](http://emacser.com/torture-emacs.htm)里copy了一段代码
{% highlight cl linenos %}
(dolist (charset '(kana han symbol cjk-misc bopomofo))
  (set-fontset-font (frame-parameter nil 'font)
					charset
					(font-spec :family "微软雅黑" :size 12)))
{% endhighlight %}
eval之后，渲染果然好多了，但是保存`.emacs`之后，新开一个emacs，又变回以前那种渲染了，经过又一次的百思不得其解之后，还是去翻文档，试着把`set-fontset-font`的第一个参数，即`(frame-parameter nil 'font)`，改成`"fontset-default"`，保存，重启，ok了。
然后设置英文字体，把其中的`Bitstream Vera Sans Mono`换成你想要的字体名就行了，比如`Consolas`
{% highlight cl linenos %}
(set-face-attribute 'default nil :font "Bitstream Vera Sans Mono-10")
{% endhighlight %}
ps: 在这里强烈推荐一下[Bitstream Vera Sans Mono](http://ftp.gnome.org/pub/GNOME/sources/ttf-bitstream-vera/1.10/)，非常耐看的字体，再配上mactype的渲染简直完美（*nix个发行版的桌面一般自带比windows好看的多的渲染，mac就更不用说了）;)。

接下来把那个烦人的工具栏去掉
{% highlight cl linenos %}
(if (fboundp 'tool-bar-mode)
  (tool-bar-mode -1))
{% endhighlight %}
其中在设置之前检测一下应该是为了兼容`nw`模式（因为既然在控制台下，工具栏什么的肯定是没有的吧）。如果你也不喜欢菜单栏，可以照葫芦画瓢，设置`menu-bar-mode`为`-1`。

然后把总是在响的bell给关掉
{% highlight cl linenos %}
(setq visible-bell t)
{% endhighlight %}
值得一提的是`setq`（set quoted）与`set`的区别，基本可以理解为以下两个表达式等价
{% highlight cl linenos %}
(setq some-variable t)
(set 'some-variable t)
{% endhighlight %}

然后设置主题，
我试过用`M-x package-install`装color-theme，也试过直接从color-theme的官网上下zip，在emacs24下都有问题：`Symbol's function definition is void: plist-to-alist`，去源码里一看，调用`plist-to-alist`的那句后面写着`XEmacs only`-_-|，试过把这句注释，或者加个`plist-to-alist`的假实现，都不行。最后看了一个stackoverflow的回答说emacs24自带了主题管理（好像以前的版本也有？），先在buffer里用`M-x customize-themes`看所有的主题，选一个，然后在`.emacs`里加入
{% highlight cl linenos %}
(load-theme 'wheatgrass t)
{% endhighlight %}

外观这部分最后要说的是两个插件：tabbar和lineno
但是在说tabbar的配置之前，要说一下emacs的package管理器的配置
{% highlight cl linenos %}
(require 'package)
(add-to-list 'package-archives
	         '("marmalade" . "http://marmalade-repo.org/packages/"))
(package-initialize)
{% endhighlight %}
具体来说就是将"marmalade"和这个repo的url作为一个cons存进`package-archives`里。
以后要安装什么插件，一般可以直接用命令`M-x package-install xxx`（以下简称pac-ins）安装。

首先用pac-ins安装lineno，然后在`(package-initialize)`后面加入
{% highlight cl linenos %}
(linum-mode t)
{% endhighlight %}
注意，所有跟用pac-ins安装的插件有关的代码都只能写在`(package-initialize)`后面，否则会提示找不到变量之类的错误。

然后安装tabbar，并加入以下代码
{% highlight cl linenos %}
(require 'tabbar)
(tabbar-mode t)
{% endhighlight %}
重启之后就可以看到buffer上面都多了一行tab。

为了更加方便地使用tabbar，可以绑定两个快捷键到tabbar-xward上，比如
{% highlight cl linenos %}
(global-set-key (kbd "M-j") 'tabbar-backward)
(global-set-key (kbd "M-k") 'tabbar-forward)
{% endhighlight %}

另外，如果你觉得默认的样式很丑，可以用下面的代码来自定义，修改自[这篇文章](http://blog.csdn.net/CherylNatsu/article/details/6204737)。
{% highlight cl linenos %}
(set-face-attribute 'tabbar-default nil
		    :background "gray80"
		    :family "Bitstream Vera Sans Mono"
		    :foreground "gray30"
		    :height 0.75)
(set-face-attribute 'tabbar-unselected nil
		    :inherit 'tabbar-default
		    :background "gray85"
		    :foreground "gray30"
		    :box nil)
(set-face-attribute 'tabbar-selected nil
		    :inherit 'tabbar-default
		    :background "#f2f2f6"
		    :foreground "black"
		    :box nil)
(set-face-attribute 'tabbar-button nil
		    :inherit 'tabbar-default
		    :box '(:line-width 1
			   :color "gray72"
			   :style released-button))
(set-face-attribute 'tabbar-separator nil
		    :height 0.7)
{% endhighlight %}
在那篇文章里，所有的`set-face-attribute`的第一个参数都以`-face`结尾，但是到我这来就没有了，所以直接copy过来是不能跑的。看了tabbar.el，那些face都是没有`-face`的，只好跟着把`-face`去掉了，重启一下，可以发现样式改过来了。

附上emacs截图一张
![截图](/assets/images/emacs-summary/emacs-screenshot.png)


未完待续...

