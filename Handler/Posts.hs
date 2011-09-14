{-# LANGUAGE TemplateHaskell, QuasiQuotes, OverloadedStrings #-}
module Handler.Posts where

import Foundation
import StandardLayout
import Data.Text (Text)
import Control.Applicative ((<*>), (<$>))
import Yesod.Goodies.Markdown
import Yesod.Goodies.Shorten
import Data.Time (getCurrentTime)


getPostsR :: Int -> Handler RepHtml
getPostsR offset = do
    let numShown = 10
    posts <- runDB $ selectList [] [LimitTo numShown, OffsetBy offset, Desc PostCreated]
    standardLayout $ do
        setDtekTitle "Gamla inlägg"
        addWidget $(widgetFile "posts")

getPostR :: Text -> Handler RepHtml
getPostR slug = do
    mpost <- runDB $ selectFirst [PostSlug ==. slug] []
    standardLayout $ do
        setDtekTitle "Specifikt inlägg"

postPostR :: Text -> Handler RepHtml
postPostR = getPostR

getManagePostsR :: Handler RepHtml
getManagePostsR = do
    (uid, _) <- requireEditor
    posts <- runDB $ selectList [] [Desc PostCreated]
    defaultLayout $ do
        setDtekTitle "Administrera inlägg"
        let postslist = $(widgetFile "postslist")
        addWidget $(widgetFile "manage")

postManagePostsR :: Handler RepHtml
postManagePostsR = getManagePostsR

getEditPostR :: Text -> Handler RepHtml
getEditPostR slug = do
    (uid, _) <- requireEditor
    mpost <- runDB $ selectFirst [PostSlug ==. slug] []
    defaultLayout $ do
        setDtekTitle "Redigera inlägg"
        addWidget $(widgetFile "editpost")

postEditPostR :: Text -> Handler RepHtml
postEditPostR = getEditPostR

getDelPostR :: Text -> Handler RepHtml
getDelPostR slug = do
    requireEditor
    p <- runDB $ getBy $ UniquePost slug
    case p of
        Just (key, _) -> do
            runDB $ delete key
            setMessage "Inlägg raderat!"
        Nothing -> setMessage "Inlägg ej funnet."
    redirect RedirectTemporary ManagePostsR


-----------------------------------------
--- Useful helpers
-----------------------------------------
data PostEditForm = PostEditForm
    { formSlug   :: Text
    , formTitle  :: Text
    , formTeaser :: Markdown
    , formBody   :: Markdown
    , formSumem  :: Bool
    }

runPostForm :: Maybe Post -> UserId -> Widget
runPostForm mpost uid = do
    ((res, form), enctype) <- lift $ runFormPost $ postForm mpost
    case res of
        FormSuccess pf -> lift $ processFormResult pf
        _ -> return ()

    [whamlet|
        <div .post_input>
            <form enctype="#{enctype}" method="post">
                <table>
                    ^{form}
                    <tr>
                        <td>&nbsp;
                        <td .buttons>
                            $maybe _ <- mpost
                                <input type="submit" value="Update">
                            $nothing
                                <input type="submit" value="Create">
        |]

    where
        processFormResult :: PostEditForm -> Handler ()
        processFormResult pf = do
            p <- postFromForm pf
            result <- runDB $ insertBy p
            case result of
                Right k -> do
                    -- post was inserted
                    setMessage "Inlägg skapad!"
                Left (k, _) -> do
                    -- post exists, update
                    updatePost k p
                    setMessage "Inlägg uppdaterat!"
            redirect RedirectTemporary ManagePostsR

        postFromForm :: PostEditForm -> Handler Post
        postFromForm pf = do
            now <- liftIO getCurrentTime
            return Post
                { postSlug        = formSlug pf
                , postTitle       = formTitle pf
                , postTeaser      = formTeaser pf
                , postBody        = formBody pf
                , postSumem       = formSumem pf
                , postCreator     = uid
                , postCreated     = now
                , postEditor      = uid
                , postEdited      = now
                }

        updatePost :: PostId -> Post -> Handler ()
        updatePost key new = do
            now <- liftIO getCurrentTime
            runDB $ update key
                [ PostSlug       =. postSlug new
                , PostTitle      =. postTitle new
                , PostTeaser     =. postTeaser new
                , PostBody       =. postBody new
                , PostSumem      =. postSumem new
                , PostEditor     =. uid
                , PostEdited     =. now
                ]


-- | Display the new post form inself. If the first argument is Just,
-- then use that to prepopulate the form
postForm :: Maybe Post -> Html -> Form Dtek Dtek (FormResult PostEditForm, Widget)
postForm mpost = renderTable $ PostEditForm
    <$> areq textField     fsSlug     (fmap postSlug   mpost)
    <*> areq textField     "Titel"    (fmap postTitle  mpost)
    <*> areq markdownField fsTeaser   (fmap postTeaser mpost)
    <*> areq markdownField "Brödtext" (fmap postBody   mpost)
    <*> areq boolField     fsSumem    (fmap postSumem  mpost)
  where
    fsSlug   = "Slugen"     {fsTooltip = Just "Om titeln är  \"Hacke hackspett\" bör slugen va \"hacke-hackspett\". Slugen är en unik nyckel"}
    fsTeaser = "Teaser"     {fsTooltip = Just "Sammanfattningen som visas på t.ex. förstasidan"}
    fsSumem  = "Konkatenera"{fsTooltip = Just "Låt innehållet vara teaser+brödtext. Annars är innehållet bara brödtexten"}