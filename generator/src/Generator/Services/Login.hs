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
  login :: m (Maybe Int)
  logout :: Int -> m ()

class HasLogin env where
  getUsers :: env -> S.Set Int
  getLogoutQueue :: env -> TQueue Int

instance (MonadIO m, Monad m, HasLogin env, MonadReader env m) => MonadLogin m where
  login = do
    (req, reqDb, rep) <- liftIO genLoginData
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    let (UserId uId) = req ^. dCommonData . cdUserId
    case rep ^. dData . lrepStatus of
      Invalid -> (say $ decodeUtf8 $ encode rep) >> pure Nothing
      _ -> do
        users <- getUsers <$> ask
        atomically $ S.insert uId users
        say $ decodeUtf8 $ encode rep
        pure $ Just uId
  logout uId = do
    (req, reqDb, rep) <- liftIO $ genLogoutData $ UserId uId
    say $ decodeUtf8 $ encode req
    say $ decodeUtf8 $ encode reqDb
    case rep ^. dData . lorepStatus of
      Invalid -> (say $ decodeUtf8 $ encode rep)
      _ -> do
        users <- getUsers <$> ask
        atomically $ S.delete uId users
        say $ decodeUtf8 $ encode rep
