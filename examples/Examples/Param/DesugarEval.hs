{-# LANGUAGE TemplateHaskell, TypeOperators, MultiParamTypeClasses,
  FlexibleInstances, FlexibleContexts, UndecidableInstances,
  TypeSynonymInstances, OverlappingInstances, Rank2Types #-}
--------------------------------------------------------------------------------
-- |
-- Module      :  Examples.Param.DesugarEval
-- Copyright   :  (c) 2011 Patrick Bahr, Tom Hvitved
-- License     :  BSD3
-- Maintainer  :  Tom Hvitved <hvitved@diku.dk>
-- Stability   :  experimental
-- Portability :  non-portable (GHC Extensions)
--
-- Desugaring + Expression Evaluation
--
-- The example illustrates how to compose a term homomorphism and an algebra,
-- exemplified via a desugaring term homomorphism and an evaluation algebra.
--
-- The example extends the example from 'Examples.Param.Eval'.
--
--------------------------------------------------------------------------------

module Examples.Param.DesugarEval where

import Data.Comp.Param
import Data.Comp.Param.Show ()
import Data.Comp.Param.Derive
import Data.Comp.Param.Desugar

-- Signatures for values and operators
data Const a e      = Const Int
data Lam a e        = Lam (a -> e) -- Note: not e -> e
data App a e        = App e e
data Op a e         = Add e e | Mult e e
data Fun a e        = Fun (e -> e) -- Note: not a -> e
data IfThenElse a e = IfThenElse e e e

-- Signature for syntactic sugar (negation, let expressions, Y combinator)
data Sug a e = Neg e | Let e (a -> e) | Fix

-- Signature for the simple expression language
type Sig = Const :+: Lam :+: App :+: Op :+: IfThenElse
-- Signature for the simple expression language with syntactic sugar
type Sig' = Sug :+: Sig
-- Signature for values. Note the use of 'Fun' rather than 'Lam' (!)
type Value = Const :+: Fun
-- Signature for ground values.
type GValue = Const

-- Derive boilerplate code using Template Haskell
$(derive [makeDifunctor, makeDitraversable, makeEqD, makeOrdD, makeShowD,
          smartConstructors] [''Const, ''Lam, ''App, ''Op, ''IfThenElse, ''Sug])

instance (Op :<: f, Const :<: f, Lam :<: f, App :<: f, Difunctor f)
  => Desugar Sug f where
  desugHom' (Neg x)   = iConst (-1) `iMult` x
  desugHom' (Let x y) = inject (Lam y) `iApp` x
  desugHom' Fix       = iLam $ \f -> iLam (\x -> f `iApp` (x `iApp` x)) `iApp`
                                     iLam (\x -> f `iApp` (x `iApp` x))

-- Term evaluation algebra
class Eval f v where
  evalAlg :: Alg f (Trm v a)

$(derive [liftSum] [''Eval])

-- Compose the evaluation algebra and the desugaring homomorphism to an algebra
eval :: Term Sig -> Term Value
eval t = Term (cata evalAlg t)

evalDesug :: Term Sig' -> Term Value
evalDesug t = eval (desugar t)

instance (Const :<: v) => Eval Const v where
  evalAlg (Const n) = iConst n

instance (Const :<: v) => Eval Op v where
  evalAlg (Add x y)  = iConst $ projC x + projC y
  evalAlg (Mult x y) = iConst $ projC x * projC y

instance (Fun :<: v) => Eval App v where
  evalAlg (App x y) = projF x y

instance (Fun :<: v) => Eval Lam v where
  evalAlg (Lam f) = inject $ Fun f

instance (Const :<: v) => Eval IfThenElse v where
  evalAlg (IfThenElse c v1 v2) = if projC c /= 0 then v1 else v2

projC :: (Const :<: v) => Trm v a -> Int
projC v = case project v of Just (Const n) -> n

projF :: (Fun :<: v) => Trm v a -> Trm v a -> Trm v a
projF v = case project v of Just (Fun f) -> f

-- |Evaluation of expressions to ground values.
evalG :: Term Sig' -> Maybe (Term GValue)
evalG = deepProject . evalDesug

-- Example: evalEx = Just (iConst 720)
evalEx :: Maybe (Term GValue)
evalEx = evalG $ Term $ fact `iApp` iConst 6

fact :: Trm Sig' a
fact = iFix `iApp`
       iLam (\f ->
          iLam $ \n ->
              iIfThenElse n  (n `iMult` (f `iApp` (n `iAdd` iConst (-1)))) (iConst 1))