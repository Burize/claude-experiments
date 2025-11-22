{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}

-- Main module for our REST API
module Main where

-- Import Scotty web framework
import Web.Scotty

-- Import HTTP status codes
import Network.HTTP.Types.Status (status200)

-- Import for JSON encoding and decoding
import Data.Aeson (FromJSON, ToJSON, object, (.=))

-- Import for automatic JSON deriving
import GHC.Generics

-- Import for text handling
import qualified Data.Text.Lazy as TL
import qualified Data.Text as T

-- Import for random generation
import System.Random

-- Import Persistent libraries
import Database.Persist hiding (get)
import Database.Persist.Postgresql hiding (get)
import Database.Persist.TH
import Control.Monad.Logger (runStdoutLoggingT, LoggingT)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Resource (runResourceT, ResourceT)
import qualified Data.ByteString.Char8 as BS

-- Define database schema using Persistent
-- This uses Template Haskell to generate database types and functions
share [mkPersist sqlSettings, mkMigrate "migrateAll"] [persistLowerCase|
Request
    item String
    deriving Show

User
    username String
    password String
    deriving Show
|]

-- Main entry point
main :: IO ()
main = do
    putStrLn "Starting Haskell REST API server on port 3000..."

    -- Connection string for PostgreSQL
    let connStr = "host=localhost dbname=haskell_api user=haskell_user password=haskell_pass"

    -- Run migrations and start server
    runStdoutLoggingT $ withPostgresqlPool (BS.pack connStr) 10 $ \pool -> liftIO $ do
        -- Run database migrations using Persistent
        putStrLn "Running database migrations with Persistent..."
        runAppMigrations pool

        putStrLn "Server ready!"
        putStrLn "GET endpoint: curl http://localhost:3000/api/strings"
        putStrLn "POST endpoint: curl -X POST http://localhost:3000/api/items -H 'Content-Type: application/json' -d '{\"item\":\"test\"}'"

        -- Start Scotty web server on port 3000
        scotty 3000 $ do
            -- Define a GET route at /api/strings
            get "/api/strings" $ do
                -- Generate random strings
                randomStrings <- liftIO generateRandomStrings

                -- Return JSON response
                json $ object [ "strings" .= randomStrings ]

            -- Define a POST route at /api/items
            post "/api/items" $ do
                -- Parse the JSON body
                itemRequest <- jsonData :: ActionM ItemRequest

                -- Log the received item to console
                liftIO $ putStrLn $ "Received item: " ++ item itemRequest

                -- Save to database using Persistent
                liftIO $ saveItemToDatabase pool (item itemRequest)

                -- Return 200 status with OK message
                status status200
                json $ object [ "message" .= ("OK" :: String) ]

-- Data type for POST request body
-- This represents the JSON structure: { "item": "some value" }
data ItemRequest = ItemRequest
    { item :: String  -- The item field from the JSON body
    } deriving (Show, Generic)

-- Automatically derive JSON parsing for ItemRequest
instance FromJSON ItemRequest
instance ToJSON ItemRequest

-- Function to generate a list of random strings
generateRandomStrings :: IO [String]
generateRandomStrings = do
    -- Create a random number generator
    gen <- getStdGen

    -- Generate 5 random strings
    let strings = take 5 $ generateInfiniteStrings gen

    return strings

-- Generate an infinite list of random strings (lazy evaluation!)
generateInfiniteStrings :: RandomGen g => g -> [String]
generateInfiniteStrings gen =
    let -- List of sample words to randomly select from
        words' = ["apple", "banana", "cherry", "dragon", "elephant",
                  "forest", "galaxy", "harmony", "island", "jungle",
                  "kitten", "lantern", "mountain", "nebula", "ocean",
                  "phoenix", "quasar", "rainbow", "sunset", "thunder"]

        -- Get the length of our word list
        wordCount = length words'

        -- Generate infinite list of random indices
        randomIndices = randomRs (0, wordCount - 1) gen

        -- Map indices to words
        randomWords = map (words' !!) randomIndices
    in randomWords

-- Run database migrations using Persistent
-- This automatically creates/updates the "request" table based on the schema
runAppMigrations :: ConnectionPool -> IO ()
runAppMigrations pool = do
    flip runSqlPersistMPool pool $ do
        -- Run the automatic migration from the schema definition
        runMigration migrateAll
    putStrLn "[OK] Database migration completed successfully with Persistent"

-- Save an item to the database using Persistent
saveItemToDatabase :: ConnectionPool -> String -> IO ()
saveItemToDatabase pool itemValue = do
    -- Insert a new Request entity into the database
    _ <- flip runSqlPersistMPool pool $ insert $ Request itemValue
    putStrLn $ "[OK] Saved to database: " ++ itemValue
