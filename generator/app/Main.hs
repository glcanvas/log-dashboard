module Main 
  ( main
  ) where

import Universum

import RIO.Orphans ()
import Options.Applicative (execParser, fullDesc, helper, info, progDesc)

import Generator.Setup (runGenerator)
import Generator.Runner (runner)
import Generator.Config.Reading (configPathsParser, readConfigs)

main :: IO ()
main = do
  configPaths <- execParser $
    info (helper <*> configPathsParser) $
    fullDesc <> progDesc "Generator"
  config <- readConfigs configPaths
  runGenerator config runner