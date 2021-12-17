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
import Generator.Data.Util (AesonType(..), deriveToJSON, genName)

newtype LoginRequest = LoginRequest { _lreqPasswordHash :: Text }
makeLenses ''LoginRequest
deriveToJSON 'LoginRequest MultipleF

genLoginRequest :: MonadGen m => m LoginRequest
genLoginRequest = LoginRequest <$> genName

newtype LoginDbRequest = LoginDbRequest { _ldrQuery :: Text }
makeLenses ''LoginDbRequest
deriveToJSON 'LoginDbRequest MultipleF

genLoginDbRequest :: UserId -> Text -> LoginDbRequest
genLoginDbRequest (UserId id') t = LoginDbRequest $
  "select * from users where users.user_id = " <> show id' <> " and users.password_hash = " <> t

newtype LoginReply = LoginReply {_lrepStatus :: Status}
makeLenses ''LoginReply
deriveToJSON 'LoginReply MultipleF

genLoginReply :: MonadGen m => m LoginReply
genLoginReply = LoginReply <$> genStatus

data LogoutRequest = LogoutRequest
deriveToJSON 'LogoutRequest MultipleF

newtype LogoutDbRequest = LogoutDbRequest { _lodrQuery :: Text }
makeLenses ''LogoutDbRequest
deriveToJSON 'LogoutDbRequest MultipleF

genLogoutDbRequest :: UserId -> LogoutDbRequest
genLogoutDbRequest (UserId id') = LogoutDbRequest $
  "delete from users where users.user_id = " <> show id'

newtype LogoutReply = LogoutReply {_lorepStatus :: Status}
makeLenses ''LogoutReply
deriveToJSON 'LogoutReply MultipleF

genLogoutReply :: MonadGen m => m LogoutReply
genLogoutReply = LogoutReply <$> genStatus
