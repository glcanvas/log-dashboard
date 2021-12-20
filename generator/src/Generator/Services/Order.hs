module Generator.Services.Order
  ( MonadOrder (..)
  , HasOrder (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (genOrder)
import Generator.Data.Common (UserId(..))
import Generator.Kafka (MonadKafka(..))

class Monad m => MonadOrder m where
  orderActionE :: UserId -> m ()

class HasOrder env where
  getOrderQueue :: env -> TQueue UserId

instance (MonadIO m, Monad m, MonadKafka m, MonadRequest m) => MonadOrder m where
  orderActionE userId = do
    request <- nextRequest
    (req, dReq, reqDb, rep) <- liftIO $ genOrder userId request
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode dReq
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
