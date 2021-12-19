module Generator.Data.Util
  ( deriveToJSON
  , genName
  , AesonType (..)
  ) where

import Universum

import qualified Data.Aeson.TH as DAT
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Data.Aeson (Options(..), defaultOptions)
import Data.Char (isLower, toLower)
import Hedgehog (MonadGen)
import Language.Haskell.TH.Syntax (Dec, Name, Q)

data AesonType = MultipleF | OneF

generatorAesonOptions :: AesonType -> Options
generatorAesonOptions t = defaultOptions
  { fieldLabelModifier = \fieldName ->
      dropWhile (\c -> isLower c || c == '_') fieldName & \case
        a : as -> toLower a : as
        [] -> error "Failed to construct field: " <> fieldName
  , unwrapUnaryRecords = case t of
      OneF -> True
      _ -> False
  }

deriveToJSON :: Name -> AesonType -> Q [Dec]
deriveToJSON n t = DAT.deriveToJSON (generatorAesonOptions t) n

genName :: MonadGen m => m Text
genName = Gen.text (Range.linear 1 30) Gen.alphaNum
