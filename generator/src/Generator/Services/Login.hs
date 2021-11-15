module Generator.Services.Login
  ( MonadLogin (..)
  , HasLogin (..)
  ) where

import Universum

import qualified StmContainers.Set as S

import Control.Concurrent.STM.TQueue (TQueue)
import Data.Aeson (encode)
import Say (say)

import Generator.Data.Base (cdUserId, dCommonData, dData, genLoginData, genLogoutData)
import Generator.Data.Common (Status(..), UserId(..))
import Generator.Data.Login (lorepStatus, lrepStatus)

class Monad m => MonadLogin m where
  login :: m (Maybe UserId)
  logout :: UserId -> m ()

class HasLogin env where
  getUsers :: env -> S.Set UserId
  getLogoutQueue :: env -> TQueue UserId

instance (MonadIO m, Monad m, HasLogin env, MonadReader env m) => MonadLogin m where
  login = do
    (req, reqDb, rep) <- liftIO genLoginData
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    let userId = req ^. dCommonData . cdUserId
    case rep ^. dData . lrepStatus of
      Invalid -> (say $ decodeUtf8 $ encode rep) >> pure Nothing
      _ -> do
        users <- getUsers <$> ask
        atomically $ S.insert userId users
        say $ decodeUtf8 $ encode rep
        pure $ Just userId
  logout userId = do
    (req, reqDb, rep) <- liftIO $ genLogoutData userId
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    case rep ^. dData . lorepStatus of
      Invalid -> say $ decodeUtf8 $ encode rep
      _ -> do
        users <- getUsers <$> ask
        atomically $ S.delete userId users
        say $ decodeUtf8 $ encode rep
