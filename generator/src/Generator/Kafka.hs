module Generator.Kafka
  ( HasKafka (..)
  , MonadKafka (..)
  , mkMessage
  , producerProps
  , targetTopic
  ) where

import Universum

import Kafka.Producer
  (KafkaLogLevel(..), KafkaProducer, ProducePartition(..), ProducerProperties, ProducerRecord(..),
  Timeout(..), TopicName, brokersList, deliveryCallback, logLevel, produceMessage, sendTimeout,
  setCallback)
import Say (say)

producerProps :: ProducerProperties
producerProps = brokersList ["localhost:9094"]
             <> sendTimeout (Timeout 10000)
             <> setCallback (deliveryCallback print)
             <> logLevel KafkaLogDebug

targetTopic :: TopicName
targetTopic = "gen-logs"

mkMessage :: Text -> ProducerRecord
mkMessage v = ProducerRecord
                  { prTopic = targetTopic
                  , prPartition = UnassignedPartition
                  , prKey = Nothing
                  , prValue = Just $ encodeUtf8 v
                  }

class Monad m => MonadKafka m where
  logKafka :: Text -> m ()

class HasKafka env where
  getProducer :: env -> Maybe KafkaProducer

instance (MonadIO m, Monad m, HasKafka env, MonadReader env m) => MonadKafka m where
  logKafka t = do
    mProducer <- getProducer <$> ask
    case mProducer of
      Nothing -> say t
      Just producer -> do
        mErr <- produceMessage producer $ mkMessage t
        case mErr of
          Just err -> say $ show err
          _ -> pass
