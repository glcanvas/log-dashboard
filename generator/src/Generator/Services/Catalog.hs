module Generator.Services.Catalog
  ( MonadCatalog (..)
  , HasCatalog (..)
  , CatalogAction (..)
  ) where

import Universum

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)
import Say (say)

import Generator.Data.Base (dData, genCatalogData, genProductDataC)
import Generator.Data.Catalog (pdrepStatus)
import Generator.Data.Common (Status(..), UserId(..))

data CatalogAction = CatalogVisit UserId | ProductVisit UserId

class Monad m => MonadCatalog m where
  catalogVisit :: UserId -> m ()
  productVisit :: UserId -> m ()

class HasCatalog env where
  getCatalogQueue :: env -> TQueue CatalogAction

instance (MonadIO m, Monad m) => MonadCatalog m where
  catalogVisit userId = do
    (req, reqDb, rep) <- liftIO $ genCatalogData userId
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    say $ decodeUtf8 $ encode rep
  productVisit userId = do
    (req, reqDb, rep, mReqL, mReqDbL) <- liftIO $ genProductDataC userId
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    case (rep ^. dData . pdrepStatus, mReqL, mReqDbL) of
      (Invalid, _, _) -> say $ decodeUtf8 $ encode rep
      (Valid, Just reqL, Just repL) -> do
        say $ decodeUtf8 $ encode rep
        say $ decodeUtf8 $ encode reqL
        say $ decodeUtf8 $ encode repL
      _ -> pure ()

