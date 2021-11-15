module Generator.Data.Base
  ( CommonData (..)
  , Data (..)

  , dAction
  , dCommonData
  , dData
  , cdLogLevel
  , cdServerName
  , cdTime
  , cdUserId
  , cdRequestId

  , genLoginData
  , genLogoutData
  ) where

import Universum

import Control.Lens (makeLenses)
import Data.Time (UTCTime, getCurrentTime)
import Hedgehog.Gen (sample)

import Generator.Data.Common
  (Level(..), RequestId, ServerName(..), Status(..), UserId, genRequestId, genUserId)
import Generator.Data.Login
  (LoginDbRequest, LoginReply, LoginRequest, LogoutDbRequest, LogoutReply, LogoutRequest(..),
  genLoginDbRequest, genLoginReply, genLoginRequest, genLogoutDbRequest, genLogoutReply,
  lorepStatus, lrepStatus, lreqPasswordHash)
import Generator.Data.Util (deriveToJSON)

data ActionType
  = LoginReq
  | LoginDbReq
  | LoginRep
  | LogoutReq
  | LogoutDbReq
  | LogoutRep
deriveToJSON ''ActionType

data CommonData = CommonData
  { _cdLogLevel :: Level
  , _cdServerName :: ServerName
  , _cdTime :: UTCTime
  , _cdUserId :: UserId
  , _cdRequestId :: RequestId
  }
makeLenses ''CommonData
deriveToJSON 'CommonData

data Data a = Data
  { _dAction :: ActionType
  , _dCommonData :: CommonData
  , _dData :: a
  }
makeLenses ''Data
deriveToJSON 'Data

genLoginData :: IO (Data LoginRequest, Data LoginDbRequest, Data LoginReply)
genLoginData = do
  userId <- sample genUserId
  requestId <- sample genRequestId
  loginRequest <- sample genLoginRequest
  let loginDbRequest = genLoginDbRequest userId $ loginRequest ^. lreqPasswordHash
  loginReply <- sample genLoginReply
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = case loginReply ^. lrepStatus of Valid -> Info; _ -> Error
        , _cdServerName = Login
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  pure
    ( Data LoginReq commonData loginRequest
    , Data LoginDbReq commonData loginDbRequest
    , Data LoginRep commonData loginReply
    )

genLogoutData :: UserId -> IO (Data LogoutRequest, Data LogoutDbRequest, Data LogoutReply)
genLogoutData userId = do
  requestId <- sample genRequestId
  let logoutRequest = LogoutRequest
  let logoutDbRequest = genLogoutDbRequest userId
  logoutReply <- sample genLogoutReply
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = case logoutReply ^. lorepStatus of Valid -> Info; _ -> Error
        , _cdServerName = Login
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  pure
    ( Data LogoutReq commonData logoutRequest
    , Data LogoutDbReq commonData logoutDbRequest
    , Data LogoutRep commonData logoutReply
    )

