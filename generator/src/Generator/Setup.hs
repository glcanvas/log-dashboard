module Generator.Setup
  ( Generator
  , GeneratorWorkMode
  , runGenerator
  ) where

import Universum

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
import Generator.Data.Common (UserId)
import Generator.Kafka (HasKafka(..), MonadKafka(..), producerProps)
import Generator.Services.Card (CardAction, HasCard(..), MonadCard(..))
import Generator.Services.Catalog (CatalogAction, HasCatalog(..), MonadCatalog(..))
import Generator.Services.Login (HasLogin(..), MonadLogin(..))

data GeneratorContext = GeneratorContext
  { _gcUsers :: S.Set UserId
  , _gcCatalogQueue :: TQueue CatalogAction
  , _gcLogoutQueue :: TQueue UserId
  , _gcCardQueue :: TQueue CardAction
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
  , HasLogin GeneratorContext
  , HasCatalog GeneratorContext
  , HasCard GeneratorContext
  , MonadLogin m
  , MonadCatalog m
  , MonadCard m
  )

runGenerator :: GeneratorConfigRec -> Generator () -> IO ()
runGenerator cfg action = do
  q <- newTQueueIO
  q' <- newTQueueIO
  q'' <- newTQueueIO
  s <- S.newIO
  mBroker <- getEnv "KAFKA_BROKER"
  let isKafka = cfg ^. option #kafka
      additionalBrokers =
        maybeToMonoid (brokersList . pure . BrokerAddress . T.pack <$> mBroker)
  if not isKafka
  then runRIO (GeneratorContext s q q' q'' cfg Nothing) action
  else bracket (newProducer $ producerProps <> additionalBrokers) clProducer $ \case
    Left err -> putStrLn ((show err) :: Text)
    Right prod -> runRIO (GeneratorContext s q q' q'' cfg $ Just prod) action
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

instance HasConfig GeneratorContext where
  getConfig = (^. gcConfig)

instance HasKafka GeneratorContext where
  getProducer = (^. gcKafkaProducer)
