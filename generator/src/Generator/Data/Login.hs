module Generator.Data.Login
  ( LoginRequest (..)
  , LoginDbRequest (..)
  , LoginReply (..)
  , LogoutRequest (..)
  , LogoutDbRequest (..)
  , LogoutReply (..)

  , lreqPasswordHash
  , ldrQuery
  , lrepStatus
  , lodrQuery
  , lorepStatus

  , genLoginRequest
  , genLoginDbRequest
  , genLoginReply
  , genLogoutDbRequest
  , genLogoutReply
  ) where

import Universum

import Control.Lens (makeLenses)
import Hedgehog (MonadGen)

import Generator.Data.Common (Status(..), UserId(..), genStatus)
import Generator.Data.Util (deriveToJSON, genName)

newtype LoginRequest = LoginRequest { _lreqPasswordHash :: Text }
makeLenses ''LoginRequest
deriveToJSON 'LoginRequest

genLoginRequest :: MonadGen m => m LoginRequest
genLoginRequest = LoginRequest <$> genName

newtype LoginDbRequest = LoginDbRequest { _ldrQuery :: Text }
makeLenses ''LoginDbRequest
deriveToJSON 'LoginDbRequest

genLoginDbRequest :: UserId -> Text -> LoginDbRequest
genLoginDbRequest (UserId id') t = LoginDbRequest $
  "select * from users where users.user_id = " <> show id' <> " and users.password_hash = " <> t

newtype LoginReply = LoginReply {_lrepStatus :: Status}
makeLenses ''LoginReply
deriveToJSON 'LoginReply

genLoginReply :: MonadGen m => m LoginReply
genLoginReply = LoginReply <$> genStatus

data LogoutRequest = LogoutRequest
deriveToJSON 'LogoutRequest

newtype LogoutDbRequest = LogoutDbRequest { _lodrQuery :: Text }
makeLenses ''LogoutDbRequest
deriveToJSON 'LogoutDbRequest

genLogoutDbRequest :: UserId -> LogoutDbRequest
genLogoutDbRequest (UserId id') = LogoutDbRequest $
  "delete from users where users.user_id = " <> show id'

newtype LogoutReply = LogoutReply {_lorepStatus :: Status}
makeLenses ''LogoutReply
deriveToJSON 'LogoutReply

genLogoutReply :: MonadGen m => m LogoutReply
genLogoutReply = LogoutReply <$> genStatus
