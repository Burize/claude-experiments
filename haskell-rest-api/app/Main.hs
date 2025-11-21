{-# LANGUAGE OverloadedStrings #-}

-- Main module for our REST API
module Main where

-- Import Scotty web framework
import Web.Scotty

-- Import for JSON encoding
import Data.Aeson (object, (.=))

-- Import for text handling
import qualified Data.Text.Lazy as TL

-- Import for random generation
import System.Random

-- Main entry point
main :: IO ()
main = do
    putStrLn "Starting Haskell REST API server on port 3000..."
    putStrLn "Try: curl http://localhost:3000/api/strings"

    -- Start Scotty web server on port 3000
    scotty 3000 $ do
        -- Define a GET route at /api/strings
        get "/api/strings" $ do
            -- Generate random strings
            randomStrings <- liftAndCatchIO generateRandomStrings

            -- Return JSON response
            json $ object [ "strings" .= randomStrings ]

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
