module Page.MyPageMenu.Info exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing(..)
import Port as P
import Json.Encode as Encode
import Json.Decode as Decode
import Route exposing (..)
import Page.Common exposing (..)
import Api as Api
import Http as Http
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
import Markdown.Block as Block exposing (Block)
import Markdown.Config exposing (HtmlOption(..),  defaultSanitizeOptions)
import Markdown.Inline as Inline
import Page.InfoEditor exposing (..)


defaultOptions =
    { softAsHardLineBreak = False
    , rawHtml = ParseUnsafe
    }

type alias Model =
    { session : Session
    , check : Bool
    , data : Data
    , page : Int
    , pageNum : Int
    , infoPage : Int
    , per_page : Int
    , infiniteLoading : Bool
    , screenInfo : ScreenInfo
    , dataList :List DataList
    , checkList : List String
    , detailData : DetailData
    , textarea : String
    , detailShow : Bool
    , onDemandText : String
    , options : Markdown.Config.Options
    , selectedPreviewTab : PreviewTab
    , showToC : Bool
    , scrollCount : Float
    , showMenu : Bool
    , errType : String
    , detailId : Int
    }

type alias ScreenInfo = 
    { scrollHeight : Int
    , scrollTop : Int
    , offsetHeight : Int}

type alias Data = 
    { data : List DataList 
    , paginate : Paginate }

type alias DataList = 
    { id : Int
    , inserted_at : String
    , is_use : Bool
    , title : String }

type alias Paginate = 
    { end_date : String
    , is_use : Bool
    , page : Int
    , per_page : Int
    , start_date : String
    , title : String
    , total_count : Int
    }

type alias DetailDataWrap =
    { data : DetailData }

type alias DetailData = 
    { content : String
    , id : Int
    , title : String }

type EditorTab
    = Editor


type PreviewTab
    = RealTime

infoEncoder : Int -> Int -> Session -> Cmd Msg
infoEncoder page per_page session = 
    let
        body = 
            Encode.object 
                [ ("page", Encode.int page )
                , ("per_page", Encode.int per_page) ]
                |> Http.jsonBody    
    in
    Api.noSessionpost Endpoint.infolist GetList body (Decoder.infoData Data DataList Paginate)

init : Session -> Bool ->(Model, Cmd Msg)
init session mobile
    = (
        { session = session
        , page = 1
        , checkList = []
        , infoPage = 1
        , infiniteLoading = False
        , per_page = 10
        , dataList = []
        , pageNum = 1
        , detailShow = False
        , onDemandText = ""
        , options = defaultOptions
        , showToC = False
        , selectedPreviewTab = RealTime
        , scrollCount = 0
        , showMenu = False
        , screenInfo = 
            { scrollHeight = 0
            , scrollTop = 0
            , offsetHeight = 0}
        , data = 
            { data = []
            , paginate = 
                { end_date = ""
                , is_use = False
                , page = 0
                , per_page = 0
                , start_date = ""
                , title = ""
                , total_count = 0
                }
                } 
        , detailData = 
            { content = ""
            , id = 0
            , title = "" }
        ,  check = mobile
        , textarea = ""
        , errType = ""
        , detailId = 0}
        , Cmd.batch[ 
            infoEncoder 1 10 session
        ]
    )
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
subscriptions model =
    Sub.batch[
    Api.getPageId GetPageId
    , Api.successId SaveComplete
    , Session.changes GotSession (Session.navKey model.session)
    , Api.touch ReceiveScr
    ]

type Msg 
    = BackBtn
    | GetList (Result Http.Error Data)
    | DetailGo Int
    | SaveComplete Encode.Value
    | PageBtn (Int, String)
    | ScrollEvent ScreenInfo
    | NoOp 
    | GetPageId Encode.Value
    | GotSession Session
    | GetDetail (Result Http.Error DetailDataWrap)
    | ReceiveScr Encode.Value

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceiveScr scr ->
            case Decode.decodeValue Decode.float scr of
                Ok ok ->
                    if model.scrollCount /= ok then
                        if List.length model.checkList > 0 then
                            ({model | scrollCount = ok}, Cmd.none)
                        else
                            ({model | infiniteLoading = True, scrollCount = ok, page = model.page + 1}, infoEncoder (model.page + 1) model.per_page model.session)
                    else
                        ({model | scrollCount = ok}, Cmd.none)
            
                Err err ->
                    (model, Cmd.none)
        GetDetail (Ok ok)->
            ({model | detailData = ok.data, textarea = ok.data.content}, Cmd.none)
        GetDetail (Err err)->
            let
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "detail"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        GotSession session ->
            ({model | session = session}, 
            case model.errType of
                "detail" ->
                    Api.get GetDetail (Endpoint.detailInfo (String.fromInt model.detailId)) (Session.cred session) (Decoder.detailInfo DetailDataWrap DetailData)
                "list" ->
                    infoEncoder (model.page) model.per_page session
                _ ->
                    infoEncoder (model.page) model.per_page session
                )
        GetPageId str ->
            let
                decodeV = Decode.decodeValue Decode.int str
            in
                case decodeV of
                    Ok ok ->
                        ({model | page = ok, infoPage = ok}, infoEncoder ok model.per_page model.session)
                    Err err ->
                        (model,  infoEncoder 1 model.per_page model.session)
        NoOp ->
            (model, Cmd.none)
        ScrollEvent { scrollHeight, scrollTop, offsetHeight } ->
                (model, Cmd.none)
        PageBtn (idx, str) ->
            let
                idxEncode = Encode.int idx
            in
            
            case str of
                "prev" ->
                    ({model | page = idx, pageNum = model.pageNum - 1}, Cmd.batch[infoEncoder idx model.per_page model.session, Api.setCookie idxEncode])
                "next" ->
                    ({model | page = idx, pageNum = model.pageNum + 1}, Cmd.batch[infoEncoder idx model.per_page model.session, Api.setCookie idxEncode])
                "go" -> 
                    ({model | page = idx}, Cmd.batch[infoEncoder idx model.per_page model.session, Api.setCookie idxEncode])
                _ ->
                    (model, Cmd.none)
        SaveComplete str ->
            if model.check then
            (model, Cmd.none)
            else
            let
                suc = Decode.decodeValue Decode.string str
            in
            case suc of
                Ok ok ->
                   (model, 
                   Route.pushUrl (Session.navKey model.session) Route.InfoD
                   ) 
            
                Err _->
                    (model, Cmd.none)
        GetList (Ok ok)->
            if ok.data == [] then
            ({model | infiniteLoading = False, checkList = ["empty"]}, Cmd.none)
            else
            ({model | data = ok, dataList = model.dataList ++ ok.data,  infiniteLoading = False}, (scrollToTop NoOp))
        GetList (Err err)->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "list"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        DetailGo id ->  
            let
                encodeId = 
                    Encode.string (String.fromInt(id))
            in
            if model.check then
                if id == 0 then
                ({model | detailShow = False}, Cmd.none)
                else
                ({model | detailShow = True, detailId = id},  Api.get GetDetail (Endpoint.detailInfo (String.fromInt id)) (Session.cred model.session) (Decoder.detailInfo DetailDataWrap DetailData))
            else
            (model, Api.saveId encodeId)
        BackBtn ->
            (model , 
            Route.pushUrl (Session.navKey model.session) Route.Home
            )

view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
        { title = "공지사항"
        , content = 
        div [] [
                app model
                , appDetail model.detailData model
        ]
        }
    else
        { title = "공지사항"
        , content = 
        div [] [ web model]
        }

editorView : String -> (String -> msg) -> Bool -> Html msg       
editorView md textAreaInput readOnly=
        textarea
            [ onInput textAreaInput
            , property "defaultValue" (Encode.string md)
            , class "editor editorStyle"
            , spellcheck False
            , disabled readOnly
            , placeholder "내용을 입력 해 주세요."
            ]
            []

web : Model -> Html Msg
web model= 
    div [ class "container" ]
        [
            commonJustHeader "/image/icon_notice.png" "공지사항",
            contentsBody model,
            pagination 
                PageBtn
                model.data.paginate
                model.pageNum
        ]

app : Model -> Html Msg
app model = 
    div [class ("container topSearch_container " ++ if model.detailShow then "fadeContainer" else "")] [
        appHeaderRDetail "공지사항" "myPageHeader whiteColor" Route.Home "fas fa-angle-left",
        div ([ class "table scrollHegiht", id "searchHeight" ])
        [ 
            if List.length (model.data.data) > 0 then
            tbody [class ""] 
            (List.map appContentsBody model.dataList)
            else
            tbody [] [
                tr[] [ 
                    td [colspan 3] [text "공지사항이 없습니다."]
                ]
            ]
    ]
    
    ]

appContentsBody : DataList -> Html Msg
appContentsBody item =
    div [class "m_tableRow",  onClick (DetailGo item.id)] [
        td[class "m_infor_tableCell"][text item.title],
        td[class" m_infor_notice_date_tableCell"][text (String.dropRight 10 (item.inserted_at))]
    ]

contentsBody : Model -> Html Msg
contentsBody model =
    div [ class "info_mediabox" ]
        [ div [ class "table info_yf_table" ]
            [  div [class "tableRow infor_tableRow"]
                    [ div [class "tableCell info_num"]
                        [ text "번호" ]
                    , div [class "tableCell info_title"]
                        [ text "내용" ]
                    , div [class "tableCell info_date"]
                        [ text "등록일" ]
                ]
            , 
            if List.length (model.data.data) > 0 then
            tbody []
                (List.indexedMap (\idx x -> contentsBodyLayout idx x model) model.data.data)
            else
            tbody [] [
                tr[] [ 
                    td [colspan 3, style "text-align" "center", style "padding" "3rem"] [text "공지사항이 없습니다."]
                ]
            ]
            ]
        ]

contentsBodyLayout : Int -> DataList -> Model -> Html Msg   
contentsBodyLayout idx item model =
        div [ class "tableRow",  onClick (DetailGo item.id)]
            [                                                           
                div [class "tableCell info_num_text"] [text (
                    String.fromInt(model.data.paginate.total_count - ((model.data.paginate.page - 1) * 10) - (idx)  )
                )],
                div [class "tableCell info_title_text"] [text item.title],
                div [class "tableCell info_date_text"] [text (String.dropRight 10 (item.inserted_at))]
            ]

appDetail : DetailData -> Model -> Html Msg
appDetail data model =
    div [class ("container myaccountStyle " ++ if model.detailShow then "account" else ""), style "overflow-y" "scroll"] [
        appHeaderRDetailClick (
            if String.length( data.title ) > 10 then
                (String.dropRight (String.length data.title - 9) data.title) ++ "..."
            else 
            data.title
        ) "myPageHeader whiteColor" (DetailGo 0) "fas fa-times",
        appContentsBox data model
    ]

appContentsBox : DetailData -> Model -> Html Msg
appContentsBox item model= 
    div [ class "mediabox" ]
        [ div [ class "titlebox" ]
            []
        , div [ class "m_infoDetail_textbox" ]
            [ 
                markdownView model
            ]
        ]
