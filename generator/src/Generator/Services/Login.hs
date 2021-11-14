module Generator.Services.Login
  ( MonadLogin (..)
  , HasLogin (..)
  ) where

import Universum

import qualified StmContainers.Set as S

import System.Random (randomRIO)
import Control.Concurrent.STM.TQueue (TQueue)
import Say (say)

class Monad m => MonadLogin m where
  login :: m Int
  logout :: Int -> m ()

class HasLogin env where
  getUsers :: env -> S.Set Int
  getLogoutQueue :: env -> TQueue Int

instance (MonadIO m, Monad m, HasLogin env, MonadReader env m) => MonadLogin m where
  login = do
    n <- randomRIO (1, 1000000)
    users <- getUsers <$> ask
    atomically $ S.insert n users
    say $ "Login " <> show n
    pure n
  logout n = do
    users <- getUsers <$> ask
    atomically $ S.delete n users
    say $ "Logout " <> show n
