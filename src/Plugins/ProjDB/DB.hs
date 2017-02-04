{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
module Plugins.ProjDB.DB where

import qualified Data.Text as T
import Control.Monad.Reader
import Data.Maybe

import Data.Aeson
import qualified Data.HashMap.Lazy as HM

runReadDBT = runReaderT

class
		(HasKey val key) =>
		DB db key val | db val -> key, db key -> val
	where
		dbLookup :: db -> key -> Maybe val
		dbKeys :: db -> [key]

lookupDB ::
	(Monad m, DB db key val) =>
	key -> ReaderT db m (Maybe val)
lookupDB key = ask >>=
	return . flip dbLookup key

select ::
	forall m db val key .
	(Monad m, DB db key val) =>
	(val -> Bool)
	-> ReaderT db m [val]
select cond = ask >>= \db ->
	return $
	filter cond $
	mapMaybe (dbLookup db) $
	dbKeys db

class HasKey val key | val -> key where
	getKey :: val -> key

class FromKey a where
	fromKey :: a -> T.Text

class HasField cont field where
	getField :: FieldName -> cont -> Maybe field

contains :: ToJSON a => FieldName -> a -> T.Text -> Bool
contains field cont val =
	contains' $ Data.Aeson.toJSON cont
	where
		contains' :: Value -> Bool
		contains' (Object m) =
			fromMaybe False $
			HM.lookup (fromFieldName field) m >>= \case
				String s -> return $ (s == val)
				Array a ->
				{-
					return $
					val `Vec.elem` a
				-}
					return $
					or $
					fmap `flip` a $ \case
						String s -> s == val
						_ -> False
				_ -> Nothing
		contains' _ = False

getFieldVal :: ToJSON a => FieldName -> a -> Maybe T.Text
getFieldVal field cont =
	getFieldVal' $ Data.Aeson.toJSON cont
	where
		getFieldVal' :: Value -> Maybe T.Text
		getFieldVal' (Object m) =
			HM.lookup (fromFieldName field) m >>= \case
				String s -> Just s
				_ -> Nothing
		getFieldVal' _ = Nothing

newtype FieldName = FieldName { fromFieldName :: T.Text }
	deriving( Eq, Ord, Show, Read)

{-
class CanContain a b where
	contains :: a -> b -> Bool

instance (Eq a) => CanContain a a where
	contains = (==)

instance (Eq a) => CanContain [a] a where
	contains l x = x `elem` l
-}