{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module UserMeSpec (spec) where

import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.Wai.Test (SResponse, simpleBody)
import Network.HTTP.Types.Status (status200, status401)
import Network.HTTP.Types.Header (hAuthorization)
import Data.Aeson (object, (.=), decode, Value(..))
import qualified Data.Aeson.KeyMap as KM
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy as LBS
import qualified Data.Text as T
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

-- Helper to extract session token from signin response
extractSessionToken :: SResponse -> IO (Maybe String)
extractSessionToken response = do
    let body = simpleBody response
    let maybeJson = decode body :: Maybe Value
    return $ case maybeJson of
        Just (Object obj) -> case KM.lookup "sessionToken" obj of
            Just (String token) -> Just (T.unpack token)
            _ -> Nothing
        _ -> Nothing

spec :: Spec
spec = around withTestApp $ do
    describe "GET /user/me" $ do
        it "should return user ID when authenticated with valid token" $ do
            -- Sign up a user
            let signupData = object [ "username" .= ("meuser" :: String)
                                    , "password" .= ("mepass" :: String)
                                    ]
            _ <- post "/user/signup" signupData

            -- Sign in to get session token
            let signinData = object [ "username" .= ("meuser" :: String)
                                    , "password" .= ("mepass" :: String)
                                    ]
            signinResponse <- post "/user/signin" signinData

            maybeToken <- liftIO $ extractSessionToken signinResponse

            case maybeToken of
                Just token -> do
                    -- Make request to /user/me with the session token
                    response <- request "GET" "/user/me" [(hAuthorization, BS.pack token)] ""

                    liftIO $ do
                        -- Verify status is 200
                        simpleStatus response `shouldBe` status200

                        -- Verify response contains userId
                        let body = simpleBody response
                        let maybeJson = decode body :: Maybe Value
                        case maybeJson of
                            Just (Object obj) -> do
                                -- Verify userId field exists
                                KM.member "userId" obj `shouldBe` True
                            _ -> expectationFailure "Response is not a valid JSON object"

                Nothing -> liftIO $ expectationFailure "Failed to extract session token from signin response"

        it "should return 401 when no Authorization header is provided" $ do
            get "/user/me" `shouldRespondWith`
                [json|{"error": "No session token provided"}|]
                { matchStatus = 401 }

        it "should return 401 when Authorization header contains invalid token" $ do
            let invalidToken = "invalid-token-12345"
            request "GET" "/user/me" [(hAuthorization, BS.pack invalidToken)] "" `shouldRespondWith`
                [json|{"error": "Invalid or expired session token"}|]
                { matchStatus = 401 }

        it "should return 401 when Authorization header is empty" $ do
            request "GET" "/user/me" [(hAuthorization, "")] "" `shouldRespondWith`
                [json|{"error": "Invalid or expired session token"}|]
                { matchStatus = 401 }

        it "should work for different users with different tokens" $ do
            -- Create first user
            let user1Signup = object [ "username" .= ("user1" :: String)
                                     , "password" .= ("pass1" :: String)
                                     ]
            _ <- post "/user/signup" user1Signup

            let user1Signin = object [ "username" .= ("user1" :: String)
                                     , "password" .= ("pass1" :: String)
                                     ]
            user1SigninResponse <- post "/user/signin" user1Signin
            maybeToken1 <- liftIO $ extractSessionToken user1SigninResponse

            -- Create second user
            let user2Signup = object [ "username" .= ("user2" :: String)
                                     , "password" .= ("pass2" :: String)
                                     ]
            _ <- post "/user/signup" user2Signup

            let user2Signin = object [ "username" .= ("user2" :: String)
                                     , "password" .= ("pass2" :: String)
                                     ]
            user2SigninResponse <- post "/user/signin" user2Signin
            maybeToken2 <- liftIO $ extractSessionToken user2SigninResponse

            -- Verify both tokens work
            case (maybeToken1, maybeToken2) of
                (Just token1, Just token2) -> do
                    response1 <- request "GET" "/user/me" [(hAuthorization, BS.pack token1)] ""
                    response2 <- request "GET" "/user/me" [(hAuthorization, BS.pack token2)] ""

                    liftIO $ do
                        simpleStatus response1 `shouldBe` status200
                        simpleStatus response2 `shouldBe` status200

                        -- Verify they return different user IDs
                        let body1 = simpleBody response1
                        let body2 = simpleBody response2
                        body1 `shouldNotBe` body2

                _ -> liftIO $ expectationFailure "Failed to extract session tokens"

        it "should persist session across multiple requests" $ do
            -- Sign up and sign in
            let signupData = object [ "username" .= ("persistuser" :: String)
                                    , "password" .= ("persistpass" :: String)
                                    ]
            _ <- post "/user/signup" signupData

            let signinData = object [ "username" .= ("persistuser" :: String)
                                    , "password" .= ("persistpass" :: String)
                                    ]
            signinResponse <- post "/user/signin" signinData
            maybeToken <- liftIO $ extractSessionToken signinResponse

            case maybeToken of
                Just token -> do
                    -- Make multiple requests with the same token
                    response1 <- request "GET" "/user/me" [(hAuthorization, BS.pack token)] ""
                    response2 <- request "GET" "/user/me" [(hAuthorization, BS.pack token)] ""
                    response3 <- request "GET" "/user/me" [(hAuthorization, BS.pack token)] ""

                    liftIO $ do
                        simpleStatus response1 `shouldBe` status200
                        simpleStatus response2 `shouldBe` status200
                        simpleStatus response3 `shouldBe` status200

                        -- All responses should be identical
                        let body1 = simpleBody response1
                        let body2 = simpleBody response2
                        let body3 = simpleBody response3
                        body1 `shouldBe` body2
                        body2 `shouldBe` body3

                Nothing -> liftIO $ expectationFailure "Failed to extract session token"
