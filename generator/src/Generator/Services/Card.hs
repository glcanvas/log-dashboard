module Generator.Services.Card
  ( CardAction (..)
  , MonadCard (..)
  , HasCard (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Card (MonadCardMap(..))
import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (dData, genCatalogAction, genCatalogList)
import Generator.Data.Card (CardActionType(..), caAction, carrepStatus)
import Generator.Data.Catalog (ProductId)
import Generator.Data.Common (Status(..), UserId(..))
import Generator.Kafka (MonadKafka(..))

data CardAction = CardActionE UserId ProductId | CardVisit UserId

class Monad m => MonadCard m where
  cardVisit :: UserId -> m ()
  cardActionE :: UserId -> ProductId -> m ()

class HasCard env where
  getCardQueue :: env -> TQueue CardAction

instance (MonadIO m, Monad m, MonadKafka m, MonadRequest m, MonadCardMap m) => MonadCard m where
  cardVisit userId = do
    request <- nextRequest
    userCard <- getUserCard userId
    (req, reqDb, rep) <- liftIO $ genCatalogList userId request userCard
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
  cardActionE userId productId = do
    request <- nextRequest
    (req, reqDb, rep) <- liftIO $ genCatalogAction userId request productId
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    case rep ^. dData . carrepStatus of
      Valid -> case req ^. dData . caAction of
        Add -> setToCard userId productId
        Remove -> removeFromCard userId productId
      _ -> pure ()
    logKafka $ decodeUtf8 $ encode rep
