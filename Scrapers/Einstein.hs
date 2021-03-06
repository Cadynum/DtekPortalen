{-# LANGUAGE OverloadedStrings #-}
module Scrapers.Einstein (
     scrapEinstein
   , EinsteinScrapResult
   ) where

import Prelude
import Helpers.Scraping (openUrl)
import Text.HTML.TagSoup
import Data.List.Split (chunksOf)
import Control.Monad (guard, liftM2)
import Data.Char (isNumber)
import Data.Maybe (listToMaybe)
import Control.Monad (msum)
import qualified Data.Text as T

-- I use tag soup as it apperently fixes unicode characters
type EinsteinScrapResult = Maybe (Int, [[String]])

scrapEinstein :: IO EinsteinScrapResult
scrapEinstein = do
    let urls = ["http://www.butlercatering.se/" ++ x | x <- ["", "Lunchmeny"]]
    fmap (msum . map parse) $ mapM openUrl urls

printMenuToStdout :: IO ()
printMenuToStdout = do
    Just (week, sss) <- scrapEinstein
    putStrLn $ "\nVecka " ++ show week ++ ":"
    mapM_ (putStrLn . unlines) sss

parse :: String -> Maybe (Int, [[String]])
parse body = liftM2 (,) mweek mmenu
  where
    tags = parseTags body
    goodContents = filter (elem '•') [ s | TagText s <- tags ]
    cleanContents = map (dropWhile (`elem` " •\n\r")) goodContents
    splitted = chunksOf 3 cleanContents
    mmenu = guard (map length splitted == [3, 3, 3, 3, 3]) >> Just splitted
    textNum = T.takeWhile isNumber $ snd $ T.breakOnEnd "Meny V " (T.pack body)
    mweek = fmap fst $ listToMaybe $ reads $ T.unpack textNum
