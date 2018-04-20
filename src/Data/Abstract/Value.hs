{-# LANGUAGE DataKinds, TypeFamilies, TypeOperators, UndecidableInstances, ScopedTypeVariables #-}
module Data.Abstract.Value where

import Control.Abstract.Analysis
import Data.Abstract.Environment (Environment)
import qualified Data.Abstract.Environment as Env
import Data.Abstract.Evaluatable
import qualified Data.Abstract.Number as Number
import Data.Scientific (Scientific)
import qualified Data.Set as Set
import Prologue hiding (TypeError)
import Prelude hiding (Float, Integer, String, Rational)
import qualified Prelude

type ValueConstructors location
  = '[Array
    , Boolean
    , Class location
    , Closure location
    , Float
    , Hash
    , Integer
    , KVPair
    , Namespace location
    , Null
    , Rational
    , String
    , Symbol
    , Tuple
    , Unit
    , Hole
    ]

-- | Open union of primitive values that terms can be evaluated to.
--   Fix by another name.
newtype Value location = Value { deValue :: Union (ValueConstructors location) (Value location) }
  deriving (Eq, Show, Ord)

-- | Identical to 'inj', but wraps the resulting sub-entity in a 'Value'.
injValue :: (f :< ValueConstructors location) => f (Value location) -> Value location
injValue = Value . inj

-- | Identical to 'prj', but unwraps the argument out of its 'Value' wrapper.
prjValue :: (f :< ValueConstructors location) => Value location -> Maybe (f (Value location))
prjValue = prj . deValue

-- | Convenience function for projecting two values.
prjPair :: (f :< ValueConstructors location , g :< ValueConstructors location)
        => (Value location, Value location)
        -> Maybe (f (Value location), g (Value location))
prjPair = bitraverse prjValue prjValue

-- TODO: Parameterize Value by the set of constructors s.t. each language can have a distinct value union.

-- | A function value consisting of a list of parameter 'Name's, a 'Label' to jump to the body of the function, and an 'Environment' of bindings captured by the body.
data Closure location value = Closure [Name] Label (Environment location value)
  deriving (Eq, Generic1, Ord, Show)

instance Eq location => Eq1 (Closure location) where liftEq = genericLiftEq
instance Ord location => Ord1 (Closure location) where liftCompare = genericLiftCompare
instance Show location => Show1 (Closure location) where liftShowsPrec = genericLiftShowsPrec

-- | The unit value. Typically used to represent the result of imperative statements.
data Unit value = Unit
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Unit where liftEq = genericLiftEq
instance Ord1 Unit where liftCompare = genericLiftCompare
instance Show1 Unit where liftShowsPrec = genericLiftShowsPrec

data Hole value = Hole
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Hole where liftEq = genericLiftEq
instance Ord1 Hole where liftCompare = genericLiftCompare
instance Show1 Hole where liftShowsPrec = genericLiftShowsPrec

-- | Boolean values.
newtype Boolean value = Boolean Prelude.Bool
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Boolean where liftEq = genericLiftEq
instance Ord1 Boolean where liftCompare = genericLiftCompare
instance Show1 Boolean where liftShowsPrec = genericLiftShowsPrec

-- | Arbitrary-width integral values.
newtype Integer value = Integer (Number.Number Prelude.Integer)
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Integer where liftEq = genericLiftEq
instance Ord1 Integer where liftCompare = genericLiftCompare
instance Show1 Integer where liftShowsPrec = genericLiftShowsPrec

-- | Arbitrary-width rational values values.
newtype Rational value = Rational (Number.Number Prelude.Rational)
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Rational where liftEq = genericLiftEq
instance Ord1 Rational where liftCompare = genericLiftCompare
instance Show1 Rational where liftShowsPrec = genericLiftShowsPrec

-- | String values.
newtype String value = String ByteString
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 String where liftEq = genericLiftEq
instance Ord1 String where liftCompare = genericLiftCompare
instance Show1 String where liftShowsPrec = genericLiftShowsPrec

-- | Possibly-interned Symbol values.
--   TODO: Should this store a 'Text'?
newtype Symbol value = Symbol ByteString
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Symbol where liftEq = genericLiftEq
instance Ord1 Symbol where liftCompare = genericLiftCompare
instance Show1 Symbol where liftShowsPrec = genericLiftShowsPrec

-- | Float values.
newtype Float value = Float (Number.Number Scientific)
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Float where liftEq = genericLiftEq
instance Ord1 Float where liftCompare = genericLiftCompare
instance Show1 Float where liftShowsPrec = genericLiftShowsPrec

-- | Zero or more values. Fixed-size at interpretation time.
--   TODO: Investigate whether we should use Vector for this.
--   TODO: Should we have a Some type over a nonemmpty list? Or does this merit one?
newtype Tuple value = Tuple [value]
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Tuple where liftEq = genericLiftEq
instance Ord1 Tuple where liftCompare = genericLiftCompare
instance Show1 Tuple where liftShowsPrec = genericLiftShowsPrec

-- | Zero or more values. Dynamically resized as needed at interpretation time.
--   TODO: Vector? Seq?
newtype Array value = Array [value]
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Array where liftEq = genericLiftEq
instance Ord1 Array where liftCompare = genericLiftCompare
instance Show1 Array where liftShowsPrec = genericLiftShowsPrec

-- | Class values. There will someday be a difference between classes and objects,
--   but for the time being we're pretending all languages have prototypical inheritance.
data Class location value = Class
  { _className  :: Name
  , _classScope :: Environment location value
  } deriving (Eq, Generic1, Ord, Show)

instance Eq location => Eq1 (Class location) where liftEq = genericLiftEq
instance Ord location => Ord1 (Class location) where liftCompare = genericLiftCompare
instance Show location => Show1 (Class location) where liftShowsPrec = genericLiftShowsPrec

data Namespace location value = Namespace
  { namespaceName  :: Name
  , namespaceScope :: Environment location value
  } deriving (Eq, Generic1, Ord, Show)

instance Eq location => Eq1 (Namespace location) where liftEq = genericLiftEq
instance Ord location => Ord1 (Namespace location) where liftCompare = genericLiftCompare
instance Show location => Show1 (Namespace location) where liftShowsPrec = genericLiftShowsPrec

data KVPair value = KVPair value value
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 KVPair where liftEq = genericLiftEq
instance Ord1 KVPair where liftCompare = genericLiftCompare
instance Show1 KVPair where liftShowsPrec = genericLiftShowsPrec

-- You would think this would be a @Map value value@ or a @[(value, value)].
-- You would be incorrect, as we can't derive a Generic1 instance for the above,
-- and in addition a 'Map' representation would lose information given hash literals
-- that assigned multiple values to one given key. Instead, this holds KVPair
-- values. The smart constructor for hashes in MonadValue ensures that these are
-- only populated with pairs.
newtype Hash value = Hash [value]
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Hash where liftEq = genericLiftEq
instance Ord1 Hash where liftCompare = genericLiftCompare
instance Show1 Hash where liftShowsPrec = genericLiftShowsPrec

data Null value = Null
  deriving (Eq, Generic1, Ord, Show)

instance Eq1 Null where liftEq = genericLiftEq
instance Ord1 Null where liftCompare = genericLiftCompare
instance Show1 Null where liftShowsPrec = genericLiftShowsPrec


instance Ord location => ValueRoots location (Value location) where
  valueRoots v
    | Just (Closure _ _ env) <- prjValue v = Env.addresses env
    | otherwise                            = mempty


-- | Construct a 'Value' wrapping the value arguments (if any).
instance forall location term m. (Monad m, MonadEvaluatable location term (Value location) m) => MonadValue location (Value location) m where
  hole     = pure . injValue $ Hole
  unit     = pure . injValue $ Unit
  integer  = pure . injValue . Integer . Number.Integer
  boolean  = pure . injValue . Boolean
  string   = pure . injValue . String
  float    = pure . injValue . Float . Number.Decimal
  symbol   = pure . injValue . Symbol
  rational = pure . injValue . Rational . Number.Ratio

  multiple = pure . injValue . Tuple
  array    = pure . injValue . Array

  kvPair k = pure . injValue . KVPair k

  null     = pure . injValue $ Null

  asPair val
    | Just (KVPair k v) <- prjValue val = pure (k, v)
    | otherwise = throwResumable @(ValueError location (Value location)) $ KeyValueError val

  hash = pure . injValue . Hash . fmap (injValue . uncurry KVPair)

  klass n [] env = pure . injValue $ Class n env
  klass n supers env = do
    product <- mconcat <$> traverse scopedEnvironment supers
    pure . injValue $ Class n (Env.push product <> env)

  namespace n env = do
    maybeAddr <- lookupEnv n
    env' <- maybe (pure mempty) (asNamespaceEnv <=< deref) maybeAddr
    pure (injValue (Namespace n (Env.mergeNewer env' env)))
    where asNamespaceEnv v
            | Just (Namespace _ env') <- prjValue v = pure env'
            | otherwise                             = throwResumable $ NamespaceError ("expected " <> show v <> " to be a namespace")

  scopedEnvironment o
    | Just (Class _ env) <- prjValue o = pure env
    | Just (Namespace _ env) <- prjValue o = pure env
    | otherwise = throwResumable $ ScopedEnvironmentError ("object type passed to scopedEnvironment doesn't have an environment: " <> show o)

  asString v
    | Just (String n) <- prjValue v = pure n
    | otherwise                     = throwResumable @(ValueError location (Value location)) $ StringError v

  ifthenelse cond if' else' = do
    isHole <- isHole cond
    if isHole then
      hole
    else do
      bool <- asBool cond
      if bool then if' else else'

  asBool val
    | Just (Boolean b) <- prjValue val = pure b
    | otherwise = throwResumable @(ValueError location (Value location)) $ BoolError val

  isHole val = pure (prjValue val == Just Hole)


  liftNumeric f arg
    | Just (Integer (Number.Integer i)) <- prjValue arg = integer $ f i
    | Just (Float (Number.Decimal d))   <- prjValue arg = float   $ f d
    | Just (Rational (Number.Ratio r))  <- prjValue arg = rational $ f r
    | otherwise = throwValueError (NumericError arg)

  liftNumeric2 f left right
    | Just (Integer  i, Integer j)  <- prjPair pair = f i j & specialize
    | Just (Integer  i, Rational j) <- prjPair pair = f i j & specialize
    | Just (Integer  i, Float j)    <- prjPair pair = f i j & specialize
    | Just (Rational i, Integer j)  <- prjPair pair = f i j & specialize
    | Just (Rational i, Rational j) <- prjPair pair = f i j & specialize
    | Just (Rational i, Float j)    <- prjPair pair = f i j & specialize
    | Just (Float    i, Integer j)  <- prjPair pair = f i j & specialize
    | Just (Float    i, Rational j) <- prjPair pair = f i j & specialize
    | Just (Float    i, Float j)    <- prjPair pair = f i j & specialize
    | otherwise = throwValueError (Numeric2Error left right)
      where
        -- Dispatch whatever's contained inside a 'Number.SomeNumber' to its appropriate 'MonadValue' ctor
        specialize :: MonadValue location value m => Number.SomeNumber -> m value
        specialize (Number.SomeNumber (Number.Integer i)) = integer i
        specialize (Number.SomeNumber (Number.Ratio r))          = rational r
        specialize (Number.SomeNumber (Number.Decimal d))        = float d
        pair = (left, right)

  liftComparison comparator left right
    | Just (Integer (Number.Integer i), Integer (Number.Integer j)) <- prjPair pair = go i j
    | Just (Integer (Number.Integer i), Float   (Number.Decimal j)) <- prjPair pair = go (fromIntegral i) j
    | Just (Float   (Number.Decimal i), Integer (Number.Integer j)) <- prjPair pair = go i                (fromIntegral j)
    | Just (Float   (Number.Decimal i), Float   (Number.Decimal j)) <- prjPair pair = go i j
    | Just (String  i,                  String  j)                  <- prjPair pair = go i j
    | Just (Boolean i,                  Boolean j)                  <- prjPair pair = go i j
    | Just (Unit,                       Unit)                       <- prjPair pair = boolean True
    | otherwise = throwValueError (ComparisonError left right)
      where
        -- Explicit type signature is necessary here because we're passing all sorts of things
        -- to these comparison functions.
        go :: (Ord a, MonadValue location value m) => a -> a -> m value
        go l r = case comparator of
          Concrete f  -> boolean (f l r)
          Generalized -> integer (orderingToInt (compare l r))

        -- Map from [LT, EQ, GT] to [-1, 0, 1]
        orderingToInt :: Ordering -> Prelude.Integer
        orderingToInt = toInteger . pred . fromEnum

        pair = (left, right)


  liftBitwise operator target
    | Just (Integer (Number.Integer i)) <- prjValue target = integer $ operator i
    | otherwise = throwValueError (BitwiseError target)

  liftBitwise2 operator left right
    | Just (Integer (Number.Integer i), Integer (Number.Integer j)) <- prjPair pair = integer $ operator i j
    | otherwise = throwValueError (Bitwise2Error left right)
      where pair = (left, right)

  lambda names (Subterm body _) = do
    l <- label body
    injValue . Closure names l . Env.bind (foldr Set.delete (Set.fromList (freeVariables body)) names) <$> getEnv

  call op params = do
    case prjValue op of
      Just (Closure names label env) -> do
        bindings <- foldr (\ (name, param) rest -> do
          v <- param
          a <- alloc name
          assign a v
          Env.insert name a <$> rest) (pure env) (zip names params)
        localEnv (mappend bindings) (evalClosure label)
      Nothing -> throwValueError (CallError op)
    where
      evalClosure :: Label -> m (Value location)
      evalClosure lab = catchResumable (goto lab >>= evaluateTerm) handleReturn

      handleReturn :: ControlThrow (Value location) r -> m (Value location)
      handleReturn (Ret v) = pure v

  loop = fix
