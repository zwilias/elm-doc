module Page.Package exposing (Model, Msg, init, update, view)

import Dict exposing (Dict)
import Elm.Docs
import Elm.Module
import Elm.Project
import Elm.Version
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Json.Decode as Json
import Markdown
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


docsDecoder : Json.Decoder (Dict String Elm.Docs.Module)
docsDecoder =
    Json.map (List.map (\d -> ( d.name, d )) >> Dict.fromList) (Json.list Elm.Docs.decoder)


packageInfoDecoder : Json.Decoder Elm.Project.PackageInfo
packageInfoDecoder =
    Json.andThen
        (\projectInfo ->
            case projectInfo of
                Elm.Project.Package info ->
                    Json.succeed info

                _ ->
                    Json.fail "Expected package info"
        )
        Elm.Project.decoder


update : Msg -> Model -> ( Model, Cmd Msg )
update msg (Model data) =
    case msg of
        GotReadme readme ->
            ( Model { data | readme = readme }, Cmd.none )

        GotPkgInfo pkgInfo ->
            ( Model { data | pkgInfo = pkgInfo }, Cmd.none )

        GotDocs docs ->
            ( Model { data | docs = docs }, Cmd.none )


view : Model -> List (Html Msg)
view ((Model data) as model) =
    case data.currentModule of
        Nothing ->
            viewPackageOverview model

        Just currentModule ->
            viewModuleDocs currentModule model


viewPackageOverview : Model -> List (Html Msg)
viewPackageOverview ((Model data) as model) =
    [ Html.text data.name
    , Html.text " "
    , Html.text (Elm.Version.toString data.version)
    , viewReadme data.readme
    , viewPkgInfo model data.pkgInfo
    ]


viewModuleDocs : String -> Model -> List (Html Msg)
viewModuleDocs currentModule (Model data) =
    case data.docs of
        Loading ->
            [ Html.text "Loading..." ]

        Error e ->
            [ Html.text "Oh noes!" ]

        Loaded docs ->
            docs
                |> Dict.get currentModule
                |> Maybe.map viewModule
                |> Maybe.withDefault [ Html.text "unknown module" ]


viewModule : Elm.Docs.Module -> List (Html Msg)
viewModule currentModule =
    currentModule
        |> Elm.Docs.toBlocks
        |> List.filterMap viewBlock


viewBlock : Elm.Docs.Block -> Maybe (Html msg)
viewBlock block =
    case block of
        Elm.Docs.MarkdownBlock mdBlock ->
            Just (Markdown.toHtml [] mdBlock)

        Elm.Docs.ValueBlock valueBlock ->
            Just (viewValueBlock valueBlock)

        _ ->
            Nothing


viewValueBlock : Elm.Docs.Value -> Html msg
viewValueBlock value =
    Html.div [ Attr.id value.name ]
        [ Html.div [ Attr.class "formatted" ]
            [ Html.a
                [ Attr.class "value", Attr.href ("#" ++ value.name) ]
                [ Html.text value.name ]
            ]
        ]


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
