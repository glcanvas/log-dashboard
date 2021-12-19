module Generator.Runner
 ( runner
 ) where

import Universum

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (async, wait)
import Control.Concurrent.STM.TQueue (tryReadTQueue, writeTQueue)
import Control.Monad.IO.Unlift (UnliftIO(..), askUnliftIO)
import System.Random (randomRIO)

import Generator.Services.Card (CardAction(..), HasCard(..), MonadCard(..))
import Generator.Services.Catalog (CatalogAction(..), HasCatalog(..), MonadCatalog(..))
import Generator.Services.Login (HasLogin(..), MonadLogin(..))
import Generator.Services.Order (HasOrder(..), MonadOrder(..))
import Generator.Services.Payment (HasPayment(..), MonadPayment(..))
import Generator.Setup (GeneratorWorkMode)

loginAction :: GeneratorWorkMode m => m ()
loginAction = forever $ do
  liftIO $ threadDelay 1000000
  mUserId <- login
  case mUserId of
    Just userId -> do
      catalogQueue <- getCatalogQueue <$> ask
      atomically $ writeTQueue catalogQueue $ CatalogVisit userId
    _ -> pure ()

logoutAction :: GeneratorWorkMode m => m ()
logoutAction = forever $ do
  liftIO $ threadDelay 1000000
  logoutQueue <- getLogoutQueue <$> ask
  mUserId <- atomically $ tryReadTQueue logoutQueue
  case mUserId of
    Just userId -> logout userId
    _ -> pure ()

pageAction :: GeneratorWorkMode m => m ()
pageAction = forever $ do
  liftIO $ threadDelay 1000000
  rn <- liftIO $ randomRIO (1 :: Int, 10)
  catalogQueue <- getCatalogQueue <$> ask
  logoutQueue <- getLogoutQueue <$> ask
  cardQueue <- getCardQueue <$> ask
  mAction <- atomically $ tryReadTQueue catalogQueue
  case mAction of
    Just (CatalogVisit userId) -> do
      catalogVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
        then atomically $ writeTQueue catalogQueue $ ProductVisit userId
        else atomically $ writeTQueue cardQueue $ CardVisit userId
    Just (ProductVisit userId) -> do
      productVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
           then atomically $ writeTQueue catalogQueue $ CatalogVisit userId
           else if rn < 5
             then atomically $ writeTQueue catalogQueue $ ProductVisit userId
             else if rn < 9
               then atomically $ writeTQueue cardQueue $ CardVisit userId
               else atomically $ writeTQueue cardQueue $ CardActionE userId
    _ -> pure ()

cardAction :: GeneratorWorkMode m => m ()
cardAction = forever $ do
  liftIO $ threadDelay 1000000
  rn <- liftIO $ randomRIO (1 :: Int, 10)
  catalogQueue <- getCatalogQueue <$> ask
  logoutQueue <- getLogoutQueue <$> ask
  orderQueue <- getOrderQueue <$> ask
  cardQueue <- getCardQueue <$> ask
  mAction <- atomically $ tryReadTQueue cardQueue
  case mAction of
    Just (CardActionE userId) -> do
      cardActionE userId
      pure ()
    Just (CardVisit userId) -> do
      cardVisit userId
      if rn == 1
      then atomically $ writeTQueue logoutQueue userId
      else if rn < 4
           then atomically $ writeTQueue catalogQueue $ CatalogVisit userId
           else if rn < 8
             then atomically $ writeTQueue orderQueue userId
             else atomically $ writeTQueue catalogQueue $ ProductVisit userId
    _ -> pure ()

orderAction :: GeneratorWorkMode m => m ()
orderAction = forever $ do
  liftIO $ threadDelay 1000000
  orderQueue <- getOrderQueue <$> ask
  paymentQueue <- getPaymentQueue <$> ask
  mAction <- atomically $ tryReadTQueue orderQueue
  case mAction of
    Just userId -> do
      orderActionE userId
      atomically $ writeTQueue paymentQueue userId
    _ -> pure ()

paymentAction :: GeneratorWorkMode m => m ()
paymentAction = forever $ do
  liftIO $ threadDelay 1000000
  paymentQueue <- getPaymentQueue <$> ask
  catalogQueue <- getCatalogQueue <$> ask
  mAction <- atomically $ tryReadTQueue paymentQueue
  case mAction of
    Just userId -> do
      paymentActionE userId
      atomically $ writeTQueue catalogQueue $ CatalogVisit userId
    _ -> pure ()

runner :: GeneratorWorkMode m => m ()
runner = do
  UnliftIO unlift <- askUnliftIO
  a <- liftIO $ async $ unlift loginAction
  _ <- liftIO $ async $ unlift orderAction
  _ <- liftIO $ async $ unlift paymentAction
  _ <- liftIO $ async $ unlift pageAction
  _ <- liftIO $ async $ unlift logoutAction
  _ <- liftIO $ async $ unlift cardAction
  liftIO $ wait a
