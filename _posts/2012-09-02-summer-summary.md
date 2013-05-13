---
layout: post
title: "2012年的暑假总结"
description: ""
category: summary
tags: [summer, summary]
---

将近2两个月的暑假过去了，写点总结性的东西，填充一下文章的数量。

首先
---

还没考完试就被一个密码学的老师邀请去做东西，这是_第二次_跟着这个老师了，第一次退出是因为，做出来第一个小东西之后，就给我了一个*在我看来*很专业的东西，被吓尿，然后就发了封邮件，说打算以后有基础了再弄。这次也是没搞几天就退了。哎，弄的东西实在是提不起兴趣，而且用的尽是我不喜欢的技术（[洗屁屁](http://www.cplusplus.com/ )和[假娃](http://www.java.com/ )什么的），跟我最开始想去实验室干活的目的不一样。不过这次我也学到了两件事：

> + 一是实验室永远用的都不会去用小众的东西，C就不说了，这货暂时还是不可替代的，cpp/java/c#可以说是大行其道，所以**永远不要**抱着**试试Scala，Clojure之类的东西在实战中是个什么样子**这种心态去找实验室，这是**不可能**的！想玩这些东西，呵呵，自己家里鼓捣鼓捣就算了吧。
> + 二是写任何东西，不可能做到**<font color="red">不去了解背景知识就能完成</font>**的。

然后
---

是跟另外一个同学一起做了一个比较坑的东西：python做一个特定领域搜索网站的爬虫。呵呵，坑人的地方就在于——**要爬<font color="red">所有</font>东西下来**！！而且，最开始还不知道这个需求，所以信誓旦旦地根据以前的经验说3天拿下，但是最后需求变得越来越，怎么说，烦人。最后是花了快20天，呵呵。收获就是，熟悉了一下python的线程（以前只有单线程抓东西，和actor模型的经验）和基础的pyqt。

再然后
---

想在github上搭一个博客，以前试过[Hyde](https://github.com/hyde/hyde )这个python写的静态网站生成器，但是文档太少，所以放弃了。于是这次试了Jekyll（准确的说是[Jekyll-Bootstrap](http://jekyllbootstrap.com)。配置也不是很难，以后记起来了就另开一篇说说。弄好了之后顺便去买了个域名，配置了一下CNAME什么的。然后配置了一下emacs，稍微学了学emacs lisp，也写了一个[小插件](https://github.com/mad4alcohol/mfa-elisp-lib )练练手。最开始是打算专门写博客用的，但是后来也还是配置了一下[clojure-mode](clojure-mode )，顺带着也弄了一下[Leiningen](https://github.com/technomancy/leiningen )（另，这货在arch下面还挺难装的，最后还是在emacs里不知不觉自己就弄好了）。配置emacs的东西都在前两篇文章里。

最后
---

是写了一个[工票录入系统](https://github.com/mad4alcohol/LaborHourInputter)，目的是加快工票的输入（原来是直接在写好的excel表格里输入工时之类的数据），所以根据用户需求，用才熟悉起来的pyqt弄了一个专门输入工票的界面。一直到现在都很简单，一天完事。这之后用户又有需求了：写出到excel之前，要用现在已有的数据算出工人的绩效，然后再跟工时废品之类的数据一起写到给定的excel的sheet里。这个工作，根据跨平台的原则，当然是首先考虑pypi里的可以跨平台的东西，所以看起来是可以用[pyExcelerator](http://sourceforge.net/projects/pyexcelerator/ )或者[xlutils](http://pypi.python.org/pypi/xlutils )这种东西来弄的，但是经过实践

> + 用pyExcelerator写入的话，所有格子的style消失，所有公式消失，基本可以说废掉了
> + 用xlutils的话，压根就写入不了（可能是操作有误吧）

最后只能去试试用[pywin32](http://sourceforge.net/projects/pywin32/ )的win32com模块了，随便去搜了搜，看起来好像很复杂，但是仔细看了一下某个邮件列表的某个邮件存档（链接已经忘了），发现用COM去操作excel还是挺简单的，直接定位之后给`Value`属性赋值就行了，然后设置style就是直接给`Style`属性赋值，比如`cell.Style = 'Percent'`（如果设置`xl_app.Visible = True`会有很有意思的事情发生）。摸清楚之后，剩下工作的工期缩短了500%（预期是十几天断断续续地弄）。收获也还是有的，熟悉了一下数据库之类的东西，但是因为用的是[SQLAlchemy](http://www.sqlalchemy.org/ )，所以很不熟悉底层的操作（比如sql语句什么的），这也导致数据库那块的效率略低，然后稍微用了一下 [xlrd](http://pypi.python.org/pypi/xlrd )去读存在表格里的工人信息，然后实践了一下抽象类之类的东西，目前感觉继承还是只是一种消除重复的机制，并没有那么神奇或者不可捉摸。反正目前我发现的办法就是，先写两个需要用的类出来（没有两个以及以上类似的类就暂时不需要抽象类对吧？），然后*并排打开*，从**字面上**提取出重复，放到一个抽象类里去，然后去掉这两个类的重复部分。

另外考虑到用户的*非*专业人员的属性，为每个项目入口点（比如输入界面和输出到表格）做了一个batch文件（给安装也做了一个脚本，静默安装python，安装distribute库，安装pip，安装xlrd和sqlalchemy，最后是安装pyqt和pywin32，基本上是全自动，除了最后两个需要手动点几下Next，因为实在是没找到可以用的静默参数是啥）。



