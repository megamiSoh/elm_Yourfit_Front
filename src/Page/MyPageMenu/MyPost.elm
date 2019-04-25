module Page.MyPageMenu.MyPost exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing(..)
import Port as P
import Json.Decode as Decode
import Json.Encode as Encode
import Route exposing(..)
import Api as Api
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
import Http as Http

type alias Model 
    = {
        session : Session
        ,checkDevice : String
        , check : Bool
        , page : Int
        , per_page : Int
        , data : DataList
        , infiniteLoading : Bool
        , checkList : List String
        , screenInfo : ScreenInfo
        , dataList : List Data
        , deleteComplete : Bool
        , errAuth : String
        , deleteId : Int
        , pageNum : Int
        , loading : Bool
        , show : String
    }

type alias ScreenInfo = 
    { scrollHeight : Int
    , scrollTop : Int
    , offsetHeight : Int}

type alias DataList = 
    { data : List Data
    , paginate : Paginate }

type alias Data = 
    { content : Maybe String
    , id : Int
    , inserted_at : String
    , link_code : String}

type alias Paginate = 
    { inserted_id : Int
    , page : Int
    , per_page : Int
    , total_count : Int }

-- init : Session -> Api.Check ->(Model, Cmd Msg)
init session mobile
    = (
        { session = session
        , checkDevice = ""
        , check = mobile
        , page = 1
        , deleteId = 0
        , deleteComplete = False
        , dataList = []
        , checkList = []
        , errAuth = ""
        , loading = True
        , show = ""
        , pageNum = 1
        , infiniteLoading = False
        , per_page = 10
        , screenInfo = 
            { scrollHeight = 0
            , scrollTop = 0
            , offsetHeight = 0}
        , data = 
            { data = []
            , paginate = 
                { inserted_id = 0
                , page = 0
                , per_page = 0
                , total_count = 0 }
            }}
        , Cmd.batch [
            mypostList 1 10 session
            , Api.removeJw ()
        ]
    )

scrollEvent msg = 
    on "scroll" (Decode.map msg scrollInfoDecoder)



scrollInfoDecoder =
    Decode.map3 ScreenInfo
        (Decode.at [ "target", "scrollHeight" ] Decode.int)
        (Decode.at [ "target", "scrollTop" ] Decode.int)
        (Decode.at [ "target", "offsetHeight" ] Decode.int)  

mypostList page per_page session = 
    let
        body = 
            Encode.object
                [ ("page" , Encode.int page) 
                , ("per_page" ,Encode.int per_page)]    
                |> Http.jsonBody
    in
    (Decoder.mypostdata DataList Data Paginate)
    |> Api.post Endpoint.myPost (Session.cred session) GetList body 

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch[Api.successId SaveId
    , Session.changes GotSession (Session.navKey model.session)]
    -- P.check CheckDevice

type Msg 
    = GetList (Result Http.Error DataList)
    | BackBtn
    | DeletePost 
    | DeleteComplete (Result Http.Error Decoder.Success)
    | PageBtn (Int, String)
    | ScrollEvent ScreenInfo
    | GetId String
    | SaveId Encode.Value
    | GotSession Session
    | NoOp
    | DeleteConfirm Int

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check
-- Endpoint.myPostDelete id

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            (model, Cmd.none)
        GotSession session ->
            if model.errAuth == "delete" then
            ({model | session =session},  
            (Decoder.resultD)
            |> Api.get DeleteComplete (Endpoint.myPostDelete (String.fromInt(model.deleteId))) (Session.cred session ) )
            else
            ({model | session =session}, mypostList model.page model.per_page session)
        SaveId complete ->
            let
                c = Decode.decodeValue Decode.string complete
            in
            case c of
                Ok ok ->
                    (model,
                    Route.pushUrl (Session.navKey model.session) Route.PostD
                    -- Api.historyUpdate (Encode.string "myPostDetail")
                     )
            
                Err _ ->
                    (model, Cmd.none)
        GetId id ->
            let
                encodeId = Encode.string id
            in
            
            (model, Api.saveId encodeId)
        ScrollEvent { scrollHeight, scrollTop, offsetHeight } ->
             if (scrollHeight - scrollTop) <= offsetHeight then
                -- case toInt of
                --     Just val ->
                        -- if (val  < (model.takeList + 10)) then
                        --     ({model | takeList = val, infiniteLoading = False},Cmd.none)
                        -- else 
                if List.length model.checkList > 0 then
                (model, Cmd.none)
                else
                ({model | infiniteLoading = True}, mypostList model.page model.per_page model.session)
                    -- Nothing ->
                    --     (model, Cmd.none)
                
            else
                (model, Cmd.none)
        PageBtn (idx, str) ->
            case str of
                "prev" ->
                    ({model | page = idx, pageNum = model.pageNum - 1}, mypostList idx model.per_page model.session)
                "next" ->
                    ({model | page = idx, pageNum = model.pageNum + 1}, mypostList idx model.per_page model.session)
                "go" -> 
                    ({model | page = idx}, mypostList idx model.per_page model.session)
                _ ->
                    (model, Cmd.none)
        DeleteComplete (Ok ok) ->
            let
                text = Encode.string "삭제 되었습니다."
            in
            
            ({model | deleteComplete = True}, Cmd.batch[mypostList 1 model.per_page model.session, Api.showToast text])
        DeleteComplete (Err err) -> 
            let
                serverErrors = 
                    Api.decodeErrors err    
            in
            
            ({model | errAuth = "delete"}, (Session.changeInterCeptor (Just serverErrors) model.session))
        DeleteConfirm id ->
            if id == 0 then
            ({model | deleteId = id, show = ""},Cmd.none)
            else
            ({model | deleteId = id, show = "logoutShow"},Cmd.none)
        DeletePost ->
            ({model | show = ""}, 
            (Decoder.resultD)
            |> Api.get DeleteComplete (Endpoint.myPostDelete (String.fromInt(model.deleteId))) (Session.cred model.session ) )
        GetList (Ok ok) ->
            if model.deleteComplete then
            ({model | data = ok, dataList = ok.data, page = model.page, deleteComplete = False, loading = False}, (scrollToTop NoOp))
            else
                if ok.data == [] then
                ({model | infiniteLoading = False, checkList = ["empty"], loading = False}, Cmd.none)
                else
                ({model | data = ok, dataList = model.dataList ++ ok.data, page = model.page + 1, infiniteLoading = False, loading = False}, Cmd.none)
        GetList (Err err) ->
            let
                serverErrors = Api.decodeErrors err
            in
            
            (model, Session.changeInterCeptor (Just serverErrors) model.session) 
        BackBtn ->
            (model, Route.backUrl(Session.navKey model.session) 1)
            

view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
        if model.loading then
        { title = "내 게시물"
        , content = div [class "spinnerBack"] [
                            spinner
                            ]
        }
        else
            if List.length model.dataList > 0 then
            { title = "내 게시물"
            , content = 
                div [] [ app model appcontentsBody]
            }
            else
            { title = "내 게시물"
            , content = 
                div [] [ app model noappcontentsBody]
            }
    else
        if List.length (model.data.data) > 0 then
        { title = "내 게시물"
        , content = 
            div [] [
                div [ class "container" ]
            [
                commonJustHeader "/image/icon_management.png" "나의 게시물관리"
                , contentsBody model.data model.pageNum model.show
                
            ]
            ]
        }
        else
        { title = "내 게시물"
        , content = 
            div [] [
                div [ class "container" ]
        [
            commonJustHeader "/image/icon_management.png" "나의 게시물관리"
            , nocontentsBody model.data model.pageNum model.show
            
        ]
            ]
        }

justData item =
    case item of
        Just val ->
            val
    
        Nothing ->
            "내용 없음"

web model= 
     div [ class "container" ]
        [
            commonJustHeader "/image/icon_management.png" "나의 게시물관리"
            , contentsBody model.data model.pageNum model.show
            
        ]
app model appcontent=
    div[class "container"] [
        appHeaderRDetail "나의 게시물관리" "myPageHeader whiteColor" Route.MyPage "fas fa-angle-left"
        , appcontent model.dataList model.infiniteLoading model.loading model.show
    ]
nocontentsBody model pageNum show=
    div [ class "myPost_searchbox" ]
        [ div [ class "myPost_mediabox" ]
            [ 
            ul [class "m_cbp_tmtimeline"]
                [
                    li [class "noResult"] [text "나의 게시물이 없습니다."]
                ]
        ]
        ]
contentsBody model pageNum show=
    div [ class "myPost_searchbox" ]
        [ div [ class "myPost_mediabox" ]
            [ 
            
            div[] [ul [ class "cbp_tmtimeline" ]
            (List.map contentsLayout model.data)
            
            , pagination 
                PageBtn
                model.paginate
                pageNum]
        ]
        , deltelayer show
        ]
appcontentsBody model infiniteloading loading show=
    div [ class "myPost_searchbox" ]
        [  div [ class "m_myPost_mediabox", scrollEvent ScrollEvent ]
            [ 
                ul [ class "m_cbp_tmtimeline" ]
                (List.map appcontentsLayout model)
                ,if infiniteloading then
                    div [class "loadingPosition"] [
                    infiniteSpinner
                    ]
                else
                span [] []
               
        ]
        , appdeltelayer show
        ]
noappcontentsBody model infiniteloading loading show=
    div [ class "myPost_searchbox" ]
        [  div [ class "m_myPost_mediabox", scrollEvent ScrollEvent ]
            [ 
                ul [class "m_cbp_tmtimeline"]
                [
                    li [class "noResult"] [text "나의 게시물이 없습니다."]
                ]
               
        ]
        ]
contentsLayout item= 
    li []
        [ time [ class "cbp_tmtime" ]
            [ span []
                [ text (String.dropRight 10 item.inserted_at) ]
            , span []
                []
            ]
        , div [ class "cbp_tmicon icon1" ]
            [ 
                i [ class "fas fa-video" ]
                []
            ]
        , div [ class "cbp_tmlabel " ]
            [ pre [onClick (GetId (String.fromInt(item.id))), class "descriptionBackground"]
                [ text (justData item.content) ]
            , p []
                [ div [ class "button is-danger", onClick (DeleteConfirm (item.id)) ]
                    [ text "삭제" ]
                ]
            ]
        ]

appcontentsLayout item= 
    li []
        [ time [ class "m_cbp_tmtime" ]
            [ span []
                [ text (String.dropRight 10 item.inserted_at) ]
            , span []
                []
            ]
        , div [ class "m_cbp_tmicon icon1" ]
            [ 
                i [ class "fas fa-video" ]
                []
            ]
        , div [ class "m_cbp_tmlabel" ]
            [ pre [onClick (GetId (String.fromInt(item.id))), class "descriptionBackground"]
                [ text (justData item.content) ]
            , p []
                [ div [ class "button danger m_mypost_btn",
                onClick (DeleteConfirm item.id) ]
                    [ text "삭제" ]
                ]
            ]
        ]
    


appdeltelayer show =
    div [class ("m_delete_post " ++ show)] [
         div [ class "yf_delete_popup" ]
            [ h1 [ class "popup_yf" ]
                [ text "게시물을 삭제하시겠습니까?" ]
            , p [ class "yf_logout_butbox" ]
                [ div [ class "button is-light logout_danger2", onClick (DeleteConfirm 0) ]
                    [ text "취소" ]
                , div [ class "button is-danger logout_cencel2", onClick DeletePost ]
                    [ text "삭제" ]
                ]
            ]
    ]

deltelayer show =
    div [class ("delete_post " ++ show)] [
         div [ class "yf_delete_popup" ]
            [ h1 [ class "popup_yf" ]
                [ text "게시물을 삭제하시겠습니까?" ]
            , p [ class "yf_logout_butbox" ]
                [ div [ class "button is-light logout_danger2", onClick (DeleteConfirm 0) ]
                    [ text "취소" ]
                , div [ class "button is-danger logout_cencel2", onClick DeletePost ]
                    [ text "삭제" ]
                ]
            ]
    ]