{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module UserSignupSpec (spec) where

import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.Wai.Test (SResponse)
import Network.HTTP.Types.Status (status200)
import Data.Aeson (object, (.=))
import qualified Data.ByteString.Char8 as BS
import Control.Monad.Logger (runStdoutLoggingT)
import Control.Monad.IO.Class (liftIO)
import Database.Persist.Postgresql (withPostgresqlPool, runSqlPersistMPool, deleteWhere, Filter)

import App
import Network.Wai (Application)
import Web.Scotty (scottyApp)

-- Helper to create test application with database cleanup
withTestApp :: (Application -> IO ()) -> IO ()
withTestApp action = do
    let connStr = "host=localhost dbname=haskell_api user=haskell_user password=haskell_pass"
    runStdoutLoggingT $ withPostgresqlPool (BS.pack connStr) 10 $ \pool -> liftIO $ do
        -- Run migrations
        runAppMigrations pool

        -- Clean up test data before each test
        runSqlPersistMPool (do
            deleteWhere ([] :: [Filter User])
            deleteWhere ([] :: [Filter Session])
            deleteWhere ([] :: [Filter Request])
            ) pool

        -- Create WAI application
        testApp <- scottyApp (app pool)

        -- Run the test action
        action testApp

spec :: Spec
spec = around withTestApp $ do
    describe "POST /user/signup" $ do
        it "should create a new user successfully" $ do
            let signupData = object [ "username" .= ("testuser" :: String)
                                    , "password" .= ("testpass123" :: String)
                                    ]

            post "/user/signup" signupData `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }

        it "should create multiple users with different usernames" $ do
            let user1 = object [ "username" .= ("user1" :: String)
                               , "password" .= ("pass1" :: String)
                               ]
            let user2 = object [ "username" .= ("user2" :: String)
                               , "password" .= ("pass2" :: String)
                               ]

            post "/user/signup" user1 `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }

            post "/user/signup" user2 `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }

        it "should handle signup with empty password" $ do
            let signupData = object [ "username" .= ("emptypassuser" :: String)
                                    , "password" .= ("" :: String)
                                    ]

            post "/user/signup" signupData `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }

        it "should handle signup with special characters in username" $ do
            let signupData = object [ "username" .= ("test@user.com" :: String)
                                    , "password" .= ("securepass" :: String)
                                    ]

            post "/user/signup" signupData `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }

        it "should handle signup with long password" $ do
            let longPassword = replicate 100 'a'
            let signupData = object [ "username" .= ("longpassuser" :: String)
                                    , "password" .= longPassword
                                    ]

            post "/user/signup" signupData `shouldRespondWith`
                [json|{"message": "User created successfully"}|]
                { matchStatus = 200 }
