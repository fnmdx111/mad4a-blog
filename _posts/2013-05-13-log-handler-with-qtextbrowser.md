---
layout: post
title: "在PyQt中实现一个可以变色的log窗口"
description: ""
category: gui
tags: [pyqt, logger, handler, qtextbrowser, formatter]
---

前述
---

[QTextBrowser]: http://qt-project.org/doc/qt-4.8/qtextedit.html

在[之前的一篇文章](../../12/pyqt-model-view-framework/ )里说过，log这种流动的文字信息可以用[QTextBrowser][]来展示。这篇文章会演示如何实现一个log窗口，而且还能根据特定log等级变化颜色。

最终效果
![overview.png](/assets/images/log-handler-with-qtextbrowser/overview.png)

实现可以分成3步

[logging.Logger]: http://docs.python.org/2/library/logging.html#logging.Logger

* 在Qt中实现带颜色的文字显示
* 在python中实现log颜色的格式化
* 连接python中的[logging.Logger][]和Qt中的[QTextBrowser][]

在Qt中实现带颜色的文字显示
---

[QTextBrowser.append]: http://qt-project.org/doc/qt-4.8/qtextedit.html#append

很简单，有了[QTextBrowser][]之后，使用[`append()`][QTextBrowser.append]槽就可以往里面添加了。而且QTextBrowser还支持html，也就是你可以在程序里写（至少是简单的）html代码，Qt可以正确的渲染出来。
比如
{% highlight python linenos %}
app = QApplication(sys.argv)
text_browser = QTextBrowser()

text_browser.append('<b>this</b> is <font color=blue><i>append</i></font>ed'
                  ' into <code>text_browser</code>')

text_browser.show()
app.exec_()
{% endhighlight %}
如图 ![render-html.png](/assets/images/log-handler-with-qtextbrowser/render-html.png)

在python中实现log颜色的格式化
---

[Formatter]: http://docs.python.org/2/library/logging.html#logging.Formatter
[`Formatter.format()`]: http://docs.python.org/2/library/logging.html#logging.Formatter.format

为了能在logger的工作流程里插一手，我们只有实现自己的[Formatter][]这一条路走。

我们的主要思路就是，在[`Formatter.format()`][]中，把给传入的参数的每个需要格式化的值外面套上`<font color=%1>`和`</font>`，所以我们需要一个表，来确定什么参数要用什么颜色，像这样
{% highlight python linenos %}
colors = {
    'asctime': 'blue',
    'message': 'green'
}
{% endhighlight %}
但是这样不够灵活，如果这样写，我们怎么来按照log等级来选择不停的颜色呢，所以可以这样
{% highlight python linenos %}
colors = {
    'asctime': lambda _: 'blue',
    'levelname': lambda record: {'DEBUG': 'gray',
                                 'INFO' : 'green',
                                 'WARNING': 'orange'}[record.levelname]
}
{% endhighlight %}
也就是颜色表的值是一个函数，按照输入来确定颜色，如果这么写，理论上（实际上也是可以实现的）我们甚至可以按照时间的不同来显示不同的颜色
{% highlight python linenos %}
colors = {
    'asctime': lambda t: 'blue' if int(t) % 2 else 'red'
}
{% endhighlight %}
效果如图 ![asctime-change-color.png](/assets/images/log-handler-with-qtextbrowser/asctime-change-color.png)

接下来我们来着手重载[`Formatter.format()`][]

[LogRecord]: http://docs.python.org/2/library/logging.html#logging.LogRecord

[`Formatter.format()`][]带了一个参数`record`，保证了是[LogRecord][]类的实例，我们要格式化的内容就在这个里面。但是我们只是一个formatter，不应该修改这个record，所以我们应该做一个这个record的拷贝，在这个拷贝的基础上，我们再来格式化log信息。
{% highlight python linenos %}
def format(self, record):
    _r = makeLogRecord(record.__dict__)
{% endhighlight %}
其中`makeLogRecord`函数是我在logging库的源码里找到的，manual里好像没记录这个东西。

[`Formatter.formatTime()`]: http://docs.python.org/2/library/logging.html#logging.Formatter.formatTime

接下来根据`colors`表来格式化各个项目，需要注意的是，我们要对`asctime`这个项目做特殊处理，因为
* 首先，[LogRecord][]对象里面没有`asctime`这个属性，但是为了跟格式化字符串`fmt`保持一致的关键字，我还是决定继续用`asctime`
* 其次，超类里的`format`方法会自己调用[formatTime()][`Formatter.formatTime()`]，然后我们对`asctime`做的颜色格式化就被覆盖了

所以基本上来说，因为`asctime`的原因，我们不能简单地按项目格式化他们的颜色之后简单的调用`super(ColoredFormatter, self).format(_r)`了。代码如下
{% highlight python linenos %}
    for item in self.colors:
        if item == 'asctime':
            info = self.formatTime(_r, self.datefmt)
        else:
            info = _r.__getattribute__(item)
        _r.__setattr__(item,
                       '<font color=%s>%s</font>' % (
                           self.colors[item](_r),
                           info
                       ))
    _r.message = _r.getMessage()

    if self.usesTime() and not 'asctime' in self.colors:
        _r.asctime = self.formatTime(record, self.datefmt)

    return self._fmt % _r.__dict__
{% endhighlight %}

`for`后面那一段基本上按照[`Formatter.format()`][]的源码写的，但是为了简单没有照抄后面关于异常的格式化。

连接python中的[logging.Logger][]和Qt中的[QTextBrowser][]
---

上面介绍了在log信息格式化中插一手的方法，现在介绍在log信息传播中插一手的方法。

[logging.Handler]: http://docs.python.org/2/library/logging.html#handler-objects
[`Handler.emit()`]: http://docs.python.org/2/library/logging.html#logging.Handler.emit

使用[logging.Handler][]来实现log信息转播到Qt中的控件中，具体方法是实现[Handler][logging.Handler]的子类。
实现这个子类很简单，只需要实现一个方法[`Handler.emit()`][]，在这个方法中写操作[`QTextBrowser`]的相关代码。为了实现线程安全，我们需要利用Qt的信号/槽机制（这个机制天生就是线程安全的），但是[`QTextBrowser`]并没有提供添加信息的信号供我们发射，只提供了一个槽。所以我们得自己做一个信号
{% highlight python linenos %}
def append_to_widget(widget, s):
    widget.append(s)
{% endhighlight %}

然后Handler的子类代码如下
{% highlight python linenos %}
class LoggerHandler(Handler):
    def __init__(self, logger_widget):
        self.logger_widget = logger_widget
        super(LoggerHandler, self).__init__()


    def emit(self, record):
        self.logger_widget.emit(SIGNAL('new_log(QString)'),
                                QString(self.format(record).decode('utf-8')))
{% endhighlight %}

然后配置代码如下
{% highlight python linenos %}
logger = Logger(__name__)

handler = LoggerHandler(text_browser)
handler.setFormatter(ColoredFormatter(
    fmt='%(asctime)s %(levelname)s %(message)s',
    datefmt='%m/%dT%H:%M:%S',
    colors={'asctime': lambda _: 'blue',
            'levelname': lambda record:
                ColoredFormatter.gen_colorscheme()[record.levelname]}
))

logger.addHandler(handler)

text_browser.connect(text_browser,
                     SIGNAL('new_log(QString)'),
                     lambda log: append_to_widget(text_browser, log))
{% endhighlight %}

其中`ColoredFormatter.gen_colorscheme()`是我另外写的一个convenience函数，就是返回了一个默认的字典罢了，不多说。

测试代码
{% highlight python linenos %}
logger.debug('debug')
logger.info('info')
logger.warning('warning')
logger.error('error')
logger.critical('critical')
{% endhighlight %}

最终效果如图 ![final.png](/assets/images/log-handler-with-qtextbrowser/final.png)

扩展阅读
---

* [基础的logging教程](http://docs.python.org/2/howto/logging.html#logging-basic-tutorial )
* [Python内置的handler，壮哉我大Python Stdlib](http://docs.python.org/2/library/logging.handlers.html#module-logging.handlers )
* [Logging Cookbook](http://docs.python.org/2/howto/logging-cookbook.html#logging-cookbook )

