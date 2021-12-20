module Generator.Data.Common
  ( Level (..)
  , ServerName (..)
  , UserId (..)
  , RequestId (..)
  , Status (..)
  , OrderId (..)

  , genUserId
  , genOrderId
  , genStatus
  , genRequestId
  ) where

import Universum

import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Hedgehog (MonadGen)

import Generator.Data.Util (AesonType(..), deriveToJSON)

data Level = Error | Warning | Info | Debug
deriveToJSON ''Level MultipleF

data ServerName = Login | Catalog | Card
deriveToJSON ''ServerName MultipleF

newtype UserId = UserId { unUserId :: Int }
  deriving newtype (Eq, Hashable)
deriveToJSON 'UserId OneF

genUserId :: MonadGen m => m UserId
genUserId = UserId <$> Gen.integral (Range.constant 0 1000000)

newtype OrderId = OrderId {unOrderId :: Int}
deriveToJSON ''OrderId OneF

genOrderId :: MonadGen m => m OrderId
genOrderId = OrderId <$> Gen.integral (Range.constant 0 1000000)

newtype RequestId = RequestId { unRequestId :: Int }
  deriving newtype Num
deriveToJSON 'RequestId OneF

genRequestId :: MonadGen m => m RequestId
genRequestId = RequestId <$> Gen.integral (Range.constant 0 1000000)

data Status = Valid | Invalid
  deriving stock Eq
deriveToJSON ''Status MultipleF

genStatus :: MonadGen m => m Status
genStatus = do
  i :: Int <- Gen.integral (Range.constant 0 10)
  if i == 0
  then pure Invalid
  else pure Valid
