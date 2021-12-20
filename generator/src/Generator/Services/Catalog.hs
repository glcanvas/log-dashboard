module Generator.Services.Catalog
  ( MonadCatalog (..)
  , HasCatalog (..)
  , CatalogAction (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)

import Generator.Core.Requests (MonadRequest(..))
import Generator.Data.Base (dData, genCatalogData, genProductDataC)
import Generator.Data.Catalog (ProductId, pdrepStatus, prProductId)
import Generator.Data.Common (Status(..), UserId(..))
import Generator.Kafka (MonadKafka(..))

data CatalogAction = CatalogVisit UserId | ProductVisit UserId

class Monad m => MonadCatalog m where
  catalogVisit :: UserId -> m ()
  productVisit :: UserId -> m (Maybe ProductId)

class HasCatalog env where
  getCatalogQueue :: env -> TQueue CatalogAction

instance (MonadIO m, Monad m, MonadKafka m, MonadRequest m) => MonadCatalog m where
  catalogVisit userId = do
    request <- nextRequest
    (req, reqDb, rep) <- liftIO $ genCatalogData userId request
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    logKafka $ decodeUtf8 $ encode rep
  productVisit userId = do
    request <- nextRequest
    (req, reqDb, rep, mReqL, mReqDbL) <- liftIO $ genProductDataC userId request
    logKafka $ decodeUtf8 $ encode req
    logKafka $ decodeUtf8 $ encode reqDb
    case (rep ^. dData . pdrepStatus, mReqL, mReqDbL) of
      (Invalid, _, _) -> do
        logKafka $ decodeUtf8 $ encode rep
        pure Nothing
      (Valid, Just reqL, Just repL) -> do
        logKafka $ decodeUtf8 $ encode rep
        logKafka $ decodeUtf8 $ encode reqL
        logKafka $ decodeUtf8 $ encode repL
        pure $ Just $ req ^. dData . prProductId
      _ -> pure Nothing

