---
layout: post
title: "PyQt的Model/View框架的个人总结"
description: ""
category: gui
tags: [pyqt, python, summary]
---

[QTextBrowser]: http://qt-project.org/doc/qt-4.8/qtextedit.html
[model view framework]: http://qt-project.org/doc/qt-4.8/model-view-programming.html 

概述
---

ui设计中，经常会有展示一系列数据的情况，如果是log那种流动的文字信息，可以用[QTextBrowser][]来展示（[参见这篇文章](../../13/log-handler-with-qtextbrowser/ )）。如果是列表式的（树形，表形之类的），可以考虑用Qt的[Model/View Framework][model view framework]。这篇文章会介绍如何自定义model和如何使用model。一般来说，会这些就足够实现一些简单的功能了。Qt的delegate可能以后会添一篇文章，毕竟现在我也没怎么用过delegate。

这个框架利用了经典的MVC设计模式，model用来提供数据，view用来展示数据，control用来控制view对用户输入的反应。而在Qt里，view和controller被合并成了view，也就是说Qt里的view有了（初步的）反应用户输入的功能，而为了提供灵活的处理方式，Qt引入了delegate。delegate可以自定义数据显示（render）和修改的方式。

[QAbstractItemModel]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html
[QAbstractListModel]: http://qt-project.org/doc/qt-4.8/qabstractlistmodel.html
[QAbstractTableModel]: http://qt-project.org/doc/qt-4.8/qabstracttablemodel.html
[QStandardItemModel]: http://qt-project.org/doc/qt-4.8/qstandarditemmodel.html
[QSqlQueryModel]: http://qt-project.org/doc/qt-4.8/qsqlquerymodel.html
[batteries included]: http://docs.python.org/2/tutorial/stdlib.html#batteries-included

Qt提供了[QAbstractItemModel][]给我们作为实现自定义的model的基础，而对于列表和树形表型则分别提供了更具体的[QAbstractListModel][]，[QAbstractTableModel][]。然后Qt还提供了一些做好的model比如[QStandardItemModel][]，[QSqlQueryModel][]等等，可以算是[batteries included][]。

这里主要用例子来介绍[QAbstractTableModel][]，[QAbstractListModel][]的使用方法很类似。

[os-exp]: https://github.com/mad4alcohol/os-experiments

例子来自于（操蛋的）[操作系统实习][os-exp]，最终实现效果如图 ![overview.png](/assets/images/pyqt-model-view-framework/overview.png)

说下每个地方是干什么的。用户首先输入进程名和大小，点添加之后会在上面的列表控件里面添加一项，用来显示进程相关的信息。同时会为这个进程创造一个页表对象（见源码的PageTable类），由于一个进程对应一个页表，也就是说会有多个页表对象，那么在选中上面的列表中的项目的时候，下面的页表列表控件也要切换到相应的PageTable对象上去。用户可以选择任意的页面然后点击释放按钮来释放页面。对应地，内存空间在变化的时候，位示图（图中右边的那个Table控件）也要变化。

整理一下需求

* 程序需要至少3个model来为3个view提供数据
* 要能向进程列表添加表项
* 要能切换不同的页表对象（model）到页表列表上，实现同上
* 页表列表要能根据进程的分配和释放而变化
* 位示图控件要能根据空间的变化而变化

经过（很长时间的）文档翻阅，初步得出一些思路

[`beginInsertRows()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#beginInsertRows
[`endInsertRows()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#endInsertRows
[`selectedIndexes()`]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#selectedIndexes

* 列表控件的变化利用model的[`beginInsertRows()`][]，[`endInsertRows()`][]等来实现
* 数据的修改可以直接在自定义的model中内置的数据存储中修改

自定义一个Model
---

首先来实现存放进程列表用的model——ProcessModel，继承自[QAbstractTableModel][]，为了实现这个类，我们必须实现几个必要的方法

[`rowCount()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#rowCount
[`columnCount()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#columnCount
[`data()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#data

* `__init__`

    {% highlight python linenos %}
def __init__(self, parent):
    super(ProcessModel, self).__init__(parent)

    self._parent = parent
    self._proc_list = defaultdict(int)

    self.headers = [u'进程名', u'已分配 (kB)']
	{% endhighlight %}

* [`rowCount()`][]用来定义列表项的个数

    {% highlight python linenos %}
def rowCount(self, index=None, *args, **kwargs):
    return len(self._proc_list)
	{% endhighlight %}

* [`columnCount()`][]用来定义列数，这里我们只有两列，所以返回定值

	{% highlight python linenos %}
def columnCount(self, index=None, *args, **kwargs):
    return 2
	{% endhighlight %}

* [`data()`][]用来根据给定的index和role来返回数据

以下简要的来说一下role是个什么东西。

在model/view框架中，role就跟它自己的名字表示的意思一样，是用来控制data表示的是什么东西的，比如给定某index和`role=Qt.DisplayRole`来调用[`data`][]，那么返回的数据就是用来显示这个index表示的位置上的内容的。
如果给定某index和`role=Qt.TextAlignmentRole`来调用[`data`][]，那么返回的数据就是用来控制这个index表示的位置上的内容的文字对齐方向的。
用户也可以自己定义一些role，从Qt.UserRole开始，每次加1就表示一个新role，同时在delegate中也要控制对应的role。
像这样的role还有很多，具体可见 [文档](http://qt-project.org/doc/qt-4.8/qt.html#ItemDataRole-enum ) 。 

[QString]: http://qt-project.org/doc/qt-4.8/qstring.html
[QVariant]: http://qt-project.org/doc/qt-4.8/qvariant.html
[`toPyObject()`]: http://pyqt.sourceforge.net/Docs/PyQt4/pyqt_qvariant.html

这里不得不说一下pyqt的实现细节，由于重载的是Qt对象的方法，所以data的返回值最好是Qt内置的数据类型，比如[QString][]之类的，一般来说，属于python的数据类型在返回前是用[QVariant][]包起来的，在实际使用的时候解包也很简单，调用[`toPyObject()`][]即可。

所以[`data()`][]的主要代码就是
{% highlight python linenos %}
proc_name = sorted(self._proc_list.keys())[row]
size = self._proc_list[proc_name]
if role == Qt.TextAlignmentRole:
    if col == 0:
        return Qt.AlignLeft | Qt.AlignVCenter
    if col == 1:
        return Qt.AlignLeft | Qt.AlignVCenter
elif role == Qt.DisplayRole:
    if col == 0:
        return QString(proc_name)
    elif col == 1:
        return QVariant(size)
elif role == Qt.ForegroundRole:
    if proc_name == self._parent.last_alloc:
        return QBrush(Qt.blue)
elif role == Qt.UserRole:
    return proc_name
return QVariant()
{% endhighlight %}
当然还有一些boilerplate
{% highlight python linenos %}
row, col = index.row(), index.column()
if not index.isValid() \
    or not (0 <= row < self.rowCount()) \
    or not (0 <= col < self.columnCount()):
    return QVariant()
{% endhighlight %}

[`headerData()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#headerData

还有一些非必要的方法，比如用来提供header数据的类似data的方法[`headerData()`][]
{% highlight python linenos %}
def headerData(self, section, orientation, role=Qt.DisplayRole):
    if role == Qt.DisplayRole and orientation == Qt.Horizontal:
        return self.headers[section]
{% endhighlight %}

[`beginRemoveRows()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#beginRemoveRows
[`endRemoveRows()`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#endRemoveRows
[`dataChanged(QModelIndex, QModelIndex)`]: http://qt-project.org/doc/qt-4.8/qabstractitemmodel.html#dataChanged
[`QModelIndex()`]: http://qt-project.org/doc/qt-4.8/qmodelindex.html

然后说说怎么合法地对model的数据做修改，根据文档中Resizable models的一节里说的，插入新数据前必须调用[`beginInsertRows()`][]，插入结束后必须调用[`endInsertRows()`][]，同样，删除数据前必须调用[`beginRemoveRows()`][]，删除结束后必须调用[`endRemoveRows()`][]，如果不这么做，根据实验，view中不会有变化。（对列的变化应该是一样的，但是我们这个例子中并不涉及到对列的修改，所以在此略去）。如果列表项的数量没有增加或者减少，只是内容改变了，则需要发射[`dataChanged(QModelIndex, QModelIndex)`][]信号。根据我的实验，发射信号带的参数只需要是两个空的[`QModelIndex()`][]就行了，可能数据量大了之后，指明范围会比较好。

其实在很多修改model内数据的场合下，我们并不知道数据到底是会多还是会少，或者增删数据不好分离出来，在这些情况下，调用上面说的`beginXXXRows()`和`endXXXRows()`还是比较困难的。

[`setModel()`]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#setModel

这样，我们就可以算是完整地实现了一个model。直接调用view的[`setModel()`][]方法就行了。

[view classes]: http://qt-project.org/doc/qt-4.8/model-view-programming.html#view-classes

有关View
---

接下来说说view，这篇文章并不打算继承一个view类，因为很多[Qt提供了很多view][view classes]，很多view直接拿现成的来就可以用。

[QTreeView]: http://qt-project.org/doc/qt-4.8/qtreeview.html
[QTableView]: http://qt-project.org/doc/qt-4.8/qtableview.html
[QListView]: http://qt-project.org/doc/qt-4.8/qlistview.html
[QColumnView]: http://qt-project.org/doc/qt-4.8/qcolumnview.html

为了实现这种genuine的带列的列表，我们只能选[QTreeView][]了，[QTableView][]我试过，效果并不好，然后[QListView][]是压根就不能带列，[QColumnView][]就更不明觉厉了。

[`setRootIsDecorated()`]: http://qt-project.org/doc/qt-4.8/qtreeview.html#rootIsDecorated-prop
[`setItemsExpandable()`]: http://qt-project.org/doc/qt-4.8/qtreeview.html#itemsExpandable-prop

生的[QTreeView][]看起来是这样的 ![raw-treeview.png](/assets/images/pyqt-model-view-framework/raw-treeview.png)为了让它变熟，得先用[`setRootIsDecorated()`][]去掉左边的树形图用的线，然后用[`setItemsExpandable()`][]让项目不能展开。变成这样 ![usable-treeview.png](/assets/images/pyqt-model-view-framework/usable-treeview.png)

接下来调用[`setModel()`][]来设置view使用的model对象。虽然是[QTreeView][]，但是它仍然支持[QAbstractTableModel][]。你也可以把这个model应用到[QTableView][]上，看看展示效果上的区别。

如何交互（只读，可编辑的要涉及到delegate）
---

然后说说交互方面，比如进程项目的添加、页表的转换之类的。

[defaultdict]: http://docs.python.org/2/library/collections.html#collections.defaultdict

向进程列表中添加进程项目，首先要调用model的[`beginInsertRows()`][]，然后修改数据来源（比如我们这里是个内置的[defaultdict][]），修改完毕之后调用[`endInsertRows()`][]。
{% highlight python linenos %}
self.beginInsertRows(QModelIndex(), 0, 0)
self._proc_list[proc_name] = size
self.endInsertRows()
{% endhighlight %}
其中调用[`beginInsertRows()`][]的时候用到的参数是`index, start, end`，这里为了简单，取了一些定值，对实际效果（好像）也没什么影响。
删除项目也是差不多了，这里不再赘述。

[QAbstractItemView]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html
[`selectionModel()`]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#selectionModel
[QItemSelectionModel]: http://qt-project.org/doc/qt-4.8/qitemselectionmodel.html
[`currentRowChanged()`]: http://qt-project.org/doc/qt-4.8/qitemselectionmodel.html#currentRowChanged

为了显示每个进程的对应列表，必须知道在进程列表中，当前选中的是哪一项。在[QAbstractItemView][]里有一个方法[`selectionModel()`][]可以拿到这个view的[QItemSelectionModel][]，它管理这个view关于*选择*的一切信息。可以同过它拿到被选中的行、列，或者判断是否有行或列被选中（具体方法参见[文档][QItemSelectionModel]。这里我们要用的是它的[`currentRowChanged()`][]信号。
{% highlight python linenos %}
self.connect(self.proc_list_view.selectionModel(),
             SIGNAL('currentRowChanged(QModelIndex, QModelIndex)'),
             self.switch_page_table_model)
{% endhighlight %}

然后是这个信号连接到的槽的代码
{% highlight python linenos %}
def switch_page_table_model(self, index, _=None):
    proc_name = self.process_model.data(index, role=Qt.UserRole)
    self.current_proc_name = proc_name
    self.page_table_view.setModel(self.page_table_models[proc_name])
{% endhighlight %}
我维护了一个[defaultdict][]，进程名做键，PageTableModel作为值，这个函数首先通过index拿到这个index对应的进程名`proc_name`，然后用[`setModel()`][]方法切换`self.page_table_view`使用的model。实现起来还是比较简单的。

[selectionMode]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#selectionMode-prop
[selectionMode-enum]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#SelectionMode-enum
[`setSelectionModel()`]: http://qt-project.org/doc/qt-4.8/qabstractitemview.html#setSelectionModel

如果要改变一个view的选择模式，可以调用[`setSelectionMode()`][selectionMode]，这里我使用的是默认的，而页表控件可以使用[ExtendedSelection模式][selectionMode-enum]来开启多选功能。如果要获得选中项，仍然可以通过[QItemSelectionModel][]来获得，也可以使用[`selectedIndexes()`][]来获取（我猜测这个方法只是对[QItemSelectionModel][]的一些方法做了一个convenience包装）。Qt为啥要还要单独提供一个model来表示选中项呢？我的理解是，这也是为了灵活性做的一个解耦，有了这个类，我们就可以利用[`setSelectionModel()`][]同步两个或者多个view的selection了。要注意的是这些view使用的model最好相同，model不同的话，同步selection好像也没什么意义。

示例代码
{% highlight python linenos %}
model = YourModel()
view1 = QTableView()
view1.setModel(model)
view2 = QListView()
view2.setModel(model)
# 注意：只有在setModel之后才能设置selectionModel
# 因为只有在设置了model之后view才会生成自己的selectionModel
# 如果在setModel之前设置，python会崩溃
view2.setSelectionModel(view1.selectionModel())
{% endhighlight %}

关于delegate
---

这篇文章就先不介绍这个了，我自己用的也不多。感兴趣的可以先看看[这个文档](http://files.meetup.com/2179791/pyqt-model-view-framework-overview.pdf )，是一位台湾友人写的，我觉得写的挺好的，不过毕竟是个overview，所以内容也不多，剩下的就要靠各位自己钻研了。

后记
---

本文的代码可以在[这个repo][os-exp]找到（前面也说过了）。

