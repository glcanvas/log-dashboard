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
  , genProductDataC
  , genCatalogData

  , genCatalogAction
  , genCatalogList

  , genOrder

  , genPayment
  ) where

import Universum

import Control.Lens (makeLenses)
import Data.Time (UTCTime, getCurrentTime)
import Hedgehog.Gen (sample)

import Generator.Data.Card
  (CardActionRedisReply, CardActionRedisRequest, CardActionRequest(..), CardListRedisReply,
  CardListRedisRequest, CardListRequest(..), genCardAction, genCardActionRedisReply,
  genCardActionRedisRequest, genCardListRedisReply, genCardListRedisRequest)
import Generator.Data.Catalog
  (CatalogDbReply, CatalogDbRequest, CatalogRequest(..), LinkedProductsDbReply,
  LinkedProductsDbRequest, ProductDbReply, ProductDbRequest, ProductRequest, genCatalogDbReply,
  genCatalogDbRequest, genLinkedProductsDbReply, genLinkedProductsDbRequest, genProductDbReply,
  genProductDbRequest, genProductRequest, pdrepStatus, prProductId)
import Generator.Data.Common
  (Level(..), RequestId, ServerName(..), Status(..), UserId, genRequestId, genUserId)
import Generator.Data.Login
  (LoginDbRequest, LoginReply, LoginRequest, LogoutDbRequest, LogoutReply, LogoutRequest(..),
  genLoginDbRequest, genLoginReply, genLoginRequest, genLogoutDbRequest, genLogoutReply,
  lreqPasswordHash)
import Generator.Data.Order
  (OrderActionDbReply, OrderActionDbRequest, OrderActionRequest(..), OrderDetailsRequest,
  genOrderActionDbReply, genOrderActionDbRequest, genOrderActionRequest, genOrderDetailsRequest)
import Generator.Data.Payment
  (PaymentCredentialsReply, PaymentCredentialsRequest, PaymentRequest, genPaymentCredentialsReply,
  genPaymentCredentialsRequest, genPaymentRequest)
import Generator.Data.Util (AesonType(..), deriveToJSON)

data ActionType
  = LoginReq
  | LoginDbReq
  | LoginRep

  | LogoutReq
  | LogoutDbReq
  | LogoutRep

  | CatalogProductReq
  | CatalogProductDbReq
  | CatalogProductDbRep
  | CatalogLinkedProductsDbReq
  | CatalogLinkedProductsDbRep

  | CatalogReq
  | CatalogDbReq
  | CatalogDbRep

  | CardActionReq
  | CardActionRedisReq
  | CardActionRedisRep

  | CardListReq
  | CardListRedisReq
  | CardListRedisRep

  | OrderActionReq
  | OrderDetailsReq
  | OrderActionDbReq
  | OrderActionDbRep

  | PaymentReq
  | PaymentCredentialsReq
  | PaymentCredentialsRep
deriveToJSON ''ActionType MultipleF

data CommonData = CommonData
  { _cdLogLevel :: Level
  , _cdServerName :: ServerName
  , _cdTime :: UTCTime
  , _cdUserId :: UserId
  , _cdRequestId :: RequestId
  }
makeLenses ''CommonData
deriveToJSON 'CommonData MultipleF

data Data a = Data
  { _dAction :: ActionType
  , _dCommonData :: CommonData
  , _dData :: a
  }
makeLenses ''Data
deriveToJSON 'Data MultipleF

genLoginData :: IO (Data LoginRequest, Data LoginDbRequest, Data LoginReply)
genLoginData = do
  userId <- sample genUserId
  requestId <- sample genRequestId
  loginRequest <- sample genLoginRequest
  let loginDbRequest = genLoginDbRequest userId $ loginRequest ^. lreqPasswordHash
  loginReply <- sample genLoginReply
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
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
        { _cdLogLevel = Info
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

genProductDataC
  :: UserId
  -> IO
     ( Data ProductRequest
     , Data ProductDbRequest
     , Data ProductDbReply
     , Maybe (Data LinkedProductsDbRequest)
     , Maybe (Data LinkedProductsDbReply)
     )
genProductDataC userId = do
  requestId <- sample genRequestId
  productRequest <- sample genProductRequest
  let pid = productRequest ^. prProductId
  let productDbRequest = genProductDbRequest pid
  productDbReply <- sample $ genProductDbReply pid
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Catalog
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  case productDbReply ^. pdrepStatus of
    Invalid -> pure
      ( Data CatalogProductReq commonData productRequest
      , Data CatalogProductDbReq commonData productDbRequest
      , Data CatalogProductDbRep commonData productDbReply
      , Nothing
      , Nothing
      )
    Valid -> do
      let linkedProductsDbRequest = genLinkedProductsDbRequest pid
      linkedProductsDbReply <- sample genLinkedProductsDbReply
      pure
        ( Data CatalogProductReq commonData productRequest
        , Data CatalogProductDbReq commonData productDbRequest
        , Data CatalogProductDbRep commonData productDbReply
        , Just $ Data CatalogLinkedProductsDbReq commonData linkedProductsDbRequest
        , Just $ Data CatalogLinkedProductsDbRep commonData linkedProductsDbReply
        )

genCatalogData :: UserId -> IO (Data CatalogRequest, Data CatalogDbRequest, Data CatalogDbReply)
genCatalogData userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Catalog
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
      catalogRequest = CatalogRequest
      catalogDbRequest = genCatalogDbRequest
  catalogDbReply <- sample genCatalogDbReply
  pure
    ( Data CatalogReq commonData catalogRequest
    , Data CatalogDbReq commonData catalogDbRequest
    , Data CatalogDbRep commonData catalogDbReply
    )

genCatalogAction
  :: UserId
  -> IO (Data CardActionRequest, Data CardActionRedisRequest, Data CardActionRedisReply)
genCatalogAction userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Card
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  cardAction@CardActionRequest{..} <- sample genCardAction
  let cardActionRedisRequest = genCardActionRedisRequest userId _caProductId _caAction
  cardActionRedisReply <- sample genCardActionRedisReply
  pure
    ( Data CardActionReq commonData cardAction
    , Data CardActionRedisReq commonData cardActionRedisRequest
    , Data CardActionRedisRep commonData cardActionRedisReply
    )

genCatalogList
  :: UserId
  -> IO (Data CardListRequest, Data CardListRedisRequest, Data CardListRedisReply)
genCatalogList userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Card
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
      cardListRequest = CardListRequest
      cardListRedisRequest = genCardListRedisRequest userId
  cardListRedisReply <- sample genCardListRedisReply
  pure
    ( Data CardListReq commonData cardListRequest
    , Data CardListRedisReq commonData cardListRedisRequest
    , Data CardListRedisRep commonData cardListRedisReply
    )

genOrder
  :: UserId
  -> IO
     ( Data OrderActionRequest
     , Data OrderDetailsRequest
     , Data OrderActionDbRequest
     , Data OrderActionDbReply
     )
genOrder userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Card
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  orderActionRequest@OrderActionRequest{..} <- sample genOrderActionRequest
  let orderDetailsRequest = genOrderDetailsRequest _oarOrderId
      orderActionDbRequest = genOrderActionDbRequest userId _oarOrderId _oarActionType
  orderActionDbReply <- sample genOrderActionDbReply
  pure
    ( Data OrderActionReq commonData orderActionRequest
    , Data OrderDetailsReq commonData orderDetailsRequest
    , Data OrderActionDbReq commonData orderActionDbRequest
    , Data OrderActionDbRep commonData orderActionDbReply
    )

genPayment
  :: UserId
  -> IO (Data PaymentRequest, Data PaymentCredentialsRequest, Data PaymentCredentialsReply)
genPayment userId = do
  requestId <- sample genRequestId
  time <- getCurrentTime
  let commonData = CommonData
        { _cdLogLevel = Info
        , _cdServerName = Card
        , _cdTime = time
        , _cdUserId = userId
        , _cdRequestId = requestId
        }
  paymentRequest <- sample genPaymentRequest
  paymentCredentialsRequest <- sample genPaymentCredentialsRequest
  paymentCredentialsReply <- sample genPaymentCredentialsReply
  pure
    ( Data PaymentReq commonData paymentRequest
    , Data PaymentCredentialsReq commonData paymentCredentialsRequest
    , Data PaymentCredentialsRep commonData paymentCredentialsReply
    )
