module Generator.Data.Order
  ( OrderActionRequest (..)
  , OrderDetailsRequest (..)
  , OrderActionDbRequest (..)
  , OrderActionDbReply (..)

  , oarOrderId
  , oarActionType
  , odrOrderId
  , oadreqQuery
  , oadrepStatus

  , genOrderActionRequest
  , genOrderDetailsRequest
  , genOrderActionDbRequest
  , genOrderActionDbReply
  ) where

import Universum

import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Control.Lens (makeLenses)
import Hedgehog (MonadGen)

import Generator.Data.Common (OrderId(..), Status(..), UserId(..), genOrderId, genStatus)
import Generator.Data.Util (AesonType(..), deriveToJSON)

data OrderActionType = Reserve | Paid | Refund
  deriving stock Show
deriveToJSON ''OrderActionType MultipleF

data OrderActionRequest = OrderActionRequest
  { _oarOrderId :: OrderId
  , _oarActionType :: OrderActionType
  }
makeLenses ''OrderActionRequest
deriveToJSON 'OrderActionRequest MultipleF

genOrderActionRequest :: MonadGen m => m OrderActionRequest
genOrderActionRequest = do
  actionSelector <- Gen.integral @_ @Int (Range.constant 1 3)
  _oarOrderId <- genOrderId
  let _oarActionType
        | actionSelector == 1 = Reserve
        | actionSelector == 2 = Paid
        | otherwise = Refund
  pure OrderActionRequest{..}

data OrderDetailsRequest = OrderDetailsRequest {_odrOrderId :: OrderId}
makeLenses ''OrderDetailsRequest
deriveToJSON 'OrderDetailsRequest MultipleF

genOrderDetailsRequest :: OrderId -> OrderDetailsRequest
genOrderDetailsRequest = OrderDetailsRequest

data OrderActionDbRequest = OrderActionDbRequest {_oadreqQuery :: Text}
makeLenses ''OrderActionDbRequest
deriveToJSON 'OrderActionDbRequest MultipleF

genOrderActionDbRequest :: UserId -> OrderId -> OrderActionType -> OrderActionDbRequest
genOrderActionDbRequest (UserId uId) (OrderId oId) = \case
  Reserve -> OrderActionDbRequest $
    "insert into order (user_id, order_id, status) values (" <> show uId <> ", " <> show oId <>
    ", Reserve);"
  s -> OrderActionDbRequest $
    "update order set status = " <> show s <> " where user_id = " <> show uId <>
    " and order_id = "<> show oId <> ";"

data OrderActionDbReply = OrderActionDbReply {_oadrepStatus :: Status}
makeLenses ''OrderActionDbReply
deriveToJSON 'OrderActionDbReply MultipleF

genOrderActionDbReply :: MonadGen m => m OrderActionDbReply
genOrderActionDbReply = do
  _oadrepStatus <- genStatus
  pure OrderActionDbReply{..}
