module Generator.Core.Requests
  ( HasRequest (..)
  , MonadRequest (..)
  ) where

import Generator.Data.Common (RequestId)
import Universum

class Monad m => MonadRequest m where
  nextRequest :: m RequestId

class HasRequest env where
  getCurRequest :: env -> TVar RequestId

instance (MonadIO m, Monad m, HasRequest env, MonadReader env m) => MonadRequest m where
  nextRequest = do
    tRequest <- getCurRequest <$> ask
    atomically $ do
      r <- readTVar tRequest
      writeTVar tRequest $ r + 1
      pure r
