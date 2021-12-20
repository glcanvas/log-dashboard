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
  CardListRedisRequest, CardListRequest(..), carrepStatus, clrrepStatus, genCardAction,
  genCardActionRedisReply, genCardActionRedisRequest, genCardListRedisReply,
  genCardListRedisRequest)
import Generator.Data.Catalog
  (CatalogDbReply, CatalogDbRequest, CatalogRequest(..), LinkedProductsDbReply,
  LinkedProductsDbRequest, ProductDbReply, ProductDbRequest, ProductRequest, cdrepStatus,
  genCatalogDbReply, genCatalogDbRequest, genLinkedProductsDbReply, genLinkedProductsDbRequest,
  genProductDbReply, genProductDbRequest, genProductRequest, lpdrepStatus, pdrepStatus, prProductId)
import Generator.Data.Common
  (Level(..), RequestId, ServerName(..), Status(..), UserId, genRequestId, genUserId)
import Generator.Data.Login
  (LoginDbRequest, LoginReply, LoginRequest, LogoutDbRequest, LogoutReply, LogoutRequest(..),
  genLoginDbRequest, genLoginReply, genLoginRequest, genLogoutDbRequest, genLogoutReply,
  lorepStatus, lrepStatus, lreqPasswordHash)
import Generator.Data.Order
  (OrderActionDbReply, OrderActionDbRequest, OrderActionRequest(..), OrderDetailsRequest,
  genOrderActionDbReply, genOrderActionDbRequest, genOrderActionRequest, genOrderDetailsRequest,
  oadrepStatus)
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

genLoginData :: RequestId -> IO (Data LoginRequest, Data LoginDbRequest, Data LoginReply)
genLoginData requestId = do
  userId <- sample genUserId
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
    , Data LoginDbReq commonData{_cdLogLevel = Debug} loginDbRequest
    , Data LoginRep commonData{_cdLogLevel = if loginReply ^. lrepStatus == Invalid then Error else Debug} loginReply
    )

genLogoutData :: RequestId -> UserId -> IO (Data LogoutRequest, Data LogoutDbRequest, Data LogoutReply)
genLogoutData requestId userId = do
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
    , Data LogoutDbReq commonData{_cdLogLevel = Debug} logoutDbRequest
    , Data LogoutRep commonData{_cdLogLevel = if logoutReply ^. lorepStatus == Invalid then Error else Debug} logoutReply
    )

genProductDataC
  :: UserId
  -> RequestId
  -> IO
     ( Data ProductRequest
     , Data ProductDbRequest
     , Data ProductDbReply
     , Maybe (Data LinkedProductsDbRequest)
     , Maybe (Data LinkedProductsDbReply)
     )
genProductDataC userId requestId = do
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
      , Data CatalogProductDbReq commonData{_cdLogLevel = Debug} productDbRequest
      , Data CatalogProductDbRep commonData{_cdLogLevel = if productDbReply ^. pdrepStatus == Invalid then Error else Debug} productDbReply
      , Nothing
      , Nothing
      )
    Valid -> do
      let linkedProductsDbRequest = genLinkedProductsDbRequest pid
      linkedProductsDbReply <- sample genLinkedProductsDbReply
      pure
        ( Data CatalogProductReq commonData productRequest
        , Data CatalogProductDbReq commonData{_cdLogLevel = Debug} productDbRequest
        , Data CatalogProductDbRep commonData{_cdLogLevel = if productDbReply ^. pdrepStatus == Invalid then Error else Debug} productDbReply
        , Just $ Data CatalogLinkedProductsDbReq commonData{_cdLogLevel = Debug} linkedProductsDbRequest
        , Just $ Data CatalogLinkedProductsDbRep commonData{_cdLogLevel = if linkedProductsDbReply ^. lpdrepStatus == Invalid then Error else Debug} linkedProductsDbReply
        )

genCatalogData :: UserId -> RequestId -> IO (Data CatalogRequest, Data CatalogDbRequest, Data CatalogDbReply)
genCatalogData userId requestId = do
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
    , Data CatalogDbReq commonData{_cdLogLevel = Debug} catalogDbRequest
    , Data CatalogDbRep commonData{_cdLogLevel = if catalogDbReply ^. cdrepStatus == Invalid then Error else Debug} catalogDbReply
    )

genCatalogAction
  :: UserId
  -> RequestId
  -> IO (Data CardActionRequest, Data CardActionRedisRequest, Data CardActionRedisReply)
genCatalogAction userId requestId = do
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
    , Data CardActionRedisReq commonData{_cdLogLevel = Debug} cardActionRedisRequest
    , Data CardActionRedisRep commonData{_cdLogLevel = if cardActionRedisReply ^. carrepStatus == Invalid then Error else Debug} cardActionRedisReply
    )

genCatalogList
  :: UserId
  -> RequestId
  -> IO (Data CardListRequest, Data CardListRedisRequest, Data CardListRedisReply)
genCatalogList userId requestId = do
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
    , Data CardListRedisReq commonData{_cdLogLevel = Debug} cardListRedisRequest
    , Data CardListRedisRep commonData{_cdLogLevel = if cardListRedisReply ^. clrrepStatus == Invalid then Error else Debug} cardListRedisReply
    )

genOrder
  :: UserId
  -> RequestId
  -> IO
     ( Data OrderActionRequest
     , Data OrderDetailsRequest
     , Data OrderActionDbRequest
     , Data OrderActionDbReply
     )
genOrder userId requestId = do
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
    , Data OrderActionDbReq commonData{_cdLogLevel = Debug} orderActionDbRequest
    , Data OrderActionDbRep commonData{_cdLogLevel = if orderActionDbReply ^. oadrepStatus == Invalid then Error else Debug} orderActionDbReply
    )

genPayment
  :: UserId
  -> RequestId
  -> IO (Data PaymentRequest, Data PaymentCredentialsRequest, Data PaymentCredentialsReply)
genPayment userId requestId = do
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
