{-# LANGUAGE BangPatterns      #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

------------------------------------------------------------------------------
import           Blaze.ByteString.Builder
import           Criterion
import           Criterion.Main
import           Criterion.Measurement hiding (getTime)
import           Control.Concurrent
import           Control.Error
import           Control.Exception (evaluate)
import           Control.Monad
import qualified Data.ByteString as B
import qualified Data.DList as DL
import qualified Data.Text as T
import           Data.Text.Encoding
import           Data.Time.Clock
import           Data.Maybe
import qualified Text.XmlHtml as X
import           System.Environment

import Heist
import Heist.Common
import qualified Heist.Compiled as C
import qualified Heist.Compiled.Internal as CI
import qualified Heist.Interpreted as I
import Heist.TestCommon
import Heist.Types

loadWithCache baseDir = do
    etm <- runEitherT $ do
        let hc = HeistConfig [] defaultLoadTimeSplices [] [] [loadTemplates baseDir]
        initHeistWithCacheTag hc
    either (error . unlines) (return . fst) etm

main = do
    (dir:file:_) <- getArgs
    applyComparison dir file

justRender dir = do
    let page = "faq"
        pageStr = T.unpack $ decodeUtf8 page
    hs <- loadWithCache dir
    let !compiledTemplate = fst $! fromJust $! C.renderTemplate hs page
        compiledAction = do
            res <- compiledTemplate
            return $! toByteString $! res
    out <- compiledAction
    putStrLn $ "Rendered ByteString of length "++(show $ B.length out)
    B.writeFile (pageStr++".out.compiled."++dir) $ out

    defaultMain
       [ bench (pageStr++"-compiled (just render)") (whnfIO compiledAction)
       ]

------------------------------------------------------------------------------
applyComparison :: FilePath -> String -> IO ()
applyComparison dir pageStr = do
    let page = encodeUtf8 $ T.pack pageStr
    hs <- loadWithCache dir
    let compiledAction = do
            res <- fst $ fromJust $ C.renderTemplate hs page
            return $! toByteString $! res
    out <- compiledAction
    B.writeFile (pageStr++".out.compiled."++dir) $ out

    let interpretedAction = do
            res <- I.renderTemplate hs page
            return $! toByteString $! fst $! fromJust res
    out2 <- interpretedAction
    B.writeFile (pageStr++".out.interpreted."++dir) $ out

    defaultMain
       [ bench (pageStr++"-compiled") (whnfIO compiledAction)
       , bench (pageStr++"-interpreted") (whnfIO interpretedAction)
       ]

cmdLineTemplate :: String -> String -> IO ()
cmdLineTemplate dir page = do
--    args <- getArgs
--    let page = head args
--    let dir = "test/snap-website"
    hs <- loadHS dir
    let action = fst $ fromJust $ C.renderTemplate hs
            (encodeUtf8 $ T.pack page)
    out <- action
    B.writeFile (page++".out.cur") $ toByteString out

--    reference <- B.readFile "faq.out"
--    if False
--      then do
--        putStrLn "Template didn't render properly"
--        error "Aborting"
--      else
--        putStrLn "Template rendered correctly"

    defaultMain [
         bench (page++"-speed") action
       ]


testNode =
  X.Element "div" [("foo", "aoeu"), ("bar", "euid")] 
    [X.Element "b" [] [X.TextNode "bolded text"]
    ,X.TextNode " not bolded"
    ,X.Element "a" [("href", "/path/to/page")] [X.TextNode "link"]
    ]

getChunks templateName = do
    hs <- loadHS "snap-website-nocache"
    let (Just t) = lookupTemplate templateName hs _compiledTemplateMap
    return $! fst $! fst t

