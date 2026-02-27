port module Main exposing (main)

import Browser
import Browser.Dom as Dom
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Task


-- PORTS: Outgoing (Elm → JS)

port openPort : Int -> Cmd msg
port closePort : () -> Cmd msg
port sendData : String -> Cmd msg
port scrollToBottom : () -> Cmd msg


-- PORTS: Incoming (JS → Elm)

port portOpened : (() -> msg) -> Sub msg
port portClosed : (() -> msg) -> Sub msg
port portError : (String -> msg) -> Sub msg
port dataReceived : (String -> msg) -> Sub msg


-- MODEL

type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected
    | Errored String


type alias Model =
    { status : ConnectionStatus
    , inputText : String
    , log : List String
    , baudRate : Int
    , buffer : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { status = Disconnected
      , inputText = ""
      , log = []
      , baudRate = 115200
      , buffer = ""
      }
    , Cmd.none
    )


-- UPDATE

type Msg
    = ClickConnect
    | ClickDisconnect
    | KeyPressed String
    | BaudRateChanged String
    | PortOpened ()
    | PortClosed ()
    | PortError String
    | DataReceived String
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ClickConnect ->
            ( { model | status = Connecting }
            , openPort model.baudRate
            )

        ClickDisconnect ->
            ( model
            , closePort ()
            )

        KeyPressed key ->
            if model.status /= Connected then
                ( model, Cmd.none )
            else
                case key of
                    "Enter" ->
                        ( { model | inputText = "" }
                        , sendData (model.inputText ++ "\n")
                        )

                    "Backspace" ->
                        ( { model | inputText = String.dropRight 1 model.inputText }
                        , scrollToBottom ()
                        )

                    k ->
                        if String.length k == 1 then
                            ( { model | inputText = model.inputText ++ k }
                            , scrollToBottom ()
                            )
                        else
                            ( model, Cmd.none )

        BaudRateChanged str ->
            case String.toInt str of
                Just rate ->
                    ( { model | baudRate = rate }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        PortOpened () ->
            ( { model | status = Connected }
            , Task.attempt (\_ -> NoOp) (Dom.focus "terminal-output")
            )

        PortClosed () ->
            ( { model | status = Disconnected }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )

        PortError errMsg ->
            ( { model
                | status = Errored errMsg
                , log = model.log ++ [ "⚠ " ++ errMsg ]
              }
            , Cmd.none
            )

        DataReceived chunk ->
            let
                parts =
                    (model.buffer ++ chunk)
                        |> String.split "\n"

                complete =
                    parts
                        |> List.reverse
                        |> List.tail
                        |> Maybe.withDefault []
                        |> List.reverse
                        |> List.map (String.replace "\r" "")
                        |> List.filter (not << String.isEmpty)

                newBuffer =
                    parts
                        |> List.reverse
                        |> List.head
                        |> Maybe.withDefault ""

                newLog =
                    (model.log ++ complete)
                        |> List.reverse
                        |> List.take 250
                        |> List.reverse
            in
            ( { model | log = newLog, buffer = newBuffer }
            , if List.isEmpty complete then Cmd.none else scrollToBottom ()
            )


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ portOpened PortOpened
        , portClosed PortClosed
        , portError PortError
        , dataReceived DataReceived
        ]


-- VIEW

view : Model -> Html Msg
view model =
    div
        [ style "display" "flex"
        , style "flex-direction" "column"
        , style "height" "100vh"
        , style "background" "#000"
        , style "font-family" "monospace"
        , style "color" "#33ff33"
        ]
        [ viewTopBar model
        , viewTerminal model
        ]


viewTopBar : Model -> Html Msg
viewTopBar model =
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "space-between"
        , style "background" "#1a1a1a"
        , style "padding" "0.3rem 0.75rem"
        , style "font-size" "0.85rem"
        , style "color" "#ccc"
        , style "flex-shrink" "0"
        ]
        [ viewStatusDot model.status
        , div
            [ style "display" "flex"
            , style "align-items" "center"
            , style "gap" "0.5rem"
            ]
            [ viewBaudSelect model
            , viewConnectButton model
            ]
        ]


viewStatusDot : ConnectionStatus -> Html Msg
viewStatusDot status =
    let
        ( label, dotColor ) =
            case status of
                Disconnected ->
                    ( "Disconnected", "#555" )

                Connecting ->
                    ( "Connecting…", "#f90" )

                Connected ->
                    ( "Connected", "#0f0" )

                Errored err ->
                    ( "Error: " ++ err, "#f33" )
    in
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "gap" "0.4rem"
        ]
        [ span
            [ style "display" "inline-block"
            , style "width" "8px"
            , style "height" "8px"
            , style "border-radius" "50%"
            , style "background" dotColor
            ]
            []
        , text label
        ]


baudRates : List Int
baudRates =
    [ 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200 ]


viewBaudSelect : Model -> Html Msg
viewBaudSelect model =
    let
        isLocked =
            model.status == Connecting || model.status == Connected
    in
    select
        [ onInput BaudRateChanged
        , disabled isLocked
        , style "background" "#333"
        , style "color" "#ccc"
        , style "border" "1px solid #555"
        , style "padding" "0.2rem 0.3rem"
        , style "font-size" "0.8rem"
        , style "font-family" "monospace"
        ]
        (List.map
            (\r ->
                option
                    [ value (String.fromInt r)
                    , selected (r == model.baudRate)
                    ]
                    [ text (String.fromInt r) ]
            )
            baudRates
        )


viewConnectButton : Model -> Html Msg
viewConnectButton model =
    case model.status of
        Disconnected ->
            button
                [ onClick ClickConnect
                , style "background" "#1a3a1a"
                , style "color" "#0f0"
                , style "border" "1px solid #0f0"
                , style "padding" "0.2rem 0.6rem"
                , style "font-family" "monospace"
                , style "font-size" "0.8rem"
                , style "cursor" "pointer"
                ]
                [ text "Connect" ]

        Connecting ->
            button
                [ disabled True
                , style "background" "#333"
                , style "color" "#888"
                , style "border" "1px solid #555"
                , style "padding" "0.2rem 0.6rem"
                , style "font-family" "monospace"
                , style "font-size" "0.8rem"
                ]
                [ text "Connecting…" ]

        Connected ->
            button
                [ onClick ClickDisconnect
                , style "background" "#3a1a1a"
                , style "color" "#f33"
                , style "border" "1px solid #f33"
                , style "padding" "0.2rem 0.6rem"
                , style "font-family" "monospace"
                , style "font-size" "0.8rem"
                , style "cursor" "pointer"
                ]
                [ text "Disconnect" ]

        Errored _ ->
            button
                [ onClick ClickConnect
                , style "background" "#3a2a1a"
                , style "color" "#f90"
                , style "border" "1px solid #f90"
                , style "padding" "0.2rem 0.6rem"
                , style "font-family" "monospace"
                , style "font-size" "0.8rem"
                , style "cursor" "pointer"
                ]
                [ text "Reconnect" ]


viewTerminal : Model -> Html Msg
viewTerminal model =
    div
        [ id "terminal-output"
        , tabindex 0
        , autofocus True
        , preventDefaultOn "keydown" terminalKeyDecoder
        , style "flex" "1"
        , style "overflow-y" "auto"
        , style "padding" "0.5rem 0.75rem"
        , style "background" "#000"
        , style "color" "#33ff33"
        , style "font-size" "0.9rem"
        , style "line-height" "1.4"
        , style "white-space" "pre-wrap"
        , style "word-break" "break-all"
        , style "outline" "none"
        , style "cursor" "text"
        ]
        (if List.isEmpty model.log && model.status == Disconnected then
            [ div [ style "color" "#555" ] [ text "--- disconnected ---" ] ]
         else
            List.map viewTerminalLine model.log
                ++ [ viewPromptLine model ]
        )


viewTerminalLine : String -> Html Msg
viewTerminalLine line =
    div [] [ text line ]



viewPromptLine : Model -> Html Msg
viewPromptLine model =
    div []
        [ text model.inputText
        , span [ class "cursor" ] [ text "▋" ]
        ]


terminalKeyDecoder : Decode.Decoder ( Msg, Bool )
terminalKeyDecoder =
    Decode.map3
        (\key ctrl meta ->
            if ctrl || meta then
                ( KeyPressed key, False )
            else if String.length key == 1 || key == "Enter" || key == "Backspace" then
                ( KeyPressed key, True )
            else
                ( KeyPressed key, False )
        )
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)


-- MAIN

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
