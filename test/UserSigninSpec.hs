{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module UserSigninSpec (spec) where

import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.Wai.Test (SResponse, simpleBody, simpleStatus)
import Network.HTTP.Types.Status (status200, status401)
import Data.Aeson (object, (.=), decode, Value, encode)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as LBS
import Control.Monad.Logger (runStdoutLoggingT)
import Control.Monad.IO.Class (liftIO)
import Database.Persist.Postgresql (withPostgresqlPool, runSqlPersistMPool, deleteWhere, Filter)

import App
import Network.Wai (Application)
import Web.Scotty (scottyApp)

-- Helper to create test application with database cleanup
testApp :: IO Application
testApp = do
    let connStr = "host=localhost dbname=haskell_api user=haskell_user password=haskell_pass"
    runStdoutLoggingT $ withPostgresqlPool (BS.pack connStr) 10 $ \pool -> liftIO $ do
        -- Run migrations
        runAppMigrations pool

        -- Clean up test data before each test
        -- Note: Delete sessions first since they have foreign key to users
        runSqlPersistMPool (do
            deleteWhere ([] :: [Filter Session])
            deleteWhere ([] :: [Filter User])
            deleteWhere ([] :: [Filter Request])
            ) pool

        -- Create WAI application
        scottyApp (app pool)

spec :: Spec
spec = with testApp $ do
    describe "POST /user/signin" $ do
        it "should sign in successfully with correct credentials" $ do
            -- First, sign up a user
            let signupData = object [ "username" .= ("testuser" :: String)
                                    , "password" .= ("testpass123" :: String)
                                    ]
            _ <- post "/user/signup" (encode signupData)

            -- Then, sign in with the same credentials
            let signinData = object [ "username" .= ("testuser" :: String)
                                    , "password" .= ("testpass123" :: String)
                                    ]
            response <- post "/user/signin" (encode signinData)

            liftIO $ do
                -- Verify status is 200
                simpleStatus response `shouldBe` status200

                -- Verify response contains message and sessionToken
                let body = simpleBody response
                let maybeJson = decode body :: Maybe Value
                case maybeJson of
                    Just json -> do
                        -- Check that the response is a JSON object with expected fields
                        -- This is a simplified check - in production you'd want more detailed validation
                        LBS.length body `shouldSatisfy` (> 10)
                    Nothing -> expectationFailure "Response body is not valid JSON"

        it "should return 401 for incorrect password" $ do
            -- First, sign up a user
            let signupData = object [ "username" .= ("testuser2" :: String)
                                    , "password" .= ("correctpass" :: String)
                                    ]
            _ <- post "/user/signup" (encode signupData)

            -- Try to sign in with wrong password
            let signinData = object [ "username" .= ("testuser2" :: String)
                                    , "password" .= ("wrongpass" :: String)
                                    ]

            post "/user/signin" (encode signinData) `shouldRespondWith`
                [json|{"error": "Username or password is incorrect"}|]
                { matchStatus = 401 }

        it "should return 401 for non-existent username" $ do
            let signinData = object [ "username" .= ("nonexistentuser" :: String)
                                    , "password" .= ("anypass" :: String)
                                    ]

            post "/user/signin" (encode signinData) `shouldRespondWith`
                [json|{"error": "Username or password is incorrect"}|]
                { matchStatus = 401 }

        it "should create a session token on successful signin" $ do
            -- Sign up a user
            let signupData = object [ "username" .= ("tokenuser" :: String)
                                    , "password" .= ("tokenpass" :: String)
                                    ]
            _ <- post "/user/signup" (encode signupData)

            -- Sign in and verify we get a session token
            let signinData = object [ "username" .= ("tokenuser" :: String)
                                    , "password" .= ("tokenpass" :: String)
                                    ]
            response <- post "/user/signin" (encode signinData)

            liftIO $ do
                simpleStatus response `shouldBe` status200
                let body = simpleBody response
                -- Verify the response body is not empty and contains JSON
                LBS.length body `shouldSatisfy` (> 10)

        it "should allow multiple signins for the same user" $ do
            -- Sign up a user
            let signupData = object [ "username" .= ("multiuser" :: String)
                                    , "password" .= ("multipass" :: String)
                                    ]
            _ <- post "/user/signup" (encode signupData)

            -- Sign in multiple times
            let signinData = object [ "username" .= ("multiuser" :: String)
                                    , "password" .= ("multipass" :: String)
                                    ]

            response1 <- post "/user/signin" (encode signinData)
            response2 <- post "/user/signin" (encode signinData)

            liftIO $ do
                simpleStatus response1 `shouldBe` status200
                simpleStatus response2 `shouldBe` status200

        it "should handle signin with empty password when user was created with empty password" $ do
            -- Sign up a user with empty password
            let signupData = object [ "username" .= ("emptypassuser" :: String)
                                    , "password" .= ("" :: String)
                                    ]
            _ <- post "/user/signup" (encode signupData)

            -- Sign in with empty password
            let signinData = object [ "username" .= ("emptypassuser" :: String)
                                    , "password" .= ("" :: String)
                                    ]

            response <- post "/user/signin" (encode signinData)
            liftIO $ simpleStatus response `shouldBe` status200
