module Page.MyPageMenu.PaperWeightList exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing(..)
import Api as Api
import Json.Encode as Encode
import Json.Decode as Decode
import Route as Route
import Http as Http
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder

type alias Model =
    { session : Session
    , check : Bool
    , showMenu : Bool
    , selected_item : String
    , ableToWatch : Bool
    , page : Int
    , per_page : Int
    , is_pay : Maybe Bool
    , data : List DataList
    , price : List String
    , pageNum : Int
    , paginate : Pagenate
    }

type alias WatchCheckData = 
    { data : Bool }

type alias Data = 
    { data : List DataList 
    , paginate : Pagenate }

type alias DataList = 
    { bought_at : String
    , end_at : String
    , id : Int
    , is_ing : Bool
    , name : String
    , price : Int
    , start_at : String
    , state : String }

type alias Pagenate  = 
    { is_pay : Maybe Bool
    , page : Int
    , per_page : Int
    , total_count : Int
    , user_id : Int }

dataListApi : Int -> Int -> String -> Session -> Cmd Msg
dataListApi page per_page selected_item session = 
    let
        body = 
            Encode.object 
                [ ("page", Encode.int page)
                , ("per_page", Encode.int per_page)
                , ("is_pay"
                    , (case selected_item of 
                        "all" ->
                            Encode.null
                        "pay" ->
                            Encode.bool True
                        "free" ->
                            Encode.bool False
                        _ ->                 
                            Encode.null   
                        )   
                    )]
                |> Http.jsonBody
    in
    Api.post Endpoint.orders (Session.cred session) GetListData body (Decoder.ordersData Data DataList Pagenate)


init : Session -> Bool ->(Model, Cmd Msg)
init session mobile = 
    (
    { session = session 
    , check = mobile 
    , showMenu = False
    , selected_item = "all"
    , ableToWatch = False
    , page = 1
    , per_page = 10
    , is_pay = Nothing 
    , data = []
    , price = []
    , pageNum = 1
    , paginate = 
        { is_pay = Nothing
        , page = 1
        , per_page = 10
        , total_count = 0
        , user_id = 0 }
    }
    , dataListApi 1 10 "all" session
    )

type Msg 
    = NoOp
    | ClickRight
    | ClickLeft
    | GoAnotherPage
    | ShowMenu
    | SelectedItem String
    | PossibleToWatch (Result Http.Error WatchCheckData)
    | GetListData (Result Http.Error Data)
    | PriceFormat Encode.Value
    | GotSession Session
    | PageBtn (Int, String)

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PageBtn (idx, str) ->
            let
                idxEncode = Encode.int idx
            in
            
            case str of
                "prev" ->
                    ({model | page = idx, pageNum = model.pageNum - 1}, Cmd.batch[dataListApi model.page model.per_page model.selected_item model.session])
                "next" ->
                    ({model | page = idx, pageNum = model.pageNum + 1}, Cmd.batch[dataListApi model.page model.per_page model.selected_item model.session])
                "go" -> 
                    ({model | page = idx}, Cmd.batch[dataListApi model.page model.per_page model.selected_item model.session])
                _ ->
                    (model, Cmd.none)
        GotSession session ->
            ({model | session = session},
            dataListApi model.page model.per_page model.selected_item session)
        PriceFormat format ->  
            let
               formtDecode =    
                    Decode.decodeValue (Decode.list Decode.string) format
            in
                case formtDecode of
                    Ok ok ->
                        ({model | price = ok}, Cmd.none)
                    Err err ->
                        (model, Cmd.none)
        GetListData (Ok ok) ->
            let
                price = 
                    List.map(\x -> x.price) ok.data
                priceEncode = 
                    Encode.object
                        [ ("price", (Encode.list (Encode.int)) price) ]
            in
            ({model | data = ok.data}, Cmd.batch
            [ Api.comma priceEncode
            , Api.get PossibleToWatch (Endpoint.possibleToCheck) (Session.cred model.session) (Decoder.possibleToWatch WatchCheckData)])
        GetListData (Err err) ->
            let
                serverErrors =
                    Api.decodeErrors err
            in 
            (model, Session.changeInterCeptor (Just serverErrors) model.session)
        PossibleToWatch (Ok ok) ->
            ({model | ableToWatch = ok.data},
            Cmd.none
            )
        PossibleToWatch (Err err) -> 
            (model, Cmd.none)
        SelectedItem item ->
            ({model | selected_item = item}, 
            dataListApi model.page model.per_page item model.session
            )
        ShowMenu ->
            ({model | showMenu = not model.showMenu}, Cmd.none)
        GoAnotherPage ->
            (model, Cmd.batch [
                 Api.setCookie (Encode.int 1)
            ])
        ClickRight ->
            ( model, Api.scrollRight () )
        ClickLeft ->
            (model , Api.scrollLeft ())
        NoOp ->
            ( model, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions model = 
    Sub.batch[
        Session.changes GotSession (Session.navKey model.session)
        , Api.commaF PriceFormat]


view : Model -> { title : String , content : Html Msg}
view model =

    if model.check then
    { title = "YourFitExer"
    , content = div [] [
        appHeaderRDetail "최근구매내역" "myPageHeader whiteColor" Route.MyPage "fas fa-angle-left"
        , recentBuylist model ]
    }

    else
    { title = "YourFitExer"
    , content = div [] [
        div [class "mypageHiddenMenu", onClick ShowMenu] []
            , div[][myPageCommonHeader ClickRight ClickLeft GoAnotherPage model.showMenu]
            , div [ class "container" ]
            [ commonJustHeader "/image/icon_cart.png" "최근구매내역"
            , recentBuylist model 
            , pagination 
                PageBtn
                model.paginate
                model.pageNum
                ]
        ]
    }



recentBuylist : Model -> Html Msg
recentBuylist model = 
    div [ class "searchbox_wrap" ]
                    [  if model.ableToWatch then
                            div [class "success_cart"][
                                h1 [class"cart_warning_h1"]
                                [ text "맞춤운동이 시청 가능한 상태입니다." ]
                            ]
                        else
                            if List.isEmpty model.data then
                                div [ class "cart_warning" ]
                                [ h1 [class"cart_warning_h1"]
                                [ text "구매내역이 없습니다." ]
                                ]
                            else
                              div [ class "cart_warning" ]
                                [ h1 [class"cart_warning_h1"]
                                [ text "구매하신 유어핏 서비스 기간이 종료되었습니다."]
                                ]
                    , div [ class "control" ]
                        [ ul [class "btn_buyList"]
                            [ li [class (if model.selected_item == "all" then "selected_item" else ""), onClick (SelectedItem "all")][text "전체"]
                            , li [class (if model.selected_item == "pay" then "selected_item" else ""),  onClick (SelectedItem "pay")][text "유료"]
                            , li [class (if model.selected_item == "free" then "selected_item" else ""),  onClick (SelectedItem "free")][text "무료"]
                            ]
                        ]
                    , div [ class "searchbox" ]
                        [ div [ class "cart_mediabox" ]
                            [ table [ class "purchasehistory_table" ]
                                [ thead [ class "history_tbody" ]
                                    [ tr [ class "history_tr" ]
                                        [ th []
                                            [ text "상품명" ]
                                        , th []
                                            [ text "결제일" ]
                                        , th []
                                            [ text "종료일" ]
                                        , th []
                                            [ text "결제금액" ]
                                        , th []
                                            [ text "유효상태" ]
                                        ]
                                    ]
                                     , if List.isEmpty model.data then 
                                    tr [class "history_tr"][
                                        td [ colspan 6 ][text "구매내역이 없습니다."]
                                    ]
                                    else
                                    tbody []
                                        (List.map2 listDataLayout model.data model.price)
                                ]
                                
                            ]
                        ]
                    ]
             
        
listDataLayout : DataList -> String -> Html Msg
listDataLayout item price =
    tr [class "history_tr"][
    td [class"history_td"]
            [ text item.name ]
        , td [class"history_td"]
            [ text (String.dropRight 15 item.bought_at)
            , br []
                [], text (String.dropRight 6 (String.dropLeft 11 item.bought_at))
            ]
        , td [class"history_td"]
            [ text (String.dropRight 15 item.end_at)
            , br []
                [], text (String.dropRight 6 (String.dropLeft 11 item.end_at))
            ]
        , td [class"history_td"] 
                [ text (price ++ "원")]
            
        , td [class"history_td"]
            [ text item.state ]
    ]
