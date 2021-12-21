module Generator.Data.Payment
  ( PaymentProvider (..)
  , PaymentRequest (..)
  , PaymentCredentialsRequest (..)
  , PaymentCredentialsReply (..)

  , prOrderId
  , prProvider
  , prAmount
  , pcreqAddress
  , pcreqPassword
  , pcrepStatus

  , genPaymentRequest
  , genPaymentCredentialsRequest
  , genPaymentCredentialsReply
  ) where

import Universum

import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Control.Lens (makeLenses)
import Hedgehog (MonadGen)

import Generator.Data.Common (OrderId(..), Status(..), genStatus)
import Generator.Data.Util (AesonType(..), deriveToJSON, genName)

data PaymentProvider = Btc | Mastercard | Visa
  deriving stock Show
deriveToJSON ''PaymentProvider MultipleF

data PaymentRequest = PaymentRequest
  { _prOrderId :: OrderId
  , _prProvider :: PaymentProvider
  , _prAmount :: Int
  }
makeLenses ''PaymentRequest
deriveToJSON 'PaymentRequest MultipleF

genPaymentRequest :: MonadGen m => OrderId -> m PaymentRequest
genPaymentRequest _prOrderId = do
  actionSelector <- Gen.integral @_ @Int (Range.constant 1 3)
  let _prProvider
        | actionSelector == 1 = Btc
        | actionSelector == 2 = Mastercard
        | otherwise = Visa
  _prAmount <- Gen.integral (Range.constant 1 200000)
  pure PaymentRequest{..}

data PaymentCredentialsRequest = PaymentCredentialsRequest
  { _pcreqAddress :: Text
  , _pcreqPassword :: Text
  }
makeLenses ''PaymentCredentialsRequest
deriveToJSON 'PaymentCredentialsRequest MultipleF

genPaymentCredentialsRequest :: MonadGen m => m PaymentCredentialsRequest
genPaymentCredentialsRequest = do
  _pcreqAddress <- genName
  _pcreqPassword <- genName
  pure PaymentCredentialsRequest{..}

data PaymentCredentialsReply = PaymentCredentialsReply {_pcrepStatus :: Status}
makeLenses ''PaymentCredentialsReply
deriveToJSON 'PaymentCredentialsReply MultipleF

genPaymentCredentialsReply :: MonadGen m => m PaymentCredentialsReply
genPaymentCredentialsReply = do
  _pcrepStatus <- genStatus
  pure PaymentCredentialsReply{..}
