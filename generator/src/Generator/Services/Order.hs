module Generator.Services.Order
  ( MonadOrder (..)
  , HasOrder (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Order (MonadOrderMap(..))
import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (dData, genOrder)
import Generator.Data.Common (OrderId, Status(..), UserId(..))
import Generator.Data.Order (OrderActionType, oadrepStatus, oarOrderId)
import Generator.Kafka (MonadKafka(..))

class Monad m => MonadOrder m where
  orderActionE :: UserId -> Maybe OrderId -> OrderActionType -> m OrderId

class HasOrder env where
  getOrderQueue :: env -> TQueue (UserId, Maybe OrderId, OrderActionType)

instance (MonadIO m, Monad m, MonadKafka m, MonadOrderMap m, MonadRequest m) => MonadOrder m where
  orderActionE userId mOrderId aType = do
    request <- nextRequest
    (req, reqDb, rep) <- liftIO $ genOrder userId request mOrderId aType
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    case rep ^. dData . oadrepStatus of
      Valid -> setOrder userId (req ^. dData . oarOrderId) aType
      _ -> pure ()
    logKafka $ decodeUtf8 $ encode rep
    pure $ req ^. dData . oarOrderId
