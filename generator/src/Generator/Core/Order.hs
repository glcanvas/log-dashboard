module Generator.Core.Order
  ( HasOrderMap (..)
  , MonadOrderMap (..)
  ) where

import Universum

import qualified StmContainers.Map as M

import Data.Map (insert)

import Generator.Core.Card (HasCardMap(..))
import Generator.Data.Common (OrderId, UserId)
import Generator.Data.Order (OrderActionType(..))

class Monad m => MonadOrderMap m where
  setOrder :: UserId -> OrderId -> OrderActionType -> m ()

class HasOrderMap env where
  getOrderMap :: env -> M.Map UserId (Map OrderId OrderActionType)

instance (MonadIO m, Monad m, HasCardMap env, HasOrderMap env, MonadReader env m) => MonadOrderMap m where
  setOrder userId orderId aType = do
    order <- getOrderMap <$> ask
    card <- getCard <$> ask
    atomically $ whenJustM (M.lookup userId order) $ \userOrder -> do
      M.insert (insert orderId aType userOrder) userId order
      case aType of
        Reserve -> M.delete userId card
        _ -> pure ()

