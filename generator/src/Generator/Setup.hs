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
import Generator.Services.Page (HasPage(..), MonadPage(..))

data GeneratorContext = GeneratorContext
  { _gcUsers :: S.Set Int
  , _gcPageQueue :: TQueue Int
  , _gcLogoutQueue :: TQueue Int
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
  , HasPage GeneratorContext
  , MonadLogin m
  , MonadPage m
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

instance HasPage GeneratorContext where
  getPageQueue = (^. gcPageQueue)
