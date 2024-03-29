module Page.Detail.FaqWrite exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Port exposing(..)
import Page.Common exposing(..)
import Route exposing (..)
import Json.Decode as Decode
import Json.Encode as E
import Api as Api
import Http as Http
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder

type alias Model =
    { session : Session
    , checkDevice : String
    , check : Bool
    , title : String
    , content : String
    }

init : Session -> Bool ->(Model, Cmd Msg)
init session mobile = 
    ({session = session
    , check = mobile
    , checkDevice = ""
    , title = ""
    , content = ""}
    , Cmd.none
    )

faqEncode : String -> String -> Session -> (Result Http.Error Decoder.Success -> msg) -> Cmd msg
faqEncode titleString content session msg = 
    let
        new string = 
            string
                |> String.replace "&" "%26" 
                |> String.replace "%" "%25"
        body =
            ("title="
                ++ (new titleString)
                ++ "&content="
                ++ (new content)
            )
            |> Http.stringBody "application/x-www-form-urlencoded"
    in
    Api.post Endpoint.faqregist (Session.cred session) msg body (Decoder.resultD)

type Msg 
    = CheckDevice E.Value
    | Title String
    | Content String
    | RegistSuccess (Result Http.Error Decoder.Success)
    | GoRegist
    | GoBack
    | GotSession Session
    | ClickRight
    | ClickLeft
    | GoAnotherPage

subscriptions : Model -> Sub Msg
subscriptions model =
    Session.changes GotSession (Session.navKey model.session)
    
toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GoAnotherPage ->
            (model, Cmd.batch [
                 Api.setCookie (E.int 1)
            ])
        ClickRight ->
            ( model, Api.scrollRight () )
        ClickLeft ->
            (model , Api.scrollLeft ())
        GotSession session ->
            ({model | session = session },faqEncode model.title model.content session RegistSuccess)
        GoBack ->
            (model, Route.pushUrl (Session.navKey model.session) Route.C)
        GoRegist ->
            (model, faqEncode model.title model.content model.session RegistSuccess)
        RegistSuccess (Ok ok) ->
            (model, Cmd.batch [
                Api.showToast (E.string "문의가 등록 되었습니다.")
                , Route.pushUrl (Session.navKey model.session) Route.C
            ])
        RegistSuccess (Err err) ->
            let
                serverErrors =
                    Api.decodeErrors err
            in
            if serverErrors == "401" then
            (model,(Session.changeInterCeptor (Just serverErrors) model.session))
            else
            (model, Cmd.none)
        Title titleStr ->
            ({model | title = titleStr}, Cmd.none)
        Content contentStr ->
            ({model | content = contentStr }, Cmd.none)
        CheckDevice str ->
            let
                result = Decode.decodeValue Decode.string str
            in
                case result of
                    Ok string ->
                        ({model | checkDevice =string}, Cmd.none)
                
                    Err _ ->
                        ({model | checkDevice = ""}, Cmd.none)
            

view : Model -> {title : String , content : Html Msg}
view model =
        { title = "1:1문의"
        , content = 
                div [] [
                    div[][myPageCommonHeader ClickRight ClickLeft GoAnotherPage False]
                , web
            ]
        }

web : Html Msg
web = 
    div [class "container"] [
        commonJustHeader "/image/icon_qna.png" "1:1문의"
        , title
        , textArea
        , uploadBtn
        , backBtn
    ]

title : Html Msg
title = 
        input [ class "input tapbox", type_ "text", placeholder "제목을 입력해주세요" , onInput Title, maxlength 50]
                []

textArea : Html Msg
textArea =
        textarea [ class "textarea tapbox", placeholder "내용을 입력해주세요", rows 10 , onInput Content, maxlength 250]
        []


uploadBtn : Html Msg
uploadBtn = 
    div [ class "togetherWrite_yf_dark" ]
        [ div [ class "button is-dark", onClick GoRegist]
                    [ text "올리기" ]
        ]

backBtn : Html Msg
backBtn = 
    div [ class "faqWrite_backbtn" ]
        [ a [ class "button yf_back",Route.href Route.C]
            [ text "뒤로" ]
        ]

