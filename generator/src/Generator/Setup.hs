module Generator.Setup
  ( Generator
  , GeneratorWorkMode
  , runGenerator
  ) where

import Universum

import qualified StmContainers.Map as M
import qualified StmContainers.Set as S

import Control.Concurrent.STM.TQueue (TQueue, newTQueueIO)
import Control.Lens (makeLenses)
import Control.Monad.IO.Unlift (MonadUnliftIO)
import Data.Text as T
import Kafka.Consumer (BrokerAddress(..))
import Kafka.Producer (KafkaProducer, brokersList, closeProducer, newProducer)
import RIO (RIO, runRIO)
import System.Environment.Blank (getEnv)

import Generator.Config.Def
  (GeneratorConfig, GeneratorConfigRec, HasConfig(..), MonadConfig, option)
import Generator.Core.Card (HasCardMap(..), MonadCardMap(..))
import Generator.Core.Order (HasOrderMap(..), MonadOrderMap(..))
import Generator.Core.Requests (HasRequest(..), MonadRequest(..))
import Generator.Data.Catalog (ProductId)
import Generator.Data.Common (OrderId, RequestId, UserId)
import Generator.Data.Order (OrderActionType)
import Generator.Kafka (HasKafka(..), MonadKafka(..), producerProps)
import Generator.Services.Card (CardAction, HasCard(..), MonadCard(..))
import Generator.Services.Catalog (CatalogAction, HasCatalog(..), MonadCatalog(..))
import Generator.Services.Login (HasLogin(..), MonadLogin(..))
import Generator.Services.Order (HasOrder(..), MonadOrder)
import Generator.Services.Payment (HasPayment(..), MonadPayment)

data GeneratorContext = GeneratorContext
  { _gcUsers :: S.Set UserId
  , _gcCurRequest :: TVar RequestId
  , _gcCard :: M.Map UserId (Map ProductId Int)
  , _gcOrder :: M.Map UserId (Map OrderId OrderActionType)

  , _gcCatalogQueue :: TQueue CatalogAction
  , _gcLogoutQueue :: TQueue UserId
  , _gcCardQueue :: TQueue CardAction
  , _gcOrderQueue :: TQueue (UserId, Maybe OrderId, OrderActionType)
  , _gcPaymentQueue :: TQueue (UserId, OrderId)

  , _gcConfig :: GeneratorConfigRec
  , _gcKafkaProducer :: Maybe KafkaProducer
  }

makeLenses ''GeneratorContext

type Generator = RIO GeneratorContext

type GeneratorWorkMode m =
  ( Monad m
  , MonadIO m
  , MonadUnliftIO m
  , MonadThrow m
  , MonadCatch m
  , MonadMask m
  , MonadReader GeneratorContext m
  , MonadConfig GeneratorConfig m
  , HasKafka GeneratorContext
  , MonadKafka m
  , MonadRequest m
  , MonadCardMap m
  , MonadOrderMap m
  , HasLogin GeneratorContext
  , HasCatalog GeneratorContext
  , HasCard GeneratorContext
  , HasOrder GeneratorContext
  , HasPayment GeneratorContext
  , MonadLogin m
  , MonadCatalog m
  , MonadCard m
  , MonadOrder m
  , MonadPayment m
  )

runGenerator :: GeneratorConfigRec -> Generator () -> IO ()
runGenerator cfg action = do
  users <- S.newIO
  requests <- newTVarIO 0
  card <- M.newIO
  order <- M.newIO
  catalogQueue <- newTQueueIO
  logoutQueue  <- newTQueueIO
  cardQueue <- newTQueueIO
  orderQueue <- newTQueueIO
  paymentQueue <- newTQueueIO
  mBroker <- getEnv "KAFKA_BROKER"
  let isKafka = cfg ^. option #kafka
      additionalBrokers =
        maybeToMonoid (brokersList . pure . BrokerAddress . T.pack <$> mBroker)
  if not isKafka
  then runRIO
    ( GeneratorContext
      users
      requests
      card
      order
      catalogQueue
      logoutQueue
      cardQueue
      orderQueue
      paymentQueue
      cfg
      Nothing
    ) action
  else bracket (newProducer $ producerProps <> additionalBrokers) clProducer $ \case
    Left err -> putStrLn ((show err) :: Text)
    Right prod -> runRIO
      ( GeneratorContext
        users
        requests
        card
        order
        catalogQueue
        logoutQueue
        cardQueue
        orderQueue
        paymentQueue
        cfg $
        Just prod
      ) action
  where
    clProducer (Left _) = return ()
    clProducer (Right prod) = closeProducer prod

instance HasLogin GeneratorContext where
  getUsers = (^. gcUsers)
  getLogoutQueue = (^. gcLogoutQueue)

instance HasCatalog GeneratorContext where
  getCatalogQueue = (^. gcCatalogQueue)

instance HasCard GeneratorContext where
  getCardQueue = (^. gcCardQueue)

instance HasOrder GeneratorContext where
  getOrderQueue = (^. gcOrderQueue)

instance HasPayment GeneratorContext where
  getPaymentQueue = (^. gcPaymentQueue)

instance HasConfig GeneratorContext where
  getConfig = (^. gcConfig)

instance HasKafka GeneratorContext where
  getProducer = (^. gcKafkaProducer)

instance HasRequest GeneratorContext where
  getCurRequest = (^. gcCurRequest)

instance HasCardMap GeneratorContext where
  getCard = (^. gcCard)

instance HasOrderMap GeneratorContext where
  getOrderMap = (^. gcOrder)
