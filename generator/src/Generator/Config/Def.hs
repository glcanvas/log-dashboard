module Generator.Config.Def
       ( GeneratorConfig
       , GeneratorConfigRec
       , MonadConfig (..)
       , HasConfig (..)
       , option
       , sub
       ) where

import Universum

import Control.Lens (Getting)
import Loot.Config (ConfigKind(Final), ConfigRec, option, sub, (:::))

type GeneratorConfig = '["kafka" ::: Bool]

type GeneratorConfigRec = ConfigRec 'Final GeneratorConfig

class Monad m => MonadConfig cfg m where
  askConfig :: m (ConfigRec 'Final cfg)
  fromConfig :: Getting a (ConfigRec 'Final cfg) a -> m a

class HasConfig env where
  getConfig :: env -> GeneratorConfigRec

instance (HasConfig env, MonadReader env m) => MonadConfig GeneratorConfig m where
  askConfig = getConfig <$> ask
  fromConfig getter = (^. getter) <$> askConfig
