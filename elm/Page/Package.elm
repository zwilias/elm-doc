module Page.Package exposing (Model, Msg, init, update, view)

import Browser.Navigation
import Dict exposing (Dict)
import Elm.Docs
import Elm.Module
import Elm.Package
import Elm.Project
import Elm.Type
import Elm.Version
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown
import Page.Block as Block
import Route


type Model
    = Model
        { name : String
        , version : Elm.Version.Version
        , readme : RemoteData String
        , pkgInfo : RemoteData Elm.Project.PackageInfo
        , docs : RemoteData (Dict String Elm.Docs.Module)
        , currentModule : Maybe String
        }


type RemoteData data
    = Loading
    | Loaded data
    | Error Http.Error


fromResult : Result Http.Error data -> RemoteData data
fromResult res =
    case res of
        Err e ->
            Error e

        Ok v ->
            Loaded v


type Msg
    = GotReadme (RemoteData String)
    | GotPkgInfo (RemoteData Elm.Project.PackageInfo)
    | GotDocs (RemoteData (Dict String Elm.Docs.Module))
    | GotoUrl String


init : String -> Elm.Version.Version -> Maybe String -> ( Model, Cmd Msg )
init name version currentModule =
    ( Model
        { name = name
        , version = version
        , readme = Loading
        , pkgInfo = Loading
        , docs = Loading
        , currentModule = currentModule
        }
    , Cmd.batch
        [ loadReadme name version
        , loadPkgInfo name version
        , loadDocs name version
        ]
    )


loadReadme : String -> Elm.Version.Version -> Cmd Msg
loadReadme name version =
    Http.get
        { url = "/~docs/" ++ name ++ "/" ++ Elm.Version.toString version ++ "/README.md"
        , expect = Http.expectString (GotReadme << fromResult)
        }


loadPkgInfo : String -> Elm.Version.Version -> Cmd Msg
loadPkgInfo name version =
    Http.get
        { url = "/~docs/" ++ name ++ "/" ++ Elm.Version.toString version ++ "/elm.json"
        , expect = Http.expectJson (GotPkgInfo << fromResult) packageInfoDecoder
        }


loadDocs : String -> Elm.Version.Version -> Cmd Msg
loadDocs name version =
    Http.get
        { url = "/~docs/" ++ name ++ "/" ++ Elm.Version.toString version ++ "/docs.json"
        , expect = Http.expectJson (GotDocs << fromResult) docsDecoder
        }


docsDecoder : Decoder (Dict String Elm.Docs.Module)
docsDecoder =
    Decode.map (List.map (\d -> ( d.name, d )) >> Dict.fromList) (Decode.list Elm.Docs.decoder)


packageInfoDecoder : Decoder Elm.Project.PackageInfo
packageInfoDecoder =
    Decode.andThen
        (\projectInfo ->
            case projectInfo of
                Elm.Project.Package info ->
                    Decode.succeed info

                _ ->
                    Decode.fail "Expected package info"
        )
        Elm.Project.decoder


update : Browser.Navigation.Key -> Msg -> Model -> ( Model, Cmd Msg )
update key msg ((Model data) as model) =
    case msg of
        GotReadme readme ->
            ( Model { data | readme = readme }, Cmd.none )

        GotPkgInfo pkgInfo ->
            ( Model { data | pkgInfo = pkgInfo }, Cmd.none )

        GotDocs docs ->
            ( Model { data | docs = docs }, Cmd.none )

        GotoUrl url ->
            ( model
            , Browser.Navigation.pushUrl key url
            )


view : Elm.Project.ApplicationInfo -> Model -> List (Html Msg)
view project model =
    [ Html.div [ Attr.class "package-page" ]
        [ viewSidebar project model
        , Html.div [ Attr.class "page-content" ] (viewContent model)
        ]
    ]


viewContent : Model -> List (Html Msg)
viewContent ((Model data) as model) =
    case data.currentModule of
        Nothing ->
            viewPackageOverview model

        Just currentModule ->
            viewModuleDocs currentModule model


viewPackageOverview : Model -> List (Html Msg)
viewPackageOverview ((Model data) as model) =
    [ viewReadme data.readme ]


viewModuleDocs : String -> Model -> List (Html Msg)
viewModuleDocs currentModule (Model data) =
    case data.docs of
        Loading ->
            [ Html.text "Loading..." ]

        Error e ->
            [ Html.text "Oh noes!" ]

        Loaded docs ->
            let
                info =
                    Block.makeInfo data.name data.version currentModule (Dict.values docs)
            in
            docs
                |> Dict.get currentModule
                |> Maybe.map (viewModule info)
                |> Maybe.withDefault [ Html.text "unknown module" ]


viewSidebar : Elm.Project.ApplicationInfo -> Model -> Html Msg
viewSidebar project ((Model data) as model) =
    Html.div
        [ Attr.class "sidebar" ]
        [ viewQuickNav project data.name
        , Html.p []
            [ Html.a
                [ Attr.href ("/" ++ data.name ++ "/" ++ Elm.Version.toString data.version) ]
                [ Html.text "README" ]
            ]
        , viewPkgInfo model data.pkgInfo
        ]


viewQuickNav : Elm.Project.ApplicationInfo -> String -> Html Msg
viewQuickNav project currentPackage =
    Html.select [ Events.on "change" (Decode.map GotoUrl Events.targetValue) ]
        (List.map (quickNavOption currentPackage) project.depsDirect)


quickNavOption : String -> ( Elm.Package.Name, Elm.Version.Version ) -> Html msg
quickNavOption self ( package, version ) =
    let
        url =
            "/" ++ Elm.Package.toString package ++ "/" ++ Elm.Version.toString version
    in
    Html.option
        [ Attr.selected (self == Elm.Package.toString package)
        , Attr.value url
        ]
        [ Html.text (Elm.Package.toString package)
        , Html.text " "
        , Html.text (Elm.Version.toString version)
        ]


viewModule : Block.Info -> Elm.Docs.Module -> List (Html Msg)
viewModule info currentModule =
    currentModule
        |> Elm.Docs.toBlocks
        |> List.map (Block.view info)


viewPkgInfo : Model -> RemoteData Elm.Project.PackageInfo -> Html msg
viewPkgInfo model data =
    case data of
        Loading ->
            Html.text "Loading..."

        Error e ->
            Html.text "Oh noes!"

        Loaded v ->
            viewExposed model v.exposed


viewExposed : Model -> Elm.Project.Exposed -> Html msg
viewExposed model exposed =
    case exposed of
        Elm.Project.ExposedList items ->
            items
                |> List.map (showItem model)
                |> Html.ul []

        Elm.Project.ExposedDict nestedItems ->
            nestedItems
                |> List.map (showNestedItem model)
                |> Html.ul []


showNestedItem : Model -> ( String, List Elm.Module.Name ) -> Html msg
showNestedItem model ( name, items ) =
    Html.li []
        [ Html.text name
        , Html.ul [] (List.map (showItem model) items)
        ]


showItem : Model -> Elm.Module.Name -> Html msg
showItem (Model data) name =
    Html.li []
        [ Html.a
            [ Route.href
                (Route.PackagePage
                    data.name
                    data.version
                    (Just (Elm.Module.toString name))
                )
            ]
            [ Html.text (Elm.Module.toString name) ]
        ]


viewReadme : RemoteData String -> Html msg
viewReadme data =
    case data of
        Loading ->
            Html.text "Loading..."

        Error e ->
            Html.text "Failed to load readme!"

        Loaded readme ->
            Markdown.toHtml [] readme
