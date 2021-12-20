module Generator.Services.Order
  ( MonadOrder (..)
  , HasOrder (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Data.Base (genOrder)
import Generator.Data.Common (UserId(..))
import Generator.Kafka (MonadKafka(..))

class Monad m => MonadOrder m where
  orderActionE :: UserId -> m ()

class HasOrder env where
  getOrderQueue :: env -> TQueue UserId

instance (MonadIO m, Monad m, MonadKafka m) => MonadOrder m where
  orderActionE userId = do
    (req, dReq, reqDb, rep) <- liftIO $ genOrder userId
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode dReq
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
