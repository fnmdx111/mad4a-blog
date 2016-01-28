---
layout: post
title: "Solutions to exercises in Typeclassopedia"
category: summary
tags: [Haskell, Typeclassopedia]
---

最近在重新学习Haskell，看完LYAHFGG之后，想加深一下对Applicative，Monad啥的理解，找了这个叫Typeclassopedia的文章来看。断断续续看了两个星期左右，把里面的习题也做得差不多了。下面列一下题解（不保证完全，也不保证正确）。

Functor 函子
----

要为一个类型`f`实现一个函子实例，这个类型必须具有`* -> *`这样的kind。也就是说`f`必须再接受一个类型`a`才能成为一个完整的类型。而函子的`fmap`就是一个将`a`映射到另外一个类型`b`的映射。所以`fmap`具有这样的类型签名：

```haskell
fmap :: (a -> b) -> f a -> f b
```

### 实现`Either e`与`((->) e)`的函子实例


首先我们知道`Either l r`是一个完整的类型（即`Either`的kind是`* -> * -> *`），那么要实现关于`Either`的函子实例，必须固定最左侧的`*`，也就是说我们只能实现关于`Either l`的函子实例。更具体来说，我们实现的函子实例可以将`Either l a`变换为`Either l b`。

```haskell
data MyEither = MyLeft e | MyRight a
instance Functor (MyEither e) where
  _ `fmap` MyLeft e = MyLeft e
  f `fmap` MyRight a = MyRight $ f a
```

同样的道理`((->) e)`的函子实例可以将`(e -> a)`映射为`(e -> b)`，那么它的实现就很直观了。

```haskell
instance ((->) e) where
  f `fmap` g = \e -> f (g e)
```

如果要写得吊一点：

```haskell
instance ((->) e) where
  fmap = (.)
```

### 实现`((,) e)`和`data Pair a = Pair a a`的函子实例，并解释他们的异同

与上面一样，`(,)`的kind是`* -> * -> *`，那么只能实现`((,) e)`的函子实例，也就是说只能实现`(e, a)`到`(e, b)`的映射，而Pair的kind已经是`* -> *`了，所以可以实现`Pair a a`到`Pair b b`的函子实例。

```haskell
newtype MyTuple e a = MyTuple { getMyTuple :: (e, a) }

instance Functor (MyTuple e) where
  f `fmap` MyTuple (e, a) = MyTuple (e, f a)


data Pair a = Pair a a

instance Functor Pair where
  f `fmap` Pair a b = Pair (f a) (f b)
```

### 实现以下类型的函子实例

```haskell
data ITree a = Leaf (Int -> a)
             | Node [ITree a]
```

Trivial:

```haskell
instance Functor ITree where
  f `fmap` Leaf t = Leaf $ f `fmap` t
  f `fmap` Node xs = Node $ map (fmap f) xs
```

*如果你知道`[]`也是一个函子，那么`map`实际上可以写成`fmap`。

### 说明两个函子的复合也是一个函子

首先定义出两个函子的复合这个类型，要注意`FCompose`这个构造器是一个一元函数，而不是三元函数：

```haskell
data FCompose f1 f2 x = FCompose (f1 (f2 x))
	deriving Show
```

当`f1`和`f2`是函子时，

```haskell
instance (Functor f1, Functor f2) => Functor (FCompose f1 f2) where
  f `fmap` FCompose t = FCompose $ fmap f `fmap` t
  -- = FCompose $ fmap (fmap f) t = FCompose $ (fmap . fmap) f t
```

对于`FCompose f1 f2`，如果，`fmap`方法的类型应该是

```haskell
fmap :: (Functor f1, Functor f2) => (a -> b) -> FCompose f1 f2 a -> FCompose f1 f2 b
```

也就是说如果我们能把`f :: a -> b`映射到`f1 (f2 a)`上并得到`f1 (f2 b)`，那么两个函子的复合就仍是一个函子。所以，

1. 首先利用`fmap :: (a -> b) -> f2 a -> f2 b`把`f :: a -> b`提升（lift）到`f2`上得到`f' :: f2 a -> f2 b`（柯里化）；
2. 这样就可以用`f1`的`fmap :: (f2 a -> f2 b) -> f1 (f2 a) -> f1 (f2 b)`将`f'`提升为`f'' :: f1 (f2 a) -> f1 (f2 b)`（仍然是柯里化）；
3. 接下来将`f''`应用到`f1 (f2 a)`上得到`f1 (f2 b)`。

这说明两个任意函子的复合确实仍然是一个函子。它告诉我们，我们可以利用各种函子复合出任意复杂的新函子。

实际上，函数式编程的一个重要的部分就是利用各种复杂结构间的复合，降低整个程序的复杂度，即尽量将程序的复杂度转移到结构之中，由于结构是通用的，并且充分研究过的，使得程序员可以更加关注于问题的业务上的解决。也就是说，Typeclassopedia这篇文章里介绍的各种数据类型其实就是函数式编程中的**设计模式**。

要得到关于多个函子的复合的`fmap`方法，只需要将多个`fmap`复合。例如两个函子复合的情况，可以是`(fmap . fmap) f t`。

Applicative 应用函子
----

### 证明以下等式

```haskell
pure f <*> x = pure (flip ($)) <*> x <*> pure f
```

从右边入手

```haskell
    pure (flip ($)) <*> x <*> pure f
  = pure (flip ($)) <*> pure x' <*> pure f where x = pure x'
  = pure (flip ($) x' f)  -- (Applicative的同态性)
  = pure (f x')  -- (f $ y = f y)
  = pure f <*> pure x'
  = pure f <*> x
```

其实仔细看了之后会发现这个等式其实很无聊。

### 实现`Maybe`的Applicative实例

Trivial:

```haskell
data MyMaybe a = MyJust a | MyNothing

instance Functor MyMaybe where
  f `fmap` MyJust x = MyJust $ f x
  f `fmap` MyNothing = MyNothing

instance Applicative MyMaybe where
  pure x = MyJust x
  MyJust f <*> x = fmap f x
  MyNothing <*> x = MyNothing
```

我们接下来来检查上面的实现是否满足Applicative的规定。

恒等律：

```haskell
    pure id <*> MyJust 42
  = MyJust id <*> MyJust 42
  = fmap id (MyJust 42)
  = MyJust (id 42)
  = MyJust 42
  
    pure id <*> MyNothing
  = MyJust id <*> MyNothing
  = fmap id MyNothing
  = MyNothing
```

同态律：

```haskell
    pure f <*> pure x
  = MyJust f <*> MyJust x
  = fmap f (MyJust x)
  = MyJust (f x)
  = pure (f x)
```

交换律：

```haskell
-- 若 u = MyJust u'，
    u <*> pure y
  = MyJust u' <*> pure y
  = MyJust u' <*> MyJust y
  = fmap u' (MyJust y)
  = MyJust (u' y)
  = pure (u' y)
  = pure (u' $ y)
  = pure ((\x -> x $ y) u')
  = pure (($ y) u')
  = pure ($ y) <*> pure u' -- 由同态律得
  = pure ($ y) <*> u

-- 若 u = MyNothing
    u <*> pure y
  = MyNothing <*> pure y
  = MyNothing

    pure ($ y) <*> u
  = fmap ($ y) MyNothing
  = MyNothing
  
-- => u <*> pure y = pure ($ y) <*> u
```

复合律：

```haskell
    u <*> (v <*> w)
  = u <*> (Maybe v' <*> Maybe w') -- 由(<*>)的定义得
  = u <*> Maybe (v' w')
  = Maybe u' <*> Maybe (v' w')
  = Maybe (u' (v' w'))
  = Maybe ((u' . v') w') -- 由(.)的定义得
  = Maybe ((.) u' v' w')
  = Maybe ((.) u' v') <*> Maybe w' -- 由同态律得
  = Maybe ((.) u') <*> Maybe v' <*> w -- 仍然由同态律得
  = Maybe (.) <*> Maybe u' <*> v <*> w
  = Maybe (.) <*> u <*> v <*> w
  = pure (.) <*> u <*> v <*> w
```

### 确定`ZipList`的Applicative实例里`pure`的正确定义，能够满足Applicative性质的实现有且仅有一个

我们已经知道`(<*>)`是使用`zipWith`函数实现的，现在考虑第一条性质`pure id <*> v = v`，如果`v`是一个有3个元素的`ZipList`，那么`pure id`就应该返回一个有**至少**三个`id`的`ZipList`，使得`zipWith`函数能够将`v`中的元素全部利用起来。到这里我们可以很轻松的得出`pure`的定义了

```haskell
pure = ZipList . repeat
```

我们稍微检查一下这个实现的性质：

恒等律：

```haskell
    pure id <*> ZipList xs
  = ZipList (repeat id) <*> ZipList xs
  = ZipList (zipWith ($) (repeat id) xs)
  = ZipList xs -- 由Haskell常识得
```

同态律：

```haskell
    pure f <*> pure x
  = ZipList (repeat f) <*> ZipList (repeat x)
  = ZipList (zipWith ($) (repeat f) (repeat x))
  = ZipList (repeat (f $ x)) -- 由Haskell常识得
  = ZipList (repeat (f x))
  = ZipList . repeat (f x) -- 由(.)的定义得
  = pure (f x)
```

剩下的规则就不一一推导了。

### 利用`unit`和`(**)`实现`pure`与`(<*>)`，再反过来实现他们

考虑在这个情况下的`pure`、`unit`、`(**)`和`fmap`的类型签名（已知一个Monoidal是一个函子）：

```haskell
pure :: Monoidal m => a -> m a
unit :: Monoidal m => m ()
(**) :: Monoidal m => m a -> m b -> m (a, b)
fmap :: Monoidal m => (t -> a) -> m t -> m a
```

可以发现`fmap`的返回值类型就是我们关心的类型（`fmap`的返回值类型与`pure`的相同）。但是此时`fmap`中的`t`从哪来呢。这时我们可以注意到Monoidal的`unit`方法恒定返回一个`m ()`类型的值，那么如果将`t`特化成`()`，就有了

```haskell
fmap :: Monoidal m => (() -> a) -> m () -> m a
```

这样就清楚了，先构造出一个接受一个任意参数的函数，然后将这个函数`fmap`到`unit`上

```haskell
pure x = fmap (\_ -> x) unit
-- or
pure x = fmap (const x) unit
```

再考虑`(<*>)`与其它已知方法的类型签名：

```haskell
(<*>) :: Monoidal m => m (a -> b) -> m a -> m b
f <*> x = ???

unit :: Monoidal m => m ()
(**) :: Monoidal m => m a -> m b -> m (a, b)
fmap :: Monoidal m => (a -> b) -> m a -> m b
```

可以发现`(<*>)`与`fmap`除了第一个参数类型不是特别相同，其它的是一样的。所以思路仍然是构造出一个供`fmap`使用的函数。同时我们发现`(**)`是Monoidal中可以与两个类型交互的方法，说明我们在构造上面说的函数中会使用到它。现在，已知量是`f :: m (a -> b)`，`x :: m a`，我们首先可以尝试`f ** x`，这样我们会得到`f ** x :: m (a -> b, a)`，而这样的类型很容易让人联想到它的计算结果的类型就是`m b`！因此如果将`fmap`中的`m a`特化成`m (a -> b, a)`，那么整个`fmap`的类型签名会变为：

```haskell
fmap :: ((a -> b, a) -> b) -> m (a -> b, a) -> m b
```

问题也就变为，如何构造出一个函数使得其类型为`(a -> b, a) -> b`，这样就很简单了

```haskell
mf <*> mx = fmap (\(f, x) -> f x) (mf ** mx)
```

这里另外介绍一个技巧（或者说是idiom）：`\(f, x) -> f x`可以写成`uncurry id`。

很脏。首先来检查一下`uncurry`的类型：

```haskell
uncurry :: (a -> b -> c) -> (a, b) -> c
```

因为`(->)`是右结合的，所以上面的类型也可以写成

```haskell
uncurry :: (a -> d) -> (a, b) -> c
  where d :: b -> c
```

也就是说如果你给我一个返回另外一个一元函数的一元函数，并且给我两个参数，我能帮你计算出结果。如果要把`id :: a -> a`提供给它，那么`id`的参数必须是一个一元函数，也就是说它必须变形为`id :: (b -> c) -> (b -> c)`，那么就有了

```haskell
uncurry id :: (b -> c, b) -> c
```

这跟我们上面推理出的`(a -> b, a) -> b`的类型恰好一样。

用`pure`来实现`unit`很简单：

```haskell
unit :: Applicative f => f ()
unit = pure ()
```

用Applicative方法来实现`(**)`，首先检查类型

```haskell
pure :: Applicative f => a -> f a
(<*>) :: Applicative f => f (a -> b) -> f a -> f b
(**) :: Applicative f => f a -> f b -> f (a, b)
```

我们可以观察出`(<*>)`与`(**)`的类型很相似，而且要使用`(<*>)`来获得`(**)`的结果。那么不妨将`(<*>)`的返回值类型特化为`f (a, b)`，这样`(<*>)`的整个类型就是：

```haskell
(<*>) :: Applicative f => f (t -> (a, b)) -> f t -> f (a, b)
```

接下来就是如何构造这样一个函数`t -> (a, b)`使得我们可以利用已知量`f a`与`f b`。很自然的想法是构造一个这样的二元函数`\a b -> (a, b)`，这样我们就可以

```haskell
(**) :: f a -> f b -> f (a, b)
fa ** fb = pure (\a b -> (a, b)) <*> fa <*> fb
```

或者

```haskell
fa ** fb = pure (,) <*> fa <*> fb
```

看到这，你就会觉得上面的推导其实是复杂化了。我们可以这样理解：将元组构造器`(,)`通过`pure`提升到Applicative中，然后将两个已经在Applicative里的已知量通过`(<*>)`应用到`pure (,)`上。

Monad 单子
----

### 实现列表的单子实例

要注意到这里的列表指的并不是`ZipList`。

```haskell
instance Functor [] where
  f `fmap` [] = []
  f `fmap` (x:xs) = (f x):(fmap f xs)

instance Applicative [] where
  pure x = [x]
  fs <*> xs = concat $ map (\f -> fmap f xs) (fmap ($) fs)
  -- 首先通过(fmap ($) fs)取得[($) f]，然后将每一个(($) f)通过fmap应用于xs，最后
  -- concat一下来满足类型约束。

instance Monad [] where
  xs >>= f = concat $ pure f <*> xs
```

接下来检查一下单子所要满足的规律

左恒等律：

```haskell
    return x >>= f
  = pure x >>= f
  = [x] >>= f
  = concat $ [f] <*> [x]
  = concat (concat $ map (\f -> fmap f [x]) (fmap ($) [f]))
  = concat (concat $ map (\f -> fmap f [x]) [(f $)])
  = concat (concat $ [fmap (f $) [x]])
  = concat (concat [[f x]])
  = concat [f x]
  = f x
```

右恒等律：

```haskell
    xs >>= return
  = xs >>= pure
  = concat $ pure pure <*> xs
  = concat $ [pure] <*> xs
  = concat (concat $ map (\f -> fmap f xs) (fmap ($) [pure]))
  = concat . concat $ map (\f -> fmap f xs) [(pure $)]
  = concat . concat $ [fmap (pure $) xs]
  = concat . concat $ [fmap (pure $) [x1, x2, ..., xk, ...]]
  = concat . concat $ [[(pure $ x1), (pure $ x2), ..., (pure $ xk), ...]]
  = concat . concat $ [[(pure x1), (pure x2), ..., (pure xk), ...]]
  = concat . concat $ [[[x1], [x2], ..., [xk], ...]]
  = concat $ [[x1], [x2], ..., [xk], ...]
  = [x1, x2, ..., xk, ...]
  = xs
```

结合律：

```haskell
    xs >>= (\y -> f y >>= g)
  = xs >>= (\y -> concat $ pure g <*> f y)
  = xs >>= (\y -> concat $ [g] <*> f y)
  = xs >>= (\y -> concat (concat $ map (\h -> fmap h (f y)) (fmap ($) [g])))
  = xs >>= (\y -> concat . concat $ map (\h -> fmap h (f y)) [(g $)])
  = xs >>= (\y -> concat . concat $ [fmap (g $) (f y)])
  = xs >>= (\y -> concat . concat $ [[g fy1, g fy2, ..., g fyk, ...]])
  = xs >>= (\y -> concat [g fy1, g fy2, ..., g fyk, ...])
  = xs >>= (\y -> concat [[gfy11, gfy12, ..., gfy1k, ...],
                          [gfy21, gfy22, ..., gfy2k, ...],
						  ...,
						  [gfyk1, gfyk2, ..., gfykk, ...],
						  ...,])
  = xs >>= (\y -> [gfy11, gfy12, ..., gfy21, gfy22, ... gfyk1, gfyk2, ...])

let gfypq = [gfy11, gfy12, ..., gfy21, gfy22, ..., gfyk1, ...],

    xs >>= (\y -> f y >>= g)
  = xs >>= (\y -> gfypq)
  = concat $ [\y -> gfypq] <*> xs
  = concat . concat $ map (\h -> fmap h xs) (fmap ($) [\y -> gfypq])
  = concat . concat $ map (\h -> fmap h xs) [((\y -> gfypq) $)]
  = concat . concat $ [fmap ((\y -> gfypq) $) xs]
  = concat . concat $ [fmap ((\y -> gfypq) $) [x1, x2, ..., xk, ...]]
  = concat . concat $ [[gfx1pq, gfx2pq, ..., gfxkpq, ...]]
  = concat [[gfx111, gfx112, ..., gfx121, gfx122, ...],
            [gfx211, gfx212, ..., gfx221, gfx222, ...],
			...,
			[gfxk11, gfxk12, ..., gfxk21, gfxk22, ...],
			...]
  = [gfx111, gfx112, ..., gfx121, gfx122, ..., gfxk11, gfxk12, ...]
  
    (xs >>= f) >>= g
  = (concat $ [f] <*> xs) >>= g
  = (concat . concat $ map (\f -> fmap f xs) [(f $)]) >>= g
  = (concat . concat $ [fmap (f $) xs]) >>= g
  = (concat . concat $ [[f x1, f x2, ..., f xk, ...]]) >>= g
  = (concat [f x1, f x2, ..., f xk, ...]) >>= g
  = (concat [[fx11, fx12, ..., fx1k, ...],
             [fx21, fx22, ..., fx2k, ...],
			 ...,
			 [fxk1, fxk2, ..., fxkk, ...]]) >>= g
  = [fx11, fx12, ..., fx1k, ..., fx21, fx22, ..., fx2k, ...] >>= g

let fxpq = [fx11, fx12, ..., fx1k, ..., fx21, fx22, ..., fx2k, ...],

    (xs >>= f) >>= g
  = fxpq >>= g
  = concat $ [g] <*> fxpq
  = concat . concat $ map (\h -> fmap h fxpq) [(g $)]
  = concat . concat $ [fmap (g $) fxpq]
  = concat . concat $ [[g fx11, g fx12, ..., g fx1k, ..., g fx21, ...]]
  = concat [g fx11, g fx12, ..., g fx1k, ..., g fx21, g fx22, ...]
  = concat [[gfx111, gfx112, ...],
            [gfx121, gfx122, ...],
			...,
			[gfxpq1, gfxpq2, ...],
			...]
  = [gfx111, gfx112, ..., gfx121, gfx122, ..., gfxpq1, gfxpq2, ...]
  = xs >>= (\y -> f y >>= g)
```

如果用更简单的`(>>=)`实现（比如`base`包里给出的使用列表解析的实现），结合律的证明可能不会这么复杂。

### 实现`((->) e)`的单子实例

`((->) e)`的函子实例前面已经实现过，这里不再重复。

首先来实现`((->) e)`的Applicative实例，`pure`很trivial：

```haskell
pure x = \_ -> x
-- or
pure = const
```

接下来看`(<*>)`特化为`((->) e)`的类型：

```haskell
(<*>) :: ((->) e (a -> b)) -> ((->) e a) -> ((->) e b)
-- i.e.
(<*>) :: (e -> (a -> b)) -> (e -> a) -> (e -> b)
-- 由于(->)是右结合的
(<*>) :: (e -> a -> b) -> (e -> a) -> (e -> b)
```

沿着这个类型，它的具体实现就很清楚了，`f :: e -> a -> b`，`g :: e -> a`，我们要得到一个`e -> b`类型的返回值，首先要做的是创建一个接受一个`e`的函数，即`\e -> ???`。然后使用`g e`获得一个`a`类型的值。根据之前的推理，将这个`a`类型的值与`e`一起作用于`f`可以得到一个`b`，即

```haskell
f <*> g = \e -> f e (g e)
```

如果你看Haskell的源码，你会发现其实它是这么实现的：

```haskell
(<*>) :: (e -> a -> b) -> (e -> a) -> (e -> b)
-- 由于(->)右结合
(<*>) :: (e -> a -> b) -> (e -> a) -> e -> b
```

这也就告诉我们，上面的式子可以这么写：

```haskell
(<*>) f g e = f e (g e)
```

下面实现`((->) e)`的单子实例：它的`(>>=)`类型应该是

```haskell
(>>=) :: ((->) e a) -> (a -> ((->) e b)) -> ((->) e b)
-- =>
(>>=) :: (e -> a) -> (a -> (e -> b)) -> (e -> b)
-- =>
(>>=) :: (e -> a) -> (a -> e -> b) -> e -> b
```

那么

```haskell
instance Monad ((->) e) where
  (>>=) f g e = g (f e) e
  -- or f >>= g = \e -> g (f e) e
```

接下来检查这个实现的性质：

左恒等律：

```haskell
    return f >>= g
  = pure f >>= g
  = (\_ -> f) >>= g
  = \e -> g ((\_ -> f) e) e
  = \e -> g f e
  = g f
```

右恒等律：

```haskell
    f >>= return
  = f >>= pure
  = \e -> pure (f e) e
  = pure (f e)
  = \e -> (\_ -> f e) e
  = \e -> f e
  = f
```

结合律：

```haskell
    f >>= (\t -> g t >>= h)
  = f >>= (\t -> (\e -> h (g t e) e))
  = f >>= (\t e -> h (g t e) e) -- uncurry
  = \e' -> (\t e -> h (g t e) e) (f e') e'
  = \e' -> (\e -> h (g (f e') e) e) e'
  = \e' -> h (g (f e') e') e'
  = \e' -> h ((\k -> g (f k) k) e') e'
  = (\k -> g (f k) k) >>= h -- \e' -> h (K e') e' = K >>= h
  = (f >>= g) >>= h         -- 同理
```

### 实现以下数据类型的函子与单子

```haskell
-- Functor f =>
data Free f a = Var a
              | Node (f (Free f a))
```

既然我们在实现关于`Free f`的函子实例，我们就可以假设它是一个函子。那么对于`Free f a`，它的`fmap`的类型是

```haskell
fmap :: Functor f => (a -> b) -> Free f a -> Free f b
```

对于`Var a`，`fmap`很简单

```haskell
g `fmap` Var x = Var $ g x
```

对于`Node t`，我们可以观察出来，`a`实际上是裹在两层函子里的，即首先它裹在`Free f a`这一个函子里，同时这个函子又裹在`f`这个函子里，那么根据之前的结论，去访问裹在两层函子里的值，我们用`fmap . fmap`，即

```haskell
g `fmap` Node t = Node $ (fmap . fmap) g t
```

接下来实现`Free f a`的Applicative实例：

```haskell
pure :: Functor f => a -> Free f a
-- =>
pure = Var

(<*>) :: Functor f => Free f (a -> b) -> Free f a -> Free f b
-- =>
Var f <*> free = fmap f free
Node t <*> free = ???
```

接下来考虑`Node t`的情况，这里的`t`实际上是一个`f (Free f (a -> b))`（观察它的`data`定义的第二句`Node (f (Free f a))`），即

```haskell
t :: Functor => f t'
  where t' :: Free f (a -> b)
```

而`free`则是一个`Free f a`，我们要解决的问题就是将`a -> b`应用到`a`上。我们最自然的想法，是递归地利用`(<*>)`使得`t`中的`t' :: Free f (a -> b)`能够与`Free f a`作用，即我们想要得到`t' <*> free`。

然而`t'`我们是不能直接得到的，它还裹在一个`f`中。回想起`fmap`的另一种理解方式：它将一个函数提升至对应的函子上下文中，即：

```haskell
fmap :: (a -> b) -> f a -> f b
fmap f :: f a -> f b
```

那么我们可以利用函子`f`的`fmap`将`(<*> free)`提升至函子`f`中，得到一个提升过的函数，再将`t`应用于这个函数上。更具体地，我们可以特化这其中的`a`为`Free f c`，`b`为`Free f d`，得到下面的类型

```haskell
fmap :: (Free f c -> Free f d) -> f (Free f c) -> f (Free f d)
-- 将c换为a -> b，d换为b
fmap :: (Free f (a -> b) -> Free f b) -> f (Free f (a -> b)) -> f (Free f b)

-- 而
(<*>) :: Functor f => Free f (a -> b) -> Free f a -> Free f b
(<*> free) :: Functor f => Free f (a -> b) -> Free f b 

-- 则
fmap (<*> free) :: f (Free f (a -> b)) -> f (Free f b)
```

这样，我们就可以把`t`应用于上面得到的式子：

```haskell
Node t <*> free = Node $ fmap (<*> free) t
```

接下来实现`Free f a`的单子实例：

```haskell
instance Monad (Free f) where
  Var a >>= f = f a
  Node t >>= f = ...
```

关于`Node t`，同样的

```haskell
t :: Functor f => f t'
  where t' :: Free f a

f :: Functor f => a -> Free f b
```

而`(>>=)`的类型为：

```haskell
(>>=) :: Functor f => Free f a -> (a -> Free f b) -> Free f b
```

则我们自然地想到，可以递归地利用`(>>=)`，来让`t' >>= f`，然而`t'`仍然裹在一层函子`f`中，那么简单地利用函子`f`的`fmap`将`(>>= f)`提升至函子`f`中即可，即

```haskell
Node t >>= f = Node $ fmap (>>= f) t
```

至此，`Free f a`的单子实例的推导结束。

可以看到，在上面的推导中，我们打了大量的类型运算的草稿，并且通过这些类型，我们能够对具体的实现有一种直观上的感受。通过类型运算来指引具体的实现在Haskell中是很重要的一个技巧。

接下来检查该实现是否符合各个单子律：

左恒等律：

```haskell
    return (Var a) >>= k
  = pure (Var a) >>= k
  = Var (Var a) >>= k
  = k (Var a)

	return (Node t) >>= k
  = Var (Node t) >>= k
  = k (Node t)
```

右恒等律：

```haskell
    Var a >>= return
  = Var a >>= Var
  = Var a

    Node t >>= return
  = Node t >>= Var
  = Node $ fmap (>>= Var) t

-- 若 t = f (Var a)，则
	Node t >>= return
  = Node $ fmap (>>= Var) t
  = Node $ fmap (\_ -> Var a >>= Var) t
  = Node $ t -- 请通过类型运算让自己相信这一步是正确的
  = Node t

-- 若 t = f (Node u)，则
    Node t >>= return
  = Node $ fmap (\_ -> Node u >>= Var) t

-- 递归至第一步，如果t有穷（其递归结构终止于Var a）,则
    Node t >>= return
  = Node $ t -- 请通过类型运算让自己相信这一步是正确的
  = Node t
```

结合律：太复杂，在简单的方法里我证明不出来。

### 利用`fmap`和`join`实现`(>>=)`

首先检查他们的类型：

```haskell
fmap :: Functor m => (x -> y) -> m x -> m y
join :: Monad m => m (m a) -> m a
(>>=) :: Monad m => m a -> (a -> m b) -> m b
```

然后检查已知量：

```haskell
m >>= f :: Monad m => m b
  where m :: m a
        f :: a -> m b
```

看到`f :: a -> m b`和`fmap`的第一个参数，不妨将`y`特化为`m b`，那么就有

```haskell
fmap :: Functor m => (x -> m b) -> m x -> m (m b)
```

看到这样的返回值类型就能很自然地将`join`联想起来了：

```haskell
m >>= f = join (fmap f m)
```
