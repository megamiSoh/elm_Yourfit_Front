module Page.Detail.MakeExerSearch exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Html.Attributes as Attr
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing (..)
import Route exposing(..)
import Port as P
import Json.Encode as Encode
import Json.Decode as Decode
import Http as Http exposing(..)
import Api as Api
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
type alias Model = 
    { session : Session
    , checkDevice : String
    , page : Int
    , per_page : Int
    , title : String
    , getlistData : GetListData
    , check : Bool
    , loading : Bool
    , saveCheckVal : String
    , sumCount : Int
    , screenInfo : ScreenInfo
    , infiniteLoading : Bool
    , newList : List ListData
    , errType : String
    , deleteId : Int
    }

type alias ScreenInfo = 
    { scrollHeight : Int
    , scrollTop : Int
    , offsetHeight : Int}

type alias GetListData = 
    { data : List ListData
    , paginate: Paginate }

type alias ListData = 
    { difficulty_name : Maybe String
    , duration : String
    , exercise_part_name : Maybe String
    , id : Int
    , inserted_at : String
    , is_use : Bool
    , mediaid : String
    , thembnail : String
    , title : String
    }

type alias Paginate = 
    { difficulty_code : String
    , end_date : String
    , exercise_part_code : String
    , inserted_id : Int
    , make_code : String
    , page : Int
    , per_page : Int
    , start_date : String
    , title : String
    , total_count : Int
    }

bodyEncode : Int -> Int -> String -> Session -> Cmd Msg
bodyEncode page perpage title session= 
    let
        list = 
            Encode.object
                [ ("page", Encode.int page)
                , ("per_page", Encode.int perpage)
                , ("title" , Encode.string title)]
        body =
            list
                |> Http.jsonBody
    in
    (Decoder.makeExerList GetListData ListData Paginate)
    |> Api.post Endpoint.makeExerList (Session.cred session) GetData body 
    
init : Session -> Bool ->(Model, Cmd Msg)
init session mobile =
    let
        listmodel = 
            { page = 1
            , per_page = 10
            , title = ""}
    in
    (
        { session = session
        , checkDevice = ""
        , page = 1
        , per_page = 10
        , infiniteLoading = False
        , sumCount = 1
        , title = ""
        , check = mobile
        , saveCheckVal = ""
        , loading = True
        , newList = []
        , screenInfo = 
            { scrollHeight = 0
            , scrollTop = 0
            , offsetHeight = 0}
        , getlistData = 
            { data = []
            , paginate =
                { difficulty_code = ""
                , end_date = ""
                , exercise_part_code = ""
                , inserted_id = 0
                , make_code = ""
                , page = 0
                , per_page = 0
                , start_date = ""
                , title = ""
                , total_count = 0
                }
            }
        , errType = ""
        , deleteId = 0
        }, 
        Cmd.none
    )

type Msg 
    =  GetData (Result Http.Error GetListData)
    | CheckId Int String
    | SaveIdComplete Encode.Value
    | SessionCheck Encode.Value
    | GotSession Session
    | Delete Int
    | DeleteSuccess (Result Http.Error Decoder.Success)
    | PageBtn (Int, String)
    | OnLoad
    | KeyDown Int
    | ScrollEvent ScreenInfo
    | SearchExercise String


toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check

scrollEvent : (ScreenInfo -> msg) -> Attribute msg
scrollEvent msg = 
    on "scroll" (Decode.map msg scrollInfoDecoder)

scrollInfoDecoder : Decode.Decoder ScreenInfo
scrollInfoDecoder =
    Decode.map3 ScreenInfo
        (Decode.at [ "target", "scrollHeight" ] Decode.int)
        (Decode.at [ "target", "scrollTop" ] Decode.int)
        (Decode.at [ "target", "offsetHeight" ] Decode.int) 


subscriptions : Model -> Sub Msg
subscriptions model=
    Sub.batch [
        Session.changes GotSession (Session.navKey model.session)
        , Api.successId SaveIdComplete
    ]

onLoad : msg -> Attribute msg
onLoad msg =
    on "load" (Decode.succeed msg)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown key ->
            if key == 13 then
                (model, bodyEncode model.page model.per_page model.title model.session)
            else
                (model, Cmd.none)
        SearchExercise str ->
            ({model | title = str}, Cmd.none)
        ScrollEvent { scrollHeight, scrollTop, offsetHeight } ->
             if (scrollHeight - scrollTop) <= offsetHeight then
                ({model | infiniteLoading = True}, bodyEncode (model.page)  model.per_page model.title model.session)
                
            else
                (model, Cmd.none)
        OnLoad ->
            if model.sumCount >= List.length(model.getlistData.data) then
            ({model | loading = False}, Cmd.none)
            else
            ({model | sumCount = model.sumCount + 1}, Cmd.none)
        PageBtn (idx, str) ->
            case str of
                "prev" ->
                    (model, bodyEncode idx model.per_page model.title model.session)
                "next" ->
                    (model, bodyEncode idx model.per_page model.title model.session)
                "go" -> 
                    (model, bodyEncode idx model.per_page model.title model.session)
                _ ->
                    (model, Cmd.none)
        DeleteSuccess (Ok ok) ->
            (model, bodyEncode model.page model.per_page model.title model.session)
        DeleteSuccess (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "delete"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        Delete id ->
            ({model | deleteId = id}, 
            Decoder.resultD
                |> Api.get DeleteSuccess (Endpoint.makeDelete (String.fromInt (id)))(Session.cred model.session)  )
        GotSession session ->
            ({model | session = session}
            , case model.errType of
                "delete" ->
                    Decoder.resultD
                    |> Api.get DeleteSuccess (Endpoint.makeDelete (String.fromInt (model.deleteId)))(Session.cred session)
                "data" ->
                    bodyEncode model.page model.per_page model.title session
                _ ->
                    bodyEncode model.page model.per_page model.title session
            )
        SessionCheck check ->
            let
                decodeCheck = Decode.decodeValue Decode.string check
            in
                case decodeCheck of
                    Ok continue ->
                        (model, bodyEncode model.page model.per_page model.title model.session)
                    Err _ ->
                        (model, Cmd.none)
        SaveIdComplete str ->
            if model.saveCheckVal == "" then
            (model, 
            Route.pushUrl (Session.navKey model.session) Route.MakeDetail
            )
            else 
            (model,
            Route.pushUrl (Session.navKey model.session) Route.TogetherW
            )
        CheckId id str->
            let
                save = Encode.int id
            in
            ({model | saveCheckVal = str},Api.saveId save)
        GetData (Ok ok) -> 
            if ok.data == [] then
            ({model | getlistData = ok, newList = model.newList, infiniteLoading = False}, Cmd.none)
            else
            ({model | getlistData = ok, newList = model.newList ++ ok.data, infiniteLoading = False}, Cmd.none)
        GetData (Err err) -> 
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "data"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        
onKeyDown:(Int -> msg) -> Attribute msg
onKeyDown tagger = 
    on "keydown" (Decode.map tagger keyCode)

view : Model -> {title : String , content : Html Msg}
view model =
    { title = "맞춤운동 검색"
    , content = div [] [
        div [ class "cus_topbox" ]
            [ a [ class "backbtn", Route.href Route.MakeExer ]
                [ i [ class "fas fa-angle-left" ]
                    []
                ]
            , div [ class "topboxtitle" ]
                [ p [ class "control has-icons-left top_input" ]
                    [ input [ class "input", type_ "text", placeholder "운동을 검색하세요", onInput SearchExercise, onKeyDown KeyDown ]
                        []
                    , span [ class "icon is-small is-left" ]
                        [ i [ class "fas fa-search" ]
                            []
                        ]
                    ]
                ]
            ]
        , div[](List.map appItemContent model.getlistData.data)
    ]}

appItemContent : ListData -> Html Msg
appItemContent item=
        div [ class "m_make_yf_box2" ]
            [ div [ class "m_make_videoimg", onClick (CheckId item.id "") ]
                [ img [ src item.thembnail, onLoad OnLoad ]
                    []
                ]
      
            , div [ class "m_make_yf_box_title", onClick (CheckId item.id "") ]
                [ text item.title ]
            , div [ class "make_yf_ul" ]
                [ ul []
                    [ li []
                        [ text (String.dropRight 10 (item.inserted_at)) ]
                    , li [] [
                        i [ class "fas fa-stopwatch" ]
                        []
                        , text " "
                        , text item.duration
                    ]
                    ]
                ]
            , div [ class "button is-dark m_makeExercise_share"
            , onClick (CheckId item.id "share")
            ]
                [ i [ class "fas fa-share-square" ]
                [], text "공유하기" 
            ]

                , div [ class "button m_makeExercise_dete",onClick (Delete item.id) ]
                [ i [ class "far fa-trash-alt" ]
                [], text "삭제" 
            ]
            ]

