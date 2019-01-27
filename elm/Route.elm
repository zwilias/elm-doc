module Route exposing (Route(..), href, route)

import Elm.Version
import Html
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Parser exposing ((</>))


type Route
    = Home
    | NotFound
    | PackagePage String Elm.Version.Version (Maybe String)


urlParser : Url.Parser.Parser (Route -> a) a
urlParser =
    Url.Parser.oneOf
        [ Url.Parser.map Home Url.Parser.top
        , Url.Parser.map
            (\author name -> PackagePage (author ++ "/" ++ name))
            (Url.Parser.string
                </> Url.Parser.string
                </> Url.Parser.custom "VERSION" Elm.Version.fromString
                </> optionalString
            )
        ]


optionalString : Url.Parser.Parser (Maybe String -> a) a
optionalString =
    Url.Parser.oneOf
        [ Url.Parser.map Nothing Url.Parser.top
        , Url.Parser.map Just Url.Parser.string
        ]


routeToString : Route -> String
routeToString r =
    case r of
        Home ->
            "/"

        NotFound ->
            "/"

        PackagePage name version Nothing ->
            "/" ++ name ++ "/" ++ Elm.Version.toString version

        PackagePage name version (Just m) ->
            "/" ++ name ++ "/" ++ Elm.Version.toString version ++ "/" ++ m


href : Route -> Html.Attribute msg
href r =
    Attr.href (routeToString r)


route : Url -> Route
route url =
    url
        |> Url.Parser.parse urlParser
        |> Maybe.withDefault NotFound
