module Generator.Data.Util
  ( deriveToJSON
  , genName
  ) where

import Universum

import qualified Data.Aeson.TH as DAT
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Data.Aeson (Options(..), defaultOptions)
import Data.Char (isLower, toLower)
import Hedgehog (MonadGen)
import Language.Haskell.TH.Syntax (Dec, Name, Q)

generatorAesonOptions :: Options
generatorAesonOptions = defaultOptions
  { fieldLabelModifier = \fieldName ->
      dropWhile (\c -> isLower c || c == '_') fieldName & \case
        a : as -> toLower a : as
        [] -> error "Failed to construct field: " <> fieldName
  }

deriveToJSON :: Name -> Q [Dec]
deriveToJSON = DAT.deriveToJSON generatorAesonOptions

genName :: MonadGen m => m Text
genName = Gen.text (Range.linear 1 30) Gen.unicode
