module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Elm.Project
import Html exposing (Html)
import Json.Decode as Json
import Page.Home
import Page.Package
import Route exposing (Route)
import Url exposing (Url)


type alias Model =
    { project : Maybe Elm.Project.Project
    , navKey : Nav.Key
    , page : Page
    , currentRoute : Route
    }


type Page
    = HomePage
    | NotFoundPage
    | PackagePage Page.Package.Model


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | PackagePageMsg Page.Package.Msg


init : Json.Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    { project = parseFlags flags
    , navKey = navKey
    , page = HomePage
    , currentRoute = Route.NotFound
    }
        |> changePage (Route.route url)


changePage : Route -> Model -> ( Model, Cmd Msg )
changePage route model =
    if model.currentRoute == route then
        ( model, Cmd.none )

    else
        case route of
            Route.Home ->
                ( { model | page = HomePage, currentRoute = route }, Cmd.none )

            Route.NotFound ->
                ( { model | page = NotFoundPage, currentRoute = route }, Cmd.none )

            Route.PackagePage name version currentModule ->
                let
                    ( page, cmds ) =
                        Page.Package.init name version currentModule
                in
                ( { model | page = PackagePage page, currentRoute = route }
                , Cmd.map PackagePageMsg cmds
                )


parseFlags : Json.Value -> Maybe Elm.Project.Project
parseFlags =
    Json.decodeValue Elm.Project.decoder >> Result.toMaybe


main : Program Json.Value Model Msg
main =
    Browser.application
        { init = init
        , view = appView
        , update = update
        , subscriptions = always Sub.none
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested (Browser.Internal url) ->
            ( model
            , Nav.pushUrl model.navKey (Url.toString url)
            )

        UrlRequested (Browser.External url) ->
            ( model
            , Nav.load url
            )

        UrlChanged newUrl ->
            changePage (Route.route newUrl) model

        PackagePageMsg pageMsg ->
            case model.page of
                PackagePage pkgPage ->
                    let
                        ( page, cmds ) =
                            Page.Package.update pageMsg pkgPage
                    in
                    ( { model | page = PackagePage page }
                    , Cmd.map PackagePageMsg cmds
                    )

                _ ->
                    ( model, Cmd.none )


appView : Model -> Browser.Document Msg
appView model =
    model.project
        |> Maybe.map (viewCurrentPage model.page)
        |> Maybe.withDefault viewInvalidElmJson


viewInvalidElmJson : Browser.Document msg
viewInvalidElmJson =
    { title = "Invalid elm.json - elm-doc"
    , body = [ Html.text "Failed to parse your elm.json." ]
    }


viewCurrentPage : Page -> Elm.Project.Project -> Browser.Document Msg
viewCurrentPage page project =
    case page of
        HomePage ->
            { title = "elm-doc"
            , body = Page.Home.view project
            }

        PackagePage pkgPage ->
            { title = "elm-doc"
            , body = Page.Package.view pkgPage |> List.map (Html.map PackagePageMsg)
            }

        _ ->
            { title = "Page not found - elm-doc"
            , body = [ Html.text "That page doesn't exist!" ]
            }
