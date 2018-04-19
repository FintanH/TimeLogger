{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses      #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE QuasiQuotes                #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

module Main where

import           Control.Concurrent
import           Control.Monad.IO.Class                (liftIO)
import           Control.Monad.Logger
import           Control.Monad.Trans.Reader
import           Control.Monad.Trans.Resource.Internal
import           Data.Function
import           Data.List
import           Data.Text                             (Text)
import           Data.Time.Clock
import           Database.Esqueleto
import           Database.Persist
import           Database.Persist.Sqlite               (runMigration, runSqlite)
import           Database.Persist.TH                   (mkMigrate, mkPersist,
                                                        persistLowerCase, share,
                                                        sqlSettings)
import           Debug.Trace
import           Graphics.X11
import           Graphics.X11.Xlib.Extras

share [mkPersist sqlSettings, mkMigrate "migrateTables"] [persistLowerCase|
LogItem
   title    Text
   begin    UTCTime
   end      UTCTime
   deriving Show
|]

runDB :: ReaderT SqlBackend (NoLoggingT (ResourceT IO)) a -> IO a
runDB = runSqlite "db.sqlite"

main :: IO ()
main =
  runDB $ do
    runMigration migrateTables

    liftIO $ do
      d <- openDisplay ""
      loop d

loop :: Display -> IO ()
loop d = do
  time <- getCurrentTime
  (w, _) <- getInputFocus d
  a <- internAtom d "_NET_WM_NAME" False
  p <- getTextProperty d w a
  currentWindowTitle <- wcTextPropertyToTextList d p
  runDB $ do
    previousLogItem <- select $ from $ \l -> do
            orderBy [desc (l ^. LogItemId)]
            limit 1
            return (l ^. LogItemTitle)
    liftIO $ print previousLogItem
      -- if title changed then add new row else update `end`
      -- if (currentWindowTitle == "") then return ()
      -- print previousLogItem
  threadDelay 1000000
  loop d
