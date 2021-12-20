module Generator.Core.Card
  ( MonadCardMap (..)
  , HasCardMap (..)
  ) where

import Universum

import qualified Data.Map as MM
import qualified StmContainers.Map as M

import Data.Map (delete, insert, lookup)

import Generator.Data.Catalog (ProductId)
import Generator.Data.Common (UserId)

class Monad m => MonadCardMap m where
  setToCard :: UserId -> ProductId -> m ()
  removeFromCard :: UserId -> ProductId -> m ()
  getUserCard :: UserId -> m [(ProductId, Int)]

class HasCardMap env where
  getCard :: env -> M.Map UserId (Map ProductId Int)

instance (MonadIO m, Monad m, HasCardMap env, MonadReader env m) => MonadCardMap m where
  setToCard userId productId = do
    card <- getCard <$> ask
    atomically $ whenJustM (M.lookup userId card) $ \userCard -> do
      let mAmount = lookup productId userCard
      case mAmount of
        Nothing -> M.insert (insert productId 1 userCard) userId card
        Just amount -> M.insert (insert productId (amount + 1) userCard) userId card
  removeFromCard userId productId = do
    card <- getCard <$> ask
    atomically $ whenJustM (M.lookup userId card) $ \userCard -> do
      let mAmount = lookup productId userCard
      case mAmount of
        Nothing -> pure ()
        Just 1 -> M.insert (delete productId userCard) userId card
        Just amount -> M.insert (insert productId (amount - 1) userCard) userId card
  getUserCard userId = do
    card <- getCard <$> ask
    atomically $ do
      mUserCard <- M.lookup userId card
      case mUserCard of
        Just userCard -> pure $ MM.toList userCard
        _ -> pure []
