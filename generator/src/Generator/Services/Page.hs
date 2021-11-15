module Generator.Services.Page
  ( MonadPage (..)
  , HasPage (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Say (say)

class Monad m => MonadPage m where
  pageVisit :: Int -> m ()

class HasPage env where
  getPageQueue :: env -> TQueue Int

instance (MonadIO m, Monad m) => MonadPage m where
  pageVisit n = do
    say $ "Page " <> show n
