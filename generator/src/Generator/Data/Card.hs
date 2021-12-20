module Generator.Data.Card
  ( CardActionType (..)
  , CardElement (..)
  , CardActionRequest (..)
  , CardActionRedisRequest (..)
  , CardActionRedisReply (..)
  , CardListRequest (..)
  , CardListRedisRequest (..)
  , CardListRedisReply (..)

  , ceProductData
  , ceAmount
  , caAction
  , caProductId
  , carreqQuery
  , carrepStatus
  , clreqQuery
  , clrrepProducts
  , clrrepStatus

  , genCardElement
  , genCardAction
  , genCardActionRedisRequest
  , genCardActionRedisReply
  , genCardListRedisRequest
  , genCardListRedisReply
  ) where

import Universum

import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Control.Lens (makeLenses)
import Hedgehog (MonadGen)

import Generator.Data.Catalog (ProductData, ProductId(..), genProductData, genProductId)
import Generator.Data.Common (Status(..), UserId(..), genStatus)
import Generator.Data.Util (AesonType(..), deriveToJSON)

data CardActionType = Add | Remove
deriveToJSON ''CardActionType MultipleF

data CardElement = CardElement
  { _ceProductData :: ProductData
  , _ceAmount :: Int
  }
makeLenses ''CardElement
deriveToJSON 'CardElement MultipleF

genCardElement :: MonadGen m => m CardElement
genCardElement = do
  _ceProductData <- genProductData Nothing
  _ceAmount <- Gen.integral (Range.constant 1 10)
  pure CardElement{..}

data CardActionRequest = CardActionRequest
  { _caAction :: CardActionType
  , _caProductId :: ProductId
  }
makeLenses ''CardActionRequest
deriveToJSON 'CardActionRequest MultipleF

genCardAction :: MonadGen m => m CardActionRequest
genCardAction = do
  actionSelector <- Gen.integral @_ @Int (Range.constant 1 2)
  let _caAction = if actionSelector == 1 then Add else Remove
  _caProductId <- genProductId
  pure CardActionRequest{..}

data CardActionRedisRequest = CardActionRedisRequest { _carreqQuery :: Text }
makeLenses ''CardActionRedisRequest
deriveToJSON 'CardActionRedisRequest MultipleF

genCardActionRedisRequest :: UserId -> ProductId -> CardActionType -> CardActionRedisRequest
genCardActionRedisRequest (UserId uId) (ProductId pId) = \case
  Add -> CardActionRedisRequest $
    "insert into card (user_id, product_id, amount) values (" <> show uId <> ", " <> show pId <>
    ", 1) on conflict (user_id, product_id) do update set amount = amount + 1;"
  Remove -> CardActionRedisRequest $
    "if (select is_one from card where user_id = " <> show uId <> " and product_id = "<> show pId <>
    " and amount = 1) then delete from card where user_id = " <> show uId <>
    " and product_id = " <> show pId <> " else update card set amount = amount - 1 where user_id = "
    <> show uId <> " and product_id = "<> show pId <> "end if;"

data CardActionRedisReply = CardActionRedisReply { _carrepStatus :: Status }
makeLenses ''CardActionRedisReply
deriveToJSON 'CardActionRedisReply MultipleF

genCardActionRedisReply :: MonadGen m => m CardActionRedisReply
genCardActionRedisReply = do
  _carrepStatus <- genStatus
  pure CardActionRedisReply{..}

data CardListRequest = CardListRequest
deriveToJSON 'CardListRequest MultipleF

data CardListRedisRequest = CardListRedisRequest { _clreqQuery :: Text }
makeLenses ''CardListRedisRequest
deriveToJSON 'CardListRedisRequest MultipleF

genCardListRedisRequest :: UserId -> CardListRedisRequest
genCardListRedisRequest (UserId uId) = CardListRedisRequest $
  "select * from card where user_id = " <> show uId <> ";"

data CardListRedisReply = CardListRedisReply
  { _clrrepProducts :: [CardElement]
  , _clrrepStatus :: Status
  }
makeLenses ''CardListRedisReply
deriveToJSON 'CardListRedisReply MultipleF

genCardListRedisReply :: MonadGen m => m CardListRedisReply
genCardListRedisReply = do
  s <- genStatus
  case s of
    Invalid -> pure $ CardListRedisReply [] s
    Valid -> CardListRedisReply <$>
      (Gen.list (Range.constant 1 10) genCardElement) <*>
      pure s
