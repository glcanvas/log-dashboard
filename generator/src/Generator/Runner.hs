module Generator.Runner
 ( runner
 ) where

import Universum

import Generator.Setup (Generator, GeneratorWorkMode)
import Control.Concurrent (threadDelay)
import Generator.Services.Login (MonadLogin(..), HasLogin (..))
import Control.Concurrent.STM.TQueue (tryReadTQueue, writeTQueue)
import Control.Concurrent.Async (async, wait)
import Control.Monad.IO.Unlift (UnliftIO (..), askUnliftIO)
import System.Random (randomIO, randomRIO)
import Generator.Services.Page (HasPage (..), MonadPage (..))

loginAction :: GeneratorWorkMode m => m ()
loginAction = forever $ do
  liftIO $ threadDelay 1000000
  n <- login
  qp <- getPageQueue <$> ask
  atomically $ writeTQueue qp n
  

logoutAction :: GeneratorWorkMode m => m ()
logoutAction = forever $ do
  liftIO $ threadDelay 1000000
  q <- getLogoutQueue <$> ask
  mI <- atomically $ tryReadTQueue q
  case mI of
    Just i -> logout i
    _ -> pure ()

pageAction :: GeneratorWorkMode m => m ()
pageAction = forever $ do
  liftIO $ threadDelay 1000000
  nr <- liftIO $ randomRIO (1 :: Int, 10)
  qp <- getPageQueue <$> ask
  ql <- getLogoutQueue <$> ask
  mI <- atomically $ tryReadTQueue qp
  case mI of
    Just i -> do
      pageVisit i
      if nr == 1
      then atomically $ writeTQueue ql i
      else atomically $ writeTQueue qp i
    _ -> pure ()

runner :: GeneratorWorkMode m => m ()
runner = do
  UnliftIO unlift <- askUnliftIO
  a1 <- liftIO $ async $ unlift loginAction
  _ <- liftIO $ async $ unlift pageAction
  _ <- liftIO $ async $ unlift logoutAction
  liftIO $ wait a1



