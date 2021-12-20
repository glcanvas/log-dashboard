module Generator.Services.Payment
  ( MonadPayment (..)
  , HasPayment (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (dData, genPayment)
import Generator.Data.Common (OrderId, Status, UserId(..))
import Generator.Data.Payment (pcrepStatus)
import Generator.Kafka (MonadKafka(..))

class Monad m => MonadPayment m where
  paymentActionE :: UserId -> OrderId -> m Status

class HasPayment env where
  getPaymentQueue :: env -> TQueue (UserId, OrderId)

instance (MonadIO m, Monad m, MonadKafka m, MonadRequest m) => MonadPayment m where
  paymentActionE userId orderId = do
    request <- nextRequest
    (req, reqDb, rep) <- liftIO $ genPayment userId request orderId
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
    pure $ rep ^. dData . pcrepStatus
