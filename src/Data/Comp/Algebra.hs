{-# LANGUAGE GADTs, RankNTypes, ScopedTypeVariables, TypeOperators,
  FlexibleContexts, CPP #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Data.Comp.Algebra
-- Copyright   :  (c) 2010-2011 Patrick Bahr, Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Patrick Bahr <paba@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- This module defines the notion of algebras.
--
--------------------------------------------------------------------------------

module Data.Comp.Algebra (
      -- * Algebras & Catamorphisms
      Alg,
      freeAlgHom,
      cata,
      cata',
      appCxt,
      
      -- * Monadic Algebras & Catamorphisms
      AlgM,
      algM,
      freeAlgHomM,
      cataM,
      cataM',

      -- * Term Homomorphisms
      CxtFun,
      SigFun,
      TermHom,
      appTermHom,
      compTermHom,
      appSigFun,
      compSigFun,
      termHom,
      compAlg,

      -- * Monadic Term Homomorphisms
      CxtFunM,
      SigFunM,
      TermHomM,
      SigFunM',
      TermHomM',
      sigFunM,
      termHom',
      appTermHomM,
      termHomM,
      termHomM',
      appSigFunM,
      appSigFunM',
      compTermHomM,
      compSigFunM,
      compAlgM,
      compAlgM',

      -- * Coalgebras & Anamorphisms
      Coalg,
      ana,
      ana',
      anaExp,
      CoalgM,
      anaM,

      -- * Paramorphisms

      RAlg,
      para,
      RAlgM,
      paraM,

      -- * Apomorphisms

      RCoalg,
      apo,
      RCoalgM,
      apoM,

      -- * CV-Algebras & Histomorphisms
      CVAlg,
      histo,
      CVAlgM,
      histoM,

      -- * CV-Coalgebras & Futumorphisms
      CVCoalg,
      futu,
      CVCoalgM,
      futuM,

      -- * Exponential Functors

      appTermHomE,
      cataE,
      appCxtE,
      
    ) where

import Data.Comp.Term
import Data.Comp.Ops
import Data.Traversable
import Control.Monad hiding (sequence, mapM)
import Data.Comp.ExpFunctor

import Prelude hiding (sequence, mapM)



{-| This type represents an algebra over a functor @f@ and domain
@a@. -}

type Alg f a = f a -> a

freeAlgHom :: forall f h a b . (Functor f) =>
              Alg f b -> (a -> b) -> Cxt h f a -> b
freeAlgHom f g = run
    where run :: Cxt h f a -> b
          run (Hole v) = g v
          run (Term c) = f $ fmap run c

{-| This function folds the given term using the given fold
function. This is the unique homomorphism @Term f -> a@ from the
initial algebra @Term f@ to the given algebra of type @f a -> a@. -}

cata :: forall f a . (Functor f) =>
          Alg f a -> Term f -> a 
{-# NOINLINE [1] cata #-}
-- cata f = freeAlgHom f undefined
-- the above definition is safe since terms do not contain holes
--
-- a direct implementation:
cata f = run 
    where run :: Term f -> a
          run (Term t) = f (fmap run t)


{-| This function applies the given algebra recursively to each
subcontext of the given context. -}

cata' :: (Functor f) => Alg f a -> Cxt h f a -> a
cata' f = freeAlgHom f id


{-| This function applies a whole context into another context. -}

appCxt :: (Functor f) => Context f (Cxt h f a) -> Cxt h f a
appCxt = cata' Term



{-| This type represents a monadic algebra. It is similar to 'Alg' but
the return type is monadic.  -}

type AlgM m f a = f a -> m a 


algM :: (Traversable f, Monad m) => AlgM m f a -> Alg f (m a)
algM f x = sequence x >>= f

freeAlgHomM :: forall h f a m b. (Traversable f, Monad m) =>
               AlgM m f b -> (a -> m b) -> Cxt h f a -> m b
-- freeAlgHomM alg var = freeAlgHom (algM alg) var
freeAlgHomM algm var = run
    where run :: Cxt h f a -> m b
          run (Hole x) = var x
          run (Term x) = mapM run x >>= algm

{-| This is a monadic version of 'cata'.  -}

cataM :: forall f m a. (Traversable f, Monad m) => AlgM m f a -> Term f -> m a 
{-# NOINLINE [1] cataM #-}
-- cataM = cata . algM
cataM algm = run
    where run :: Term f -> m a
          run (Term x) = mapM run x >>= algm




{-| This function applies the given monadic algebra recursively to
each subcontext of the given context. -}

cataM' :: forall h f a m . (Traversable f, Monad m)
            => AlgM m f a -> Cxt h f a -> m a
{-# NOINLINE [1] cataM' #-}
-- cataM' f = freeAlgHom (\x -> sequence x >>= f) return
cataM' f = run
    where run :: Cxt h f a -> m a
          run (Hole x) = return x
          run (Term x) = mapM run x >>= f


{-| This type represents context function. -}

type CxtFun f g = forall a h. Cxt h f a -> Cxt h g a

{-| This type represents uniform signature function
specification.-}

type SigFun f g = forall a. f a -> g a


{-| This type represents a term algebra. -}

type TermHom f g = SigFun f (Context g)



appTermHom :: (Traversable f, Functor g) => TermHom f g -> CxtFun f g
{-# INLINE [1] appTermHom #-}
-- Constraint Traversable f is not essential and can be replaced by
-- Functor f. It is, however, needed for the shortcut-fusion rules to
-- work.
appTermHom = appTermHom'

{-| This function applies the given term homomorphism to a
term/context. -}

appTermHom' :: forall f g . (Functor f, Functor g) => TermHom f g -> CxtFun f g
{-# NOINLINE [1] appTermHom' #-}
-- Note: The rank 2 type polymorphism is not necessary. Alternatively, also the type
-- (Functor f, Functor g) => (f (Cxt h g b) -> Context g (Cxt h g b)) -> Cxt h f b -> Cxt h g b
-- would achieve the same. The given type is chosen for clarity.
appTermHom' f = run where
    run :: CxtFun f g
    run (Hole b) = Hole b
    run (Term t) = appCxt . f . fmap run $ t




{-| This function composes two term algebras
-}

compTermHom :: (Functor g, Functor h) => TermHom g h -> TermHom f g -> TermHom f h
-- Note: The rank 2 type polymorphism is not necessary. Alternatively, also the type
-- (Functor f, Functor g) => (f (Cxt h g b) -> Context g (Cxt h g b))
-- -> (a -> Cxt h f b) -> a -> Cxt h g b
-- would achieve the same. The given type is chosen for clarity.
compTermHom f g = appTermHom' f . g





{-| This function composes a term algebra with an algebra. -}

compAlg :: (Functor g) => Alg g a -> TermHom f g -> Alg f a
compAlg alg talg = cata' alg . talg


{-| This function applies a signature function to the
given context. -}

appSigFun :: (Functor f, Functor g) => SigFun f g -> CxtFun f g
appSigFun f = appTermHom' $ termHom $ f


{-| This function composes two signature functions.  -}

compSigFun :: SigFun g h -> SigFun f g -> SigFun f h
compSigFun f g = f . g


{-| Lifts the given signature function to the canonical term homomorphism.
-}

termHom :: (Functor g) => SigFun f g -> TermHom f g
termHom f = simpCxt . f

{-|
  This type represents monadic context function.
-}
type CxtFunM m f g = forall a h. Cxt h f a -> m (Cxt h g a)

{-| This type represents monadic signature functions. -}

type SigFunM m f g = forall a. f a -> m (g a)

{-| This type represents monadic signature functions.  It is similar
to 'SigFunM' but has monadic values also in the domain. -}

type SigFunM' m f g = forall a. f (m a) -> m (g a)

{-| This type represents monadic term algebras.  -}

type TermHomM m f g = SigFunM m f (Context g)

{-| This type represents monadic term algebras. It is similar to
'TermHomM' but has monadic values also in the domain. -}

type TermHomM' m f g = SigFunM' m f (Context g)


{-| This function lifts the given signature function to a monadic
signature function. Note that term algebras are instances of signature
functions. Hence this function also applies to term algebras. -}

sigFunM :: (Monad m) => SigFun f g -> SigFunM m f g
sigFunM f = return . f


{-| This function lifts the give monadic signature function to a
monadic term algebra. -}

termHom' :: (Functor f, Functor g, Monad m) => SigFunM m f g -> TermHomM m f g
termHom' f = liftM  (Term . fmap Hole) . f

{-| This function lifts the given signature function to a monadic term
algebra. -}

termHomM :: (Functor g, Monad m) => SigFun f g -> TermHomM m f g
termHomM f = sigFunM $ termHom f


{-| This function applies the given monadic term homomorphism to the
given term/context. -}
appTermHomM :: forall f g m . (Traversable f, Functor g, Monad m)
         => TermHomM m f g -> CxtFunM m f g
{-# NOINLINE [1] appTermHomM #-}
appTermHomM f = run
    where run :: Cxt h f a -> m (Cxt h g a)
          run (Hole b) = return $ Hole b
          run (Term t) = liftM appCxt . (>>= f) . mapM run $ t

{-| This function constructs the unique monadic homomorphism from the
initial term algebra to the given term algebra. -}

termHomM' :: forall f g m . (Traversable f, Functor g, Monad m)
          => TermHomM' m f g -> CxtFunM m f g
termHomM' f = run 
    where run :: Cxt h f a -> m (Cxt h g a)
          run (Hole b) = return $ Hole b
          run (Term t) = liftM appCxt . f . fmap run $ t


{-| This function applies the given monadic signature function to the
given context -}

appSigFunM :: (Traversable f, Functor g, Monad m) => SigFunM m f g -> CxtFunM m f g
appSigFunM f = appTermHomM $ termHom' $ f

{-| This function applies the given monadic signature function to the
given context -}

appSigFunM' :: forall f g m . (Traversable f, Functor g, Monad m)
              => SigFunM' m f g -> CxtFunM m f g
appSigFunM' f = run 
    where run :: Cxt h f a -> m (Cxt h g a)
          run (Hole b) = return $ Hole b
          run (Term t) = liftM Term . f . fmap run $ t

{-| This function composes two monadic term algebras. -}

compTermHomM :: (Traversable g, Functor h, Monad m)
            => TermHomM m g h -> TermHomM m f g -> TermHomM m f h
compTermHomM f g a = g a >>= appTermHomM f


{-| This function composes a monadic term algebra with a monadic algebra -}

compAlgM :: (Traversable g, Monad m) => AlgM m g a -> TermHomM m f g -> AlgM m f a
compAlgM alg talg c = cataM' alg =<< talg c

{-| This function composes a monadic term algebra with a monadic algebra -}

compAlgM' :: (Traversable g, Monad m) => AlgM m g a -> TermHom f g -> AlgM m f a
compAlgM' alg talg = cataM' alg . talg


{-| This function composes two monadic signature functions.  -}

compSigFunM :: (Monad m) => SigFunM m g h -> SigFunM m f g -> SigFunM m f h
compSigFunM f g a = g a >>= f

----------------
-- Coalgebras --
----------------

type Coalg f a = a -> f a

{-| This function unfolds the given value to a term using the given
unravelling function. This is the unique homomorphism @a -> Term f@
from the given coalgebra of type @a -> f a@ to the final coalgebra
@Term f@. -}

ana :: forall a f . Functor f
         => Coalg f a -> a -> Term f
ana f = run
    where run :: a -> Term f
          run t = Term $ fmap run (f t)

-- | Shortcut fusion variant of anamorphisms.

ana' :: forall a f . Functor f
         => Coalg f a -> a -> Term f
ana' f t = build $ run t
    where run :: forall b . a -> Alg f b -> b
          run t con = run' t where
              run' :: a ->  b
              run' t = con $ fmap run' (f t)

build :: (forall a. Alg f a -> a) -> Term f
{-# INLINE [1] build #-}
build g = g Term


{-| Anamorphism for exponential functors. -}
anaExp :: forall a f . ExpFunctor f => Coalg f a -> a -> Term (f :&: a)
anaExp f = run
    where run :: a -> Term (f :&: a)
          run t = Term $ (xmap run (snd . projectP . unTerm) (f t)) :&: t

type CoalgM m f a = a -> m (f a)

{-| This function unfolds the given value to a term using the given
monadic unravelling function. This is the unique homomorphism @a ->
Term f@ from the given coalgebra of type @a -> f a@ to the final
coalgebra @Term f@. -}

anaM :: forall a m f. (Traversable f, Monad m)
          => CoalgM m f a -> a -> m (Term f)
anaM f = run 
    where run :: a -> m (Term f)
          run t = liftM Term $ f t >>= mapM run


--------------------------------
-- R-Algebras & Paramorphisms --
--------------------------------

-- | This type represents r-algebras over functor @f@ and with domain
-- @a@.
type RAlg f a = f (Term f, a) -> a

-- | This function constructs a paramorphism from the given r-algebra
para :: (Functor f) => RAlg f a -> Term f -> a
para f = snd . cata run
    where run t = (Term $ fmap fst t, f t)

-- | This type represents monadic r-algebras over monad @m@ and
-- functor @f@ and with domain @a@.
type RAlgM m f a = f (Term f, a) -> m a

-- | This function constructs a monadic paramorphism from the given
-- monadic r-algebra
paraM :: (Traversable f, Monad m) => 
         RAlgM m f a -> Term f -> m a
paraM f = liftM snd . cataM run
    where run t = do
            a <- f t
            return (Term $ fmap fst t, a)

--------------------------------
-- R-Coalgebras & Apomorphisms --
--------------------------------

-- | This type represents r-coalgebras over functor @f@ and with
-- domain @a@.
type RCoalg f a = a -> f (Either (Term f) a)

-- | This function constructs an apomorphism from the given
-- r-coalgebra.
apo :: (Functor f) => RCoalg f a -> a -> Term f
apo f = run 
    where run = Term . fmap run' . f
          run' (Left t) = t
          run' (Right a) = run a
-- can also be defined in terms of anamorphisms (but less
-- efficiently):
-- apo f = ana run . Right
--     where run (Left (Term t)) = fmap Left t
--           run (Right a) = f a

-- | This type represents monadic r-coalgebras over monad @m@ and
-- functor @f@ with domain @a@.

type RCoalgM m f a = a -> m (f (Either (Term f) a))

-- | This function constructs a monadic apomorphism from the given
-- monadic r-coalgebra.
apoM :: (Traversable f, Monad m) =>
        RCoalgM m f a -> a -> m (Term f)
apoM f = run 
    where run a = do
            t <- f a
            t' <- mapM run' t
            return $ Term t'
          run' (Left t) = return t
          run' (Right a) = run a

-- can also be defined in terms of anamorphisms (but less
-- efficiently):
-- apoM f = anaM run . Right
--     where run (Left (Term t)) = return $ fmap Left t
--           run (Right a) = f a


----------------------------------
-- CV-Algebras & Histomorphisms --
----------------------------------

-- | This type represents cv-algebras over functor @f@ and with domain
-- @a@.

type CVAlg f a f' = f (Term f') -> a


-- | This function applies 'projectP' at the tip of the term.

projectTip  :: (DistProd f a f') => Term f' -> (f (Term f'), a)
projectTip (Term v) = projectP v

-- | This function constructs the unique histomorphism from the given
-- from the term algebra to the given cv-algebra.
histo :: (Functor f,DistProd f a f') => CVAlg f a f' -> Term f -> a
histo alg  = snd . projectTip . cata run
    where run v = Term $ injectP (alg v) v

-- | This type represents monadic cv-algebras over monad @m@ and
-- functor @f@, and with domain @a@.
type CVAlgM m f a f' = f (Term f') -> m a


-- | This function constructs the unique monadic histomorphism from
-- the given from the term algebra to the given monadic cv-algebra.
histoM :: (Traversable f, Monad m, DistProd f a f') =>
          CVAlgM m f a f' -> Term f -> m a
histoM alg  = liftM (snd . projectTip) . cataM run
    where run v = do r <- alg v
                     return $ Term $ injectP r v

-----------------------------------
-- CV-Coalgebras & Futumorphisms --
-----------------------------------


-- | This type represents cv-coalgebras over functor @f@ and with domain
-- @a@.

type CVCoalg f a = a -> f (Context f a)


-- | This function constructs the unique futumorphism from the given
-- cv-coalgebra to the term algebra.

futu :: forall f a . Functor f => CVCoalg f a -> a -> Term f
futu coa = ana run . Hole
    where run :: Coalg f (Context f a)
          run (Hole a) = coa a
          run (Term v) = v


-- | This type represents monadic cv-coalgebras over monad @m@ and
-- functor @f@, and with domain @a@.

type CVCoalgM m f a = a -> m (f (Context f a))

-- | This function constructs the unique monadic futumorphism from the
-- given monadic cv-coalgebra to the term algebra.
futuM :: forall f a m . (Traversable f, Monad m) =>
         CVCoalgM m f a -> a -> m (Term f)
futuM coa = anaM run . Hole
    where run :: CoalgM m f (Context f a)
          run (Hole a) = coa a
          run (Term v) = return v


--------------------------
-- Exponential Functors --
--------------------------

{-| Catamorphism for exponential functors. The intermediate 'cataFS' originates
 from @http://comonad.com/reader/2008/rotten-bananas/@. -}
cataE :: forall f a . ExpFunctor f => Alg f a -> Term f -> a
{-# NOINLINE [1] cataE #-}
cataE f = cataFS . toCxt
    where cataFS :: ExpFunctor f => (Context f a) -> a
          cataFS (Term x) = f (xmap cataFS Hole x)
          cataFS (Hole x) = x


-- | Variant of 'appCxt' for contexts over 'ExpFunctor' signatures.

appCxtE :: (ExpFunctor f) => Context f (Cxt h f a) -> Cxt h f a
appCxtE (Term x) = Term (xmap appCxtE Hole x)
appCxtE (Hole x) = x

-- | Variant of 'appTermHom' for term homomorphisms from and to
-- 'ExpFunctor' signatures.
appTermHomE :: forall f g . (ExpFunctor f, ExpFunctor g) => TermHom f g
            -> Term f -> Term g
appTermHomE f = cataFS . toCxt
    where cataFS :: Context f (Term g) -> Term g
          cataFS (Term x) = appCxtE $ f (xmap cataFS Hole x)
          cataFS (Hole x) = x


-------------------
-- rewrite rules --
-------------------

#ifndef NO_RULES
{-# RULES
  "cata/appTermHom" forall (a :: Alg g d) (h :: TermHom f g) x.
    cata a (appTermHom h x) = cata (compAlg a h) x;

  "appTermHom/appTermHom" forall (a :: TermHom g h) (h :: TermHom f g) x.
    appTermHom a (appTermHom h x) = appTermHom (compTermHom a h) x;

  "cataE/appTermHom" forall (a :: Alg g d) (h :: TermHom f g) (x :: ExpFunctor f => Term f) .
    cataE a (appTermHom h x) = cataE (compAlg a h) x
 #-}

{-# RULES 
  "cataM/appTermHomM" forall (a :: AlgM m g d) (h :: TermHomM m f g) x.
     appTermHomM h x >>= cataM a = cataM (compAlgM a h) x;

  "cataM/appTermHom" forall (a :: AlgM m g d) (h :: TermHom f g) x.
     cataM a (appTermHom h x) = cataM (compAlgM' a h) x;

  "appTermHomM/appTermHomM" forall (a :: TermHomM m g h) (h :: TermHomM m f g) x.
    appTermHomM h x >>= appTermHomM a = appTermHomM (compTermHomM a h) x;
 #-}

{-# RULES
  "cata/build"  forall alg (g :: forall a . Alg f a -> a) .
                cata alg (build g) = g alg
 #-}
#endif