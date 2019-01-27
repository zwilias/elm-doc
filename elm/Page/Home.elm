module Page.Home exposing (view)

import Elm.Constraint
import Elm.Package
import Elm.Project
import Elm.Version
import Html exposing (Html)
import Html.Attributes as Attr
import Route


view : Elm.Project.Project -> List (Html msg)
view project =
    case project of
        Elm.Project.Application appInfo ->
            viewAppHome appInfo

        Elm.Project.Package pkgInfo ->
            viewPkgHome pkgInfo


viewAppHome : Elm.Project.ApplicationInfo -> List (Html msg)
viewAppHome appInfo =
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


viewPkgHome : Elm.Project.PackageInfo -> List (Html msg)
viewPkgHome pkgInfo =
    pkgInfo.deps
        |> List.map (\( name, constraint ) -> Html.text (Elm.Package.toString name ++ "@" ++ Elm.Constraint.toString constraint))
        |> List.intersperse (Html.br [] [])
