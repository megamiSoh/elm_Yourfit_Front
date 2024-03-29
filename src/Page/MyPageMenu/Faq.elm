module Page.MyPageMenu.Faq exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing(..)
import Route exposing (..)
import Json.Decode as Decode
import Json.Encode as E
import Api as Api
import Http as Http
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
import Page.Detail.FaqDetail as FaqDetail
import Page.Detail.FaqWrite as Fw
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
    , checkDevice : String
    , idx : String
    , check : Bool
    , faq : Faq
    , getId : Int
    , pageNum : Int
    , page : Int
    , per_page : Int
    , detail : FaqDetail.Detail
    , screenInfo : ScreenInfo
    , ofheight : Bool
    , appFaqData : List Data
    , title : String
    , content : String
    , showWrite : Bool
    , showDetail : Bool
    , scrollCount : Float
    , onDemandText : String
    , options : Markdown.Config.Options
    , selectedPreviewTab : PreviewTab
    , showToC : Bool
    , textarea : String
    , errType : String
    }

type alias Faq =
    { data : List Data
    , paginate : Page }

type alias Data = 
    { id : Int
    , inserted_at : String
    , is_use : Bool
    , title : String }

type alias Detail = 
    { answer : Maybe String
    , asked_id : Int
    , content : String
    , id : Int
    , is_answer : Bool
    , title : String
    , username : String }

type alias Page = 
    {  end_date : String
    , is_use : Bool
    , page : Int
    , per_page : Int
    , start_date : String
    , title : String
    , total_count : Int  }

type alias ScreenInfo = 
    { scrollHeight : Int
    , scrollTop : Int
    , offsetHeight : Int}

type PreviewTab
    = RealTime


type EditorTab
    = Editor


init : Session -> Bool ->(Model, Cmd Msg)
init session mobile
    = (
        {session = session
        ,checkDevice = "",
        idx = ""
        , check = mobile
        , getId = 0
        , pageNum = 1
        , page = 1
        , per_page = 10
        , ofheight = False
        , appFaqData = []
        , title = ""
        , content = ""
        , showWrite = False
        , scrollCount = 0
        , textarea = ""
        , onDemandText = ""
        , options = defaultOptions
        , showToC = False
        , selectedPreviewTab = RealTime
        , screenInfo = 
            { scrollHeight = 0
            , scrollTop = 0
            , offsetHeight = 0}
        , faq = 
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
        , detail = 
            { content = ""
            , id = 0 
            , title = "" }
        , showDetail = False
        , errType = ""
        }
        , Cmd.batch[faqEncode 1 10 session
        , scrollToTop NoOp
        ]
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch[Api.successSave GetDetail
    , Session.changes GotSession (Session.navKey model.session)
    , Api.touch ReceiveScroll]

faqEncode : Int -> Int -> Session -> Cmd Msg
faqEncode page per_page session =
    let
        body = 
            E.object 
                [ ("page", E.int page)
                , ("per_page", E.int per_page)]
                    |> Http.jsonBody 
    in
    Api.post Endpoint.faqfaqList (Session.cred session) FaqList body (Decoder.faqfaqList Faq Data Page)

detailApi : String -> Session -> Cmd Msg    
detailApi id session = 
    Api.get AppDetail (Endpoint.faqfaqDetail id) (Session.cred session) (Decoder.faqfaqDetail FaqDetail.Data FaqDetail.Detail)

type Msg 
    = CheckDevice E.Value
    | Show Int Int
    | FaqList (Result Http.Error Faq)
    | DetailGo Int
    | GetDetail E.Value
    | PageBtn (Int, String)
    | AppDetail (Result Http.Error FaqDetail.Data)
    | GoDelete Int
    | DeleteSuccess (Result Http.Error Decoder.Success)
    | ScrollEvent ScreenInfo
    | GotSession Session
    | GoRegist
    | GoBack String
    | Title String
    | Content String
    | RegistSuccess (Result Http.Error Decoder.Success)
    | DetailData (Result Http.Error FaqDetail.Data)
    | GoEdit
    | EditComplete (Result Http.Error Decoder.Success)
    | NoOp
    | ReceiveScroll E.Value

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check

regist : Model -> (Result Http.Error Decoder.Success -> msg) -> Cmd msg
regist model = 
    Fw.faqEncode model.title model.content model.session

scrollEvent : (ScreenInfo -> msg) -> Attribute msg
scrollEvent msg = 
    on "scroll" (Decode.map msg scrollInfoDecoder)

scrollInfoDecoder : Decode.Decoder ScreenInfo
scrollInfoDecoder =
    Decode.map3 ScreenInfo
        (Decode.at [ "target", "scrollHeight" ] Decode.int)
        (Decode.at [ "target", "scrollTop" ] Decode.int)
        (Decode.at [ "target", "offsetHeight" ] Decode.int)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceiveScroll scr ->
            case Decode.decodeValue Decode.float scr of
                Ok ok ->
                    let 
                        endOfPage =  model.faq.paginate.total_count // model.per_page 
                    in
                        if ok /= model.scrollCount then
                            if model.page < (endOfPage + 1) then
                            ({model | scrollCount = ok, page =  model.page + 1}, faqEncode  (model.page + 1) model.per_page model.session )
                            else
                            ({model | ofheight = True}, Cmd.none)
                        else
                        (model, Cmd.none)
                Err err ->
                    (model, Cmd.none)
        NoOp ->
            (model, Cmd.none)
        EditComplete (Ok ok) ->
            ({model | showDetail = False}, Cmd.batch[Api.showToast (E.string "수정이 완료 되었습니다."), faqEncode model.page model.per_page model.session])
        EditComplete (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "edit"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        GoEdit ->
            (model , FaqDetail.editEncoder model.title model.content model.session (String.fromInt model.getId) EditComplete)
        DetailData (Ok ok) ->
            ({model | detail = ok.data, title = ok.data.title, content = ok.data.content, textarea = ok.data.content}, Cmd.none)
        DetailData (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "detail"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        RegistSuccess (Ok ok) ->
            ({model | title = "" , content = "", showWrite = False}, Cmd.batch [
                Api.showToast (E.string "문의가 등록 되었습니다.")
                , faqEncode model.page model.per_page model.session
            ])
        RegistSuccess (Err err) ->
            let
                serverErrors =
                    Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "regist"},(Session.changeInterCeptor (Just serverErrors) model.session))
            else
            (model, Cmd.none)
        Title titleStr ->
            ({model | title = titleStr}, Cmd.none)
        Content contentStr ->
            ({model | content = contentStr }, Cmd.none)
        GoBack whereIs ->
            case whereIs of
                "home" ->
                    (model, Route.pushUrl (Session.navKey model.session) Route.Home)
                "write" ->
                    ({model | showWrite = True, title = "", content = ""}, Cmd.none)
                "list" ->
                    ({model | showWrite = False, showDetail = False, title = "" , content = ""}, Cmd.none)
                _ ->
                    ({model | showWrite = False}, Cmd.none)
        GoRegist ->
            (model, 
            Fw.faqEncode model.title model.content model.session RegistSuccess
            )
        GotSession session ->
            ({model | session = session}, 
            case model.errType of
                "edit" ->
                    FaqDetail.editEncoder model.title model.content session (String.fromInt model.getId) EditComplete
                "detail" ->
                    FaqDetail.detailApi (String.fromInt model.getId) session DetailData
                "regist" ->
                    Fw.faqEncode model.title model.content session RegistSuccess
                "delete" ->
                    Api.get DeleteSuccess (Endpoint.faqDelete (String.fromInt model.getId)) (Session.cred session) (Decoder.resultD)
                "appDetail" ->
                    detailApi (String.fromInt model.getId) session
                "faq" ->
                    faqEncode  (model.page + 1) model.per_page session
                _ ->
                    faqEncode  (model.page + 1) model.per_page session)
        ScrollEvent { scrollHeight, scrollTop, offsetHeight } ->
                (model, Cmd.none)
        DeleteSuccess (Ok ok) ->
            (model, Cmd.batch [
                Api.showToast (E.string "삭제되었습니다.")
                , faqEncode model.page model.per_page model.session
            ])
        DeleteSuccess (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "delete"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        GoDelete id ->
            ({model | getId = id}, Api.get DeleteSuccess (Endpoint.faqDelete (String.fromInt id)) (Session.cred model.session) (Decoder.resultD) )
        AppDetail (Ok ok) ->
            ({model | detail = ok.data, textarea = ok.data.content}, Cmd.none)
        AppDetail (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "appDetail"}, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        PageBtn (idx, str) ->
            let
                idxEncode = E.int idx
            in
            
            case str of
                "prev" ->
                    ({model | page = idx, pageNum = model.pageNum - 1}, Cmd.batch[faqEncode idx model.per_page model.session, Api.setCookie idxEncode])
                "next" ->
                    ({model | page = idx, pageNum = model.pageNum + 1}, Cmd.batch[faqEncode idx model.per_page model.session, Api.setCookie idxEncode])
                "go" -> 
                    ({model | page = idx}, Cmd.batch[faqEncode idx model.per_page model.session, Api.setCookie idxEncode])
                _ ->
                    (model, Cmd.none)
        GetDetail str ->
            (model, Route.pushUrl (Session.navKey model.session) Route.FaqD )
        DetailGo id ->
            if model.check then
            ({model | getId = id, showDetail = True}, FaqDetail.detailApi (String.fromInt id) model.session DetailData)
            else
            ({model | getId = id}, Api.saveKey (E.string (String.fromInt id)))
        FaqList (Ok ok) ->
            if model.check then
            ({model | faq = ok, appFaqData = model.appFaqData ++ ok.data}, Cmd.none)
            else
            ({model | faq = ok}, Cmd.none)
        FaqList (Err err) ->
            let
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            ({model | errType = "faq"}, (Session.changeInterCeptor (Just serverErrors) model.session))
            else
            (model, Cmd.none)
        CheckDevice str ->
            let
                result = Decode.decodeValue Decode.string str
            in
                case result of
                    Ok string ->
                        ({model | checkDevice = string}, Cmd.none)
                
                    Err _ ->
                        ({model | checkDevice = ""}, Cmd.none)
                        
        Show idx id->
            if String.fromInt(idx) == model.idx then
            ({model| idx = ""}, Cmd.none)    
            else
            ({model| idx = String.fromInt(idx), getId = id}, detailApi (String.fromInt id) model.session)

view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
    { title = "YourFitExer"
    , content = 
        div [] [
            app model
        ]
    }
    else
    { title = "YourFitExer"
    , content = 
        div [] [web model]
    }

web : Model -> Html Msg
web model = 
    div [ class "container" ]
        [
            commonJustHeader "/image/icon_qna.png" "자주하는 질문",
            if List.isEmpty model.faq.data then
            div [class "noResult"] [text "문의가 없습니다."]
            else
            div [] [
                contentsBody model,
                pagination 
                    PageBtn
                    model.faq.paginate
                    model.pageNum
            ]
        ]

app : Model -> Html Msg
app model = 
    div [class ("container topSearch_container " ++ (if model.showWrite || model.showDetail then "fadeContainer" else ""))] [
        appHeaderConfirmDetailleft "자주하는 질문" "myPageHeader" (GoBack "home") (GoBack "write") "" 
        , 
        if List.isEmpty model.faq.data then
        div [class "noResult"] [text "문의가 없습니다."]
        else
        appContentsBody model

    ]

appContentsBody : Model -> Html Msg
appContentsBody model=
    div [class "table scrollHegiht" , scrollEvent ScrollEvent, id "searchHeight"] [
        div [class "m_loadlistbox"] (List.indexedMap (\idx x ->  itemLayout idx x model) model.appFaqData)
    ]

itemLayout : Int -> Data -> Model -> Html Msg
itemLayout idx item model =
        div [class "eventArea" ,onClick (Show idx item.id)] [
            div [class "eventAreaChild faqevent"] [
                pre [class "titleLeft"] [text item.title]
            ]
            , expandQ idx model item.id
        ]

expandAnswer : String -> Html Msg
expandAnswer title = 
        div [class"answerbox"] [
            p[class"answerbox_text"][text ("Re: " ++  title)]
        ]

showAnswer : Maybe String -> Html Msg
showAnswer answer= 
    div [class"tr_showAnswer"]
        [  pre [class "faq_q"][text (justString answer)] 
        ]

expandQ : Int -> Model -> Int -> Html Msg
expandQ idx model id =
    div [classList [
        ("heightZero", True),
        ("heightShow", String.fromInt(idx)  == model.idx )
    ]] [
        markdownView model
    ]

contentsBody : Model -> Html Msg
contentsBody model =
    div [ class "info_mediabox" ]
        [ div [ class "table info_yf_table" ]
            [ div [class "tableRow"]
                    [ div [class "tableCell faq_num"]
                        [ text "번호" ]
                    , div [class "tableCell faq_title"]
                        [ text "제목" ]
                    , div [class "tableCell faq_date"]
                        [ text "등록일" ]
                    ]
            , tbody []
                (List.indexedMap (\idx x -> contentsLayout idx x model) model.faq.data)
            ]
        ]


contentsLayout : Int -> Data -> Model -> Html Msg
contentsLayout idx item model = 
    div [class "tableRow cursor", onClick (DetailGo item.id)] [
        div [class "tableCell qna_numtext"] [text (
                    String.fromInt(model.faq.paginate.total_count - ((model.faq.paginate.page - 1) * 10) - (idx)  )
                )],
        div [class "tableCell qna_title_text"] 
            [text (
                item.title
                    |> String.replace "%26" "&"
                    |> String.replace "%25" "%"
            ) ],
        div [class "tableCell qna_title_date"] [text (String.dropRight 10 item.inserted_at)]
    ]

pagenation : Html Msg
pagenation =
    div [ class "yf_Pagination" ]
        [ nav [ class "pagination is-centered" ]
            [ ul [ class "pagination-list" ]
                [ li [ class "" ]
                    [ a [ class "pagination-link"]
                        [ text "<" , text "<" ]
                    ]
                , a [ class "pagination-link"]
                    [ text "<" ]
                , li []
                    [ a [ class "pagination-link is-current yf_cut" ]
                        [ text "5" ]
                    ]
                , li []
                    [ a [ class "pagination-link"]
                        [ text ">" ]
                    ]
                , a [ class "pagination-link" ]
                    [ text ">>" ]
                ]
            ]
        ]



justString : Maybe String -> String     
justString item = 
    case item of
        Just ok ->
            decodeChar ok
    
        Nothing ->
            "등록된 답변이 없습니다."

decodeChar : String -> String
decodeChar char = 
    char
        |> String.replace  "%26" "&"
        |> String.replace  "%25" "%"

