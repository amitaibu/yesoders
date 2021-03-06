module Handler.UserUpdate where

import Import
import Model.Types
import Utils.LocalTasks

getUserUpdateR :: Text -> Handler Html
getUserUpdateR ident = do
    (Entity _ user) <- runDB . getBy404 $ UniqueUser ident

    mcurrentUser <- maybeAuth

    mlocalTasks <- getLocalTasksWidget
            [ ("View", UserR ident)
            , ("Edit", UserUpdateR ident)
            ]

    (widget, enctype) <- generateFormPost $ userForm ident user mcurrentUser
    defaultLayout $(widgetFile "user-update")

postUserUpdateR :: Text -> Handler Html
postUserUpdateR ident = do
    (Entity userId user) <- runDB . getBy404 $ UniqueUser ident

    mcurrentUser <- maybeAuth

    ((result, widget), enctype) <- runFormPost $ userForm ident user mcurrentUser
    case result of
        FormSuccess user' -> do
            _ <- runDB $ replace userId user'

            setMessage "User saved"
            redirect $ UserR ident
        _ -> defaultLayout
            [whamlet|
                <p>Invalid input, let's try again.
                <form method=post action=@{UserUpdateR ident} enctype=#{enctype}>
                    ^{widget}
                    <button>Submit
            |]


userForm :: Text -> User -> Maybe (Entity User) -> Form User
userForm ident user mcurrentUser = renderSematnicUiDivs $ User
    <$> pure ident
    <*> pure (userEmail user)
    <*> aopt textField "Full name" (Just $ userFullName user)
    <*> aopt textareaField "Description" (Just $ userDesc user)
    <*> adminCheckBox (areq checkBoxField "Admin" (Just $ userAdmin user)) (userAdmin user)
    <*> areq (selectFieldList empOpts) (selectSettings "Employment") (Just $ userEmployment user)
    <*> adminCheckBox (areq checkBoxField "Blocked"  (Just $ userBlocked user)) (userBlocked user)
    <*> areq checkBoxField "Public email"  (Just $ userEmailPublic user)
    <*> pure (userCreated user)
    where
        adminCheckBox field val =
            case mcurrentUser of
                Nothing -> pure val
                Just (Entity _ currentUser) ->
                        if (userAdmin currentUser)
                            then
                                -- Don't allow user to remove own admin rights.
                                if (userIdent currentUser == userIdent user)
                                    then
                                        pure val
                                    else
                                        field
                            else
                                pure val

        empOpts = map (pack . prettyEmployment &&& id) [minBound..maxBound] :: [(Text, Employment)]
        selectSettings label =
            FieldSettings
                { fsLabel = label
                , fsTooltip = Nothing
                , fsId = Nothing
                , fsName = Nothing
                , fsAttrs = [("class", "ui fluid dropdown")]
                }
