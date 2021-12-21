module Generator.Data.Order
  ( OrderActionType (..)
  , OrderActionRequest (..)
  , OrderActionDbRequest (..)
  , OrderActionDbReply (..)

  , oarOrderId
  , oarActionType
  , oadreqQuery
  , oadrepStatus

  , genOrderActionRequest
  , genOrderActionDbRequest
  , genOrderActionDbReply
  ) where

import Universum

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

genOrderActionRequest :: MonadGen m => Maybe OrderId -> OrderActionType -> m OrderActionRequest
genOrderActionRequest mOrderId _oarActionType = do
  _oarOrderId <- maybe genOrderId pure mOrderId
  pure OrderActionRequest{..}

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
