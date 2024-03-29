module Page.Detail.MyPostDetail exposing(..)

import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Json.Encode as E
import Json.Decode as Decode
import Page.Common exposing(..)
import Page.Detail.YourFitDetail as YfD
import Route exposing(..)
import Api as Api
import Api.Endpoint as Endpoint
import Http as Http
import Api.Decoder as Decoder
import Page.Together as T

type alias Model = 
    { session : Session
    , check : Bool
    , checkDevice: String
    , getData : TogetherData
    , loading : Bool
    , scrap : Bool
    , postId : String
    , zindex : String
    }

type alias TogetherDataWrap = 
    { data : TogetherData 
    }

type alias TogetherData = 
    { content : Maybe String
    , detail : Maybe (List DetailTogether)
    , id : Int
    , inserted_at : String
    , is_delete : Bool
    , link_code : String
    , recommend_cnt : Int
    , nickname: Maybe String
    }

type alias DetailTogether = 
    { thembnail : Maybe String
    , difficulty_name : Maybe String
    , duration : Maybe String
    , exercise_items : Maybe (List TogetherItems)
    , exercise_part_name : Maybe String
    , id : Int
    , inserted_at : Maybe String
    , pairing : Maybe (List Pairing) 
    , title : Maybe String
    , content : Maybe String
    , snippet : Maybe Snippet
    , photo : Maybe String
    }

type alias TogetherItems = 
    { exercise_id : Int
    , is_rest : Bool
    , sort : Int
    , title : String
    , value : Int }

type alias Pairing = 
    { file : String
    , image : String
    , title : String 
    }
type alias Snippet = 
    { items : List DetailItems }

type alias DetailItems = 
    { id : String }

init : Session -> Bool ->(Model, Cmd Msg)
init session mobile
    = (
        { session = session
        , checkDevice = ""
        , check = mobile
        , loading = True
        , scrap = False
        , postId = ""
        , zindex =""
        , getData = 
            { content = Nothing
            , detail = Nothing
            , id = 0
            , inserted_at = ""
            , is_delete = False
            , link_code = ""
            , recommend_cnt = 0
            , nickname = Nothing
            }
        }
        , Cmd.batch 
        [  Api.getId ()
        ]
        
    )

type Msg 
    = GotSession Session
    | BackPage
    | GetId E.Value
    | GetList (Result Http.Error TogetherDataWrap)
    | GoVideo
    | Loading E.Value
    | VideoCall (List Pairing)
    | ClickRight
    | ClickLeft
    | GoAnotherPage

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
    [ Api.receiveId GetId
    , Api.videoSuccess Loading
    , Session.changes GotSession (Session.navKey model.session) ]

justList : Maybe (List a) -> List a
justList item = 
    case item of
        Just a ->
            a
    
        Nothing ->
            []


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
        VideoCall pairing ->
            let
                encodePairing pair= 
                    E.object 
                        [ ("file", E.string pair.file)
                        , ("image", E.string pair.image)
                        , ("title", E.string pair.title)]
                listPair = 
                    E.list encodePairing pairing
            in
            
            ({model | zindex = "zindex"}, Api.videoData listPair)
        GoVideo ->
            let
                head = List.head (justList model.getData.detail)
                result = 
                    case head of
                        Just a ->
                            T.justListData a.pairing
                    
                        Nothing ->
                            []
                videoList = 
                    E.object 
                        [ ("pairing", E.list videoEncode result)]

                videoEncode p=
                    E.object
                        [ ("file", E.string p.file)
                        , ("image", E.string p.image)
                        , ("title", E.string p.title)
                        ]
            in
            (model, Cmd.none)
        GetList(Ok ok) ->
            update GoVideo {model | getData = ok.data, loading = False}
        GetList(Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            (model, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        Loading success ->
            let
                d = Decode.decodeValue Decode.string success
            in
                case d of
                    Ok item ->
                        ({model | loading = False},Cmd.none)
                    Err _->
                         ({model | loading = False},Cmd.none)
        GetId id ->
            let
                result = Decode.decodeValue Decode.string id
            in
            case result of
                Ok string ->
                    ({model | postId = string} , 
                    Decoder.mypostDataWrap TogetherDataWrap TogetherData DetailTogether TogetherItems Pairing Snippet DetailItems
                    |>Api.get GetList (Endpoint.postList string) (Session.cred model.session)  
                    )
            
                Err _ ->
                    (model,Cmd.none)
        
        GotSession session ->
            ({model | session = session} , 
            Decoder.mypostDataWrap TogetherDataWrap TogetherData DetailTogether TogetherItems Pairing Snippet DetailItems
            |> Api.get GetList (Endpoint.postList model.postId) (Session.cred session) 
            )
        BackPage ->
            (model, 
            Route.pushUrl (Session.navKey model.session) Route.MyPost
            )
          

view : Model -> {title : String , content : Html Msg}
view model =
        { title = "내 게시물 관리"
        , content = 
            div [] [
                div[][myPageCommonHeader ClickRight ClickLeft GoAnotherPage False]
                , web BackPage model
            ]
        }

web : msg -> Model -> Html Msg
web msg model= 
    div [class "container"] [
        div [ class "yf_yfworkout_search_wrap" ]
        [ div []
        ( List.map( \x-> 
            contentsItem x model
        ) (justList model.getData.detail)) 
        , goBtn
        ]
    ]

goBtn : Html Msg
goBtn  = 
    div [ class "make_yf_butbox" ]
        [ div [ class "yf_backbtm" ]
            [ a [ class "button yf_largebut", Route.href Route.MyPost ]
                [ text "뒤로" ]
            ]
        , div [ class "yf_nextbtm" ]
            [ a [ class "button is-dark yf_editbut", Route.href Route.FilterS1 ]
                [ text "수정" ]
            ]
        ]



contentsItem : DetailTogether -> Model -> Html Msg
contentsItem item model=
            div [ class "tile is-parent is-vertical" ]
            [div [ class "yf_notification" ]
                [
                    div [ class "tapbox" ]
                    [ div [ class "yf_large" ]
                        [ text (caseString item.title) ]
                    ]
                    , div [class "postVideoWrap"] [
                        div [ class ("imagethumb " ++ model.zindex ), style "background-image" ("url(../image/play-circle-solid.svg) ,url("++ (caseString item.thembnail) ++") ") , onClick (VideoCall (T.justListData item.pairing)) ][]
                    , div [id "myElement", style "height" (if String.isEmpty model.zindex then "0px" else "auto") ] []
                ]
                ], 
            div [ class "yf_subnav" ]
                [ div [ class "yf_time" ]
                    [ span []
                        [ i [ class "fas fa-clock" ]
                            []
                        ], text (justokData item.duration)
                    ]
                , div [ class "yf_part" ]
                    [ text ((justokData item.exercise_part_name) ++ " - " ++  (justokData item.difficulty_name)) ]
                ]
            , 
            pre [class "wordBreak descriptionBackground"]
                    [ 
                    text (justokData model.getData.content)
                    ]
        ,
            div [ class "yf_text" ]
               (List.indexedMap YfD.description (List.sortBy .sort (T.exerciseItemCase item.exercise_items)))
            ]

caseString : Maybe String -> String
caseString item = 
    case item of
        Just string ->
             string
        _ ->
            ""

justokData : Maybe String -> String
justokData result = 
    case result of
        Just ok ->
            ok
        Nothing ->
            ""
