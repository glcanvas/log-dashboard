module Generator.Config.Reading
       ( ConfigError (..)
       , readConfigs
       , configPathsParser
       ) where

import Universum

import Control.Applicative.Combinators.NonEmpty as NonEmpty (some)
import Data.Aeson (Result(..), Value(..), fromJSON)
import qualified Data.HashMap.Strict as HM
import Data.Yaml (decodeFileEither, prettyPrintParseException)
import Loot.Config (finalise)
import qualified Options.Applicative as Opt

import Generator.Config.Def (GeneratorConfigRec)

data ConfigError
  = ConfigReadingError !String
  | ConfigParsingError !String
  | ConfigIncomplete ![String]
  deriving stock (Show, Eq, Generic)

instance Exception ConfigError

readConfigsValue
  :: (MonadIO m)
  => NonEmpty FilePath
  -> m Value
readConfigsValue = foldM addConfigValue (Object mempty)
  where
    addConfigValue prev =
      fmap (mergeOverride prev) . readOneConfig
    readOneConfig file = liftIO $
      decodeFileEither file >>= either rethrowParseException pure
    rethrowParseException = throwM . ConfigReadingError . prettyPrintParseException
    mergeOverride (Object o1) (Object o2) =
      Object $ HM.unionWith mergeOverride o1 o2
    mergeOverride _ b = b

readConfigs
  :: (MonadIO m, MonadThrow m)
  => NonEmpty FilePath
  -> m GeneratorConfigRec
readConfigs files = do
  let successOrThrow (Error s)   = throwM $ ConfigParsingError s
      successOrThrow (Success a) = pure a
  val <- readConfigsValue files
  cfg <- successOrThrow $ fromJSON val
  either (throwM . ConfigIncomplete) pure $
    finalise cfg

configPathsParser :: Opt.Parser (NonEmpty FilePath)
configPathsParser = NonEmpty.some $ Opt.strOption $
  Opt.short 'c' <>
  Opt.long "config" <>
  Opt.metavar "FILEPATH" <>
  Opt.help "Path to configuration file. Multiple -c options can \
           \be provided, in which case configuration is merged. \
           \The order matters, the latter one overrides the former."
