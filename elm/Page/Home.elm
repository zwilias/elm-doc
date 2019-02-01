module Page.Home exposing (view)

import Elm.Constraint
import Elm.Package
import Elm.Project
import Elm.Version
import Html exposing (Html)
import Html.Attributes as Attr
import Route


view : Elm.Project.ApplicationInfo -> List (Html msg)
view appInfo =
    appInfo.depsDirect
        |> List.map viewLink
        |> List.intersperse (Html.br [] [])


viewLink : ( Elm.Package.Name, Elm.Version.Version ) -> Html msg
viewLink ( name, version ) =
    Html.a
        [ Route.href (Route.PackagePage (Elm.Package.toString name) version Nothing) ]
        [ Html.text (Elm.Package.toString name)
        , Html.text " "
        , Html.text (Elm.Version.toString version)
        ]
