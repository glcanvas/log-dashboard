module Main 
  ( main
  ) where

import Universum

import RIO.Orphans ()

import Generator.Setup (runGenerator)
import Generator.Runner (runner)

main :: IO ()
main = runGenerator runner