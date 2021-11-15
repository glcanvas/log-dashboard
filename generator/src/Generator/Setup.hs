module Generator.Setup
  ( Generator
  , GeneratorWorkMode
  , runGenerator
  ) where

import Universum

import qualified StmContainers.Set as S

import Control.Concurrent.STM.TQueue (TQueue, newTQueueIO)
import Control.Lens (makeLenses)
import Control.Monad.IO.Unlift (MonadUnliftIO)
import RIO (RIO, runRIO)

import Generator.Services.Login (HasLogin(..), MonadLogin(..))
import Generator.Services.Catalog (HasCatalog(..), MonadCatalog(..), CatalogAction)
import Generator.Data.Common (UserId)

data GeneratorContext = GeneratorContext
  { _gcUsers :: S.Set UserId
  , _gcCatalogQueue :: TQueue CatalogAction
  , _gcLogoutQueue :: TQueue UserId
  }

makeLenses ''GeneratorContext

type Generator = RIO GeneratorContext

type GeneratorWorkMode m =
  ( Monad m
  , MonadIO m
  , MonadUnliftIO m
  , MonadThrow m
  , MonadCatch m
  , MonadMask m
  , MonadReader GeneratorContext m
  , HasLogin GeneratorContext
  , HasCatalog GeneratorContext
  , MonadLogin m
  , MonadCatalog m
  )

runGenerator :: Generator a -> IO a
runGenerator action = do
  q <- newTQueueIO
  q' <- newTQueueIO
  s <- S.newIO
  runRIO (GeneratorContext s q q') action

instance HasLogin GeneratorContext where
  getUsers = (^. gcUsers)
  getLogoutQueue = (^. gcLogoutQueue)

instance HasCatalog GeneratorContext where
  getCatalogQueue = (^. gcCatalogQueue)
