{-# LANGUAGE GADTs, ExistentialQuantification, TypeOperators, ScopedTypeVariables, RankNTypes #-}

--------------------------------------------------------------------------------
-- |
-- Module      :  Data.ALaCarte.Generic
-- Copyright   :  3gERP, 2011
-- License     :  AllRightsReserved
-- Maintainer  :  Patrick Bahr, Tom Hvitved
-- Stability   :  unknown
-- Portability :  unknown
--
-- This module defines type generic functions and recursive schemes
-- along the lines of the Uniplate library.
--
--------------------------------------------------------------------------------

module Data.ALaCarte.Multi.Generic where

import Data.ALaCarte.Multi.Term
import Data.ALaCarte.Multi.Sum
import Data.ALaCarte.Multi.HFunctor
import GHC.Exts
import Control.Monad
import Prelude

-- | This function returns a list of all subterms of the given
-- term. This function is similar to Uniplate's @universe@ function.
subterms :: forall f  . HFoldable f => Term f  :=> [A (Term f)]
subterms t = build (f t)
    where f :: Term f :=> (A (Term f) -> b -> b) -> b -> b
          f t cons nil = A t `cons` hfoldl (\u s -> f s cons u) nil (unTerm t)

-- | This function returns a list of all subterms of the given term
-- that are constructed from a particular functor.
subterms' :: forall f g . (HFoldable f, g :<<: f) => Term f :=> [A (g (Term f))]
subterms' (Term t) = build (f t)
    where f :: f (Term f) :=> (A (g (Term f)) -> b -> b) -> b -> b
          f t cons nil = let rest = hfoldl (\u (Term s) -> f s cons u) nil t
                         in case hproj t of
                              Just t' -> A t' `cons` rest
                              Nothing -> rest

-- | This function transforms every subterm according to the given
-- function in a bottom-up manner. This function is similar to
-- Uniplate's @transform@ function.
transform :: forall f . (HFunctor f) => (Term f :-> Term f) -> Term f :-> Term f
transform f = run
    where run :: Term f :-> Term f
          run = f . Term . hfmap run . unTerm


-- | Monadic version of 'transform'.
transformM :: forall f m . (HTraversable f, Monad m) =>
             (NatM m (Term f) (Term f)) -> NatM m (Term f) (Term f)
transformM  f = run 
    where run :: NatM m (Term f) (Term f)
          run t = f =<< (liftM Term $ hmapM run $ unTerm t)

-- | This function computes the generic size of the given term,
-- i.e. the its number of subterm occurrences.
size :: HFoldable f => Cxt h f a :=> Int
size (Hole {}) = 0
size (Term t) = hfoldl (\s x -> s + size x) 1 t

-- | This function computes the generic depth of the given term.
depth :: HFoldable f => Cxt h f a :=> Int
depth (Hole {}) = 0
depth (Term t) = 1 + hfoldl (\s x -> s + size x) 0 t