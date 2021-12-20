module Generator.Services.Payment
  ( MonadPayment (..)
  , HasPayment (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (genPayment)
import Generator.Data.Common (UserId(..))
import Generator.Kafka (MonadKafka(..))

class Monad m => MonadPayment m where
  paymentActionE :: UserId -> m ()

class HasPayment env where
  getPaymentQueue :: env -> TQueue UserId

instance (MonadIO m, Monad m, MonadKafka m, MonadRequest m) => MonadPayment m where
  paymentActionE userId = do
    request <- nextRequest
    (req, reqDb, rep) <- liftIO $ genPayment userId request
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
