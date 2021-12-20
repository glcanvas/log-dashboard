module Generator.Data.Catalog
  ( Price (..)
  , ProductId (..)
  , ProductData (..)
  , ProductRequest (..)
  , ProductDbRequest (..)
  , ProductDbReply (..)
  , LinkedProductsDbRequest (..)
  , LinkedProductsDbReply (..)
  , CatalogRequest (..)
  , CatalogDbRequest (..)
  , CatalogDbReply (..)

  , pProductId
  , pDescription
  , pPrice
  , prProductId
  , pdrQuery
  , pdrepData
  , pdrepStatus
  , lpdrQuery
  , lpdrepProducts
  , lpdrepStatus
  , cdrQuery
  , cdrepProducts
  , cdrepStatus

  , genPrice
  , genProductId
  , genProductData
  , genProductRequest
  , genProductDbRequest
  , genProductDbReply
  , genLinkedProductsDbRequest
  , genLinkedProductsDbReply
  , genCatalogDbRequest
  , genCatalogDbReply
  ) where

import Universum

import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range

import Control.Lens (makeLenses)
import Hedgehog (MonadGen)

import Generator.Data.Common (Status(..), genStatus)
import Generator.Data.Util (AesonType(..), deriveToJSON, genName)

newtype Price = Price {unPrice :: Int}
deriveToJSON 'Price OneF

genPrice :: MonadGen m => m Price
genPrice = Price <$> Gen.integral (Range.constant 1 1000000)

newtype ProductId = ProductId {unProductId :: Int}
  deriving newtype (Eq, Ord)
deriveToJSON 'ProductId OneF

genProductId :: MonadGen m => m ProductId
genProductId = ProductId <$> Gen.integral (Range.constant 1 1000000)

data ProductData = ProductData
  { _pProductId :: ProductId
  , _pDescription :: Text
  , _pPrice :: Price
  }
makeLenses ''ProductData
deriveToJSON 'ProductData MultipleF

genProductData :: MonadGen m => Maybe ProductId -> m ProductData
genProductData pId = do
  _pProductId <- maybe (ProductId <$> Gen.integral (Range.constant 1 1000000)) pure pId
  _pDescription <- genName
  _pPrice <- genPrice
  pure ProductData{..}

data ProductRequest = ProductRequest {_prProductId :: ProductId}
makeLenses ''ProductRequest
deriveToJSON 'ProductRequest MultipleF

genProductRequest :: MonadGen m => m ProductRequest
genProductRequest = ProductRequest <$> genProductId

data ProductDbRequest = ProductDbRequest {_pdrQuery :: Text}
makeLenses ''ProductDbRequest
deriveToJSON 'ProductDbRequest MultipleF

genProductDbRequest :: ProductId -> ProductDbRequest
genProductDbRequest (ProductId pId) = ProductDbRequest $
  "select * from products where products.product_id = " <> show pId

data ProductDbReply = ProductDbReply
  { _pdrepData :: Maybe ProductData
  , _pdrepStatus :: Status
  }
makeLenses ''ProductDbReply
deriveToJSON 'ProductDbReply MultipleF

genProductDbReply :: MonadGen m => ProductId -> m ProductDbReply
genProductDbReply pId = do
  s <- genStatus
  case s of
    Invalid -> pure $ ProductDbReply Nothing s
    Valid -> ProductDbReply <$> (Just <$> genProductData (Just pId)) <*> pure s

data LinkedProductsDbRequest = LinkedProductsDbRequest {_lpdrQuery :: Text}
makeLenses ''LinkedProductsDbRequest
deriveToJSON 'LinkedProductsDbRequest MultipleF

genLinkedProductsDbRequest :: ProductId -> LinkedProductsDbRequest
genLinkedProductsDbRequest (ProductId pId) = LinkedProductsDbRequest $
  "select * from products where products.linked_product = " <> show pId

data LinkedProductsDbReply = LinkedProductsDbReply
  { _lpdrepProducts :: [ProductData]
  , _lpdrepStatus :: Status
  }
makeLenses ''LinkedProductsDbReply
deriveToJSON 'LinkedProductsDbReply MultipleF

genLinkedProductsDbReply :: MonadGen m => m LinkedProductsDbReply
genLinkedProductsDbReply = do
  s <- genStatus
  case s of
    Invalid -> pure $ LinkedProductsDbReply [] s
    Valid -> LinkedProductsDbReply <$>
      (Gen.list (Range.constant 1 10) $ genProductData Nothing) <*>
      pure s

data CatalogRequest = CatalogRequest
deriveToJSON 'CatalogRequest MultipleF

data CatalogDbRequest = CatalogDbRequest {_cdrQuery :: Text}
makeLenses ''CatalogDbRequest
deriveToJSON 'CatalogDbRequest MultipleF

genCatalogDbRequest :: CatalogDbRequest
genCatalogDbRequest = CatalogDbRequest "select * from products"

data CatalogDbReply = CatalogDbReply
  { _cdrepProducts :: [ProductData]
  , _cdrepStatus :: Status
  }
makeLenses ''CatalogDbReply
deriveToJSON 'CatalogDbReply MultipleF

genCatalogDbReply :: MonadGen m => m CatalogDbReply
genCatalogDbReply = do
  s <- genStatus
  case s of
    Invalid -> pure $ CatalogDbReply [] s
    Valid -> CatalogDbReply <$>
      (Gen.list (Range.constant 1 100) $ genProductData Nothing) <*>
      pure s
