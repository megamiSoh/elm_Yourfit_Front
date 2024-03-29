port module Page.Home exposing (..)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes as Atrr exposing(..)
import Session exposing(Session)
import Json.Encode as E
import Json.Decode as Decode
import Route exposing(..)
import Api as Api
import Page as P
import Html.Lazy exposing (lazy)
import Page.Common exposing (..)
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
import Http as Http
import Random
import Page.YourFitPrice  as YP exposing (Msg (..))

type alias Model = 
    { session : Session
    , title : String
    , check : Bool
    , image : String
    , splash : Bool
    , bannerList : List BannerList
    , bannerIndex : Int
    , bannerPosition : String
    , transition : String
    , checkId : String
    , last_bullet : Int
    , random: Int
    , horizontal : List BannerList
    , yourfitPriceOpen : Bool
    , yf_price : YP.Model
    }


type alias SessionCheck = 
    { id : Int
    , username : String }

type alias BannerListData = 
    { data : List BannerList }

type alias BannerList =
    { description : String
    , id : Int
    , is_link : Bool
    , link : Maybe String
    , src : String
    , target : Maybe String
    , title : String
    , backcolor : Maybe String
    , is_vertical : Bool 
    }

bannerApi : Session -> Bool -> ( Result Http.Error BannerListData -> Msg ) -> Cmd Msg
bannerApi session vertical msg = 
    let
        body = 
            E.object 
                [( "is_vertical", E.bool vertical)]
                |> Http.jsonBody
    in
    Api.post Endpoint.bannerList (Session.cred session) msg body(Decoder.bannerListdata BannerListData BannerList)

init : Session -> Bool ->(Model, Cmd Msg)
init session mobile=
    let
        ( yf_price, yf_price_msg ) = 
            YP.init session mobile
    in
    (
        { session = session
        , title = "" 
        , check = mobile
        , splash = if Session.viewer session == Nothing then False else True
        , image = "/image/lazy_bg_back.jpg"
        , bannerList = []
        , bannerIndex = 0
        , bannerPosition = ""
        , transition = "shiftThing"
        , checkId = ""
        , last_bullet = 5
        , random = 0
        , horizontal = []
        , yourfitPriceOpen = False
        , yf_price = yf_price
        }
       , Cmd.batch[scrollToTop NoOp
       , Cmd.map Yf_price_Msg yf_price_msg
        , Api.progressCalcuration ()
        , bannerApi session True BannerComplete
        , bannerApi session False HorizonTalBannerComplete
        , Api.hamburgerShut ()
        ]
    )

type Msg 
    = NoOp 
    | LoadImg
    | Complete E.Value
    | BannerComplete (Result Http.Error BannerListData)
    | SlideMove String
    | SilderRestart E.Value
    | AutoSlide E.Value
    | TransitionCheck E.Value
    | SwipeDirection E.Value
    | BulletGo Int
    | OpenPop
    | HorizonTalBannerComplete (Result Http.Error BannerListData)
    | Yf_price_Msg YP.Msg

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


subscriptions :Model -> Sub Msg
subscriptions model=
    Sub.batch
    [ Api.calcurationComplete Complete
    , Api.sliderRestart SilderRestart
    , Api.autoSlide AutoSlide
    , Api.transitionCheck TransitionCheck
    , Api.swipe SwipeDirection
    , Sub.map Yf_price_Msg (YP.subscriptions model.yf_price)
    ]

onLoad : msg -> Attribute msg
onLoad msg =
    on "load" (Decode.succeed msg)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Yf_price_Msg ypMsg ->
            YP.update ypMsg model.yf_price
                |> (\( data, cmd ) ->
                        ( {model | yf_price = data}
                        , Cmd.map Yf_price_Msg cmd
                        )
                   )

                |> (\( newModel, cmd ) ->
                        (newModel, cmd)
                   )
        OpenPop ->
            ({model | yourfitPriceOpen = not model.yourfitPriceOpen}, Cmd.none)
        BulletGo idx ->
            ({model | transition = "", bannerPosition = "-" ++ String.fromInt (idx * 100), bannerIndex = idx, last_bullet = 150}, Cmd.none)
        SwipeDirection direction ->
            case Decode.decodeValue Decode.string direction of
                Ok ok ->
                    case ok of
                        "right" ->
                            update (SlideMove "right") model
                        "left" ->
                            update (SlideMove "left") model
                        _ ->
                            (model, Cmd.none)
                Err err ->
                    (model, Cmd.none)
        TransitionCheck check ->
            case Decode.decodeValue Decode.string check of
                Ok ok ->
                    case ok of 
                        "right" ->
                            ({model | transition = "", bannerPosition = "0", bannerIndex = 0}, Cmd.none)
                        "left" ->
                            ({model | transition = "", bannerPosition = "-" ++ String.fromInt ((List.length model.bannerList) * 100)}, Cmd.none)
                        _ ->
                            ({model | checkId = ""}, Cmd.none)
                Err err ->
                    (model, Cmd.none)
        AutoSlide auto ->
            let
                index = 
                    if List.length model.bannerList >= model.bannerIndex then model.bannerIndex + 1 else 0
            in
            if model.bannerPosition == "-" ++ String.fromInt ((List.length model.bannerList) * 100) then
            (model, Cmd.none)
            else
                    ({model | bannerIndex = index
                    , bannerPosition = "-" ++ String.fromInt ((model.bannerIndex + 1) * 100)
                    , transition = "shiftThing"
                    , last_bullet = if List.length model.bannerList == index then 0 else 150}
                    , Cmd.none)
        SilderRestart restart ->
            (model, Cmd.none)
        SlideMove direction ->
            case direction of
                "right" ->
                    let
                        index = 
                            if List.length model.bannerList >= model.bannerIndex then model.bannerIndex + 1 else 0
                    in
                    if model.bannerPosition == "-" ++ String.fromInt ((List.length model.bannerList) * 100) then
                    (model, Cmd.none)
                    else
                            ({model | bannerIndex = index
                            , bannerPosition = "-" ++ String.fromInt ((model.bannerIndex + 1) * 100)
                            , transition = "shiftThing"
                            , checkId = "stopInterval"
                            , last_bullet = if List.length model.bannerList == index then 0 else 150}
                            , Cmd.none)
                    
                "left" ->
                    let
                        index = 
                            if 1 < model.bannerIndex then model.bannerIndex - 1 else List.length model.bannerList
                    in
                    if model.bannerPosition ==  "-0"  then
                    (model, Cmd.none)
                    else
                    ({model | bannerIndex = index
                    , bannerPosition = "-" ++ String.fromInt ((model.bannerIndex - 1) * 100)
                    , transition = "shiftThing"
                    , checkId = "stopInterval"
                    , last_bullet = if List.length model.bannerList == index then 0 else 150}
                    , Cmd.none)
                _ ->
                    (model, Cmd.none)
        BannerComplete (Ok ok) ->
            ({model | bannerList = ok.data}
            , Cmd.batch[Api.slide (E.string (String.fromInt (List.length ok.data)))])
        BannerComplete (Err err) ->
            (model, Cmd.none)
        HorizonTalBannerComplete (Ok ok) ->
            ({model | horizontal = ok.data} , Cmd.none)
        HorizonTalBannerComplete (Err err) ->
            (model, Cmd.none)
        Complete val ->
            ({model | splash = False}, Cmd.none)
        LoadImg ->
            ({model | image = "/image/bg_back.png"}, Cmd.none)
        NoOp ->
            (model, Cmd.none)
    
view : Model -> {title : String , content : Html Msg}
view model =
    {
    
    title = "YourFit"
    , content = 
       webOrApp model
    }

caseList : List BannerList -> BannerList
caseList item = 
    case List.head item of
                Just list ->
                    list
                Nothing ->
                    { description = ""
                    , id = 0
                    , is_link = False
                    , link = Nothing
                    , src = ""
                    , target = Nothing
                    , title = ""
                    , backcolor = Nothing
                    , is_vertical = False}

webOrApp : Model -> Html Msg
webOrApp model =
    let
        bannerFirst = 
            caseList model.bannerList

    in
    if model.check then
        div [class "appWrap"] [
            home,
             div [class "home_main_top"]
            [ div [ class "app_bannerimg_container", id  ("slideId " ++ model.checkId) ]
                [ div [class ("bannerList_items " ++  model.transition), id "slide", style "left" (model.bannerPosition ++ "%")] (List.map(\x ->  banner x "bannerimg_container") model.bannerList 
                ++ [banner bannerFirst "bannerimg_container"]
                )  
                , 
                div [class "bullet_container"] (List.indexedMap (\idx x -> bulletitems idx x model) model.bannerList)
                ]
            
            ],
            div [class "homemenu"]
            [ div [ class "home_main_middle" ]
            [ 
                apphomeDirecMenu        
            ]   
            , div [class "bottom_bannerImg"](List.map(\x ->  banner x "") model.horizontal ) 
      ]
    ]
    else 
         div [class"yf_home_wrap"]
        [ 
            div [class "home_main_top "]
            [ div [ class "bannerList_container", id model.checkId]
                [ i [ class "fas fa-chevron-left sliderBtn" , onClick (SlideMove "left")]
                []
                , div [class ("bannerList_items " ++  model.transition), id "slide", style "left" (model.bannerPosition ++ "%")] (  List.map (\x ->  banner x "web_bannerimg_container") model.bannerList 
                ++ [banner bannerFirst "web_bannerimg_container" ]
                )  
                , i [ class "fas fa-chevron-right sliderBtn" , onClick (SlideMove "right")] []
                , 
                    div [class "bullet_container"] (List.indexedMap (\idx x -> bulletitems idx x model) model.bannerList)
                ]
            ],
         div [ class "container is-widescreen" ]
            [ homeDirectMenu
            , div [class "bottom_bannerImg"](List.map (\x ->  banner x "web_bannerimg_container") model.horizontal)
            , P.viewFooter
            ]
        , div [class "paperweightLayer", style "display" (if model.yourfitPriceOpen then "flex" else "none")][
            div [class "makeExercise_paperWeight_slideContainer"][
            div [class "yp_price_slide_layer"][
                div [class "button yf_price_top_btn is-danger", onClick OpenPop][text "닫기"]
                , YP.weblayout  model.yf_price
                    |> Html.map Yf_price_Msg 
                ]
        ]
        ]
        ]
 
bulletitems : Int -> BannerList -> Model -> Html Msg
bulletitems idx item model = 
    div [classList 
        [("bullet_items", True)
        , ("selected_bullet", model.bannerIndex == idx)
        , ("selected_bullet",  model.last_bullet == idx )
        ]
        , onClick (BulletGo idx)
        ][]

apphomeDirecMenu : Html Msg 
apphomeDirecMenu =
    div [ class "columns home_yf_columns" ]
        [ a [ class "home_yf_columns_column1 main_middle_1 main_middle_size" , Route.href Route.Info ]
            [  i [ class "fas fa-align-justify" ]
                    []
                , text "공지사항"
            ]
            
          , a [ class "home_yf_columns_column1 main_middle_1 main_middle_size", Route.href Route.YP]
                    [ i [ class "fas fa-won-sign" ]
                            []
                        , text "유어핏 가격"
                    ]

          , a [ class "home_yf_columns_column1 main_middle_1 main_middle_size" , Route.href Route.Faq ]
                    [  i [ class "fas fa-question" ]
                            []
                        , text "자주하는 질문"
                    ]
        ]

homeDirectMenu : Html Msg 
homeDirectMenu = 
    div [ class "home_main_middle" ]
    [ div [ class "columns home_yf_columns" ]
        [ a [ class "home_yf_columns_column1" , Route.href Route.Info ]
            [  p [ class "main_middle_1"]
          
                      [ i [ class "fas fa-align-justify" ]
                            []
                        , text "공지사항"
                        ]
            ]
            
          , div [ class "home_yf_columns_column1", onClick OpenPop ]
                    [ p [ class "main_middle_1" ]
                        [ i [ class "fas fa-won-sign" ]
                            []
                        , text "유어핏 가격"
                        ]
         
                    ]

          , a [ class "home_yf_columns_column1", Route.href Route.Faq  ]
                    [ p [ class "main_middle_1"]
                        [ i [ class "fas fa-question" ]
                            []
                        , text "자주하는 질문"
                        ]
         
                    ]
        ]
                   
    ] 

lazyview : String -> Html Msg
lazyview image= 
     div [ class "home_main_top lazyimage", 
        style "background-size" "cover" ,
        style "background" ("0px -20rem / cover no-repeat url(" ++ image ++") fixed") 
        ]
        [ div [ class "home_main_box_warp" ]
            [ div [ class "home_main_box" ]
              []
            ]
            ,
            img [src "image/bg_back.png", onLoad LoadImg, class "shut"] []
        ]

caseString : Maybe String -> String    
caseString item= 
    case item of
        Just ok ->
            ok
        Nothing ->
            ""

banner : BannerList -> String -> Html Msg        
banner item styles=
        a [class styles, style "background-color" (caseString item.backcolor), Atrr.href (caseString item.link), target (caseString item.target)][img [src item.src, onLoad LoadImg, class "slideItems"] []]

home : Html Msg 
home =
     div [class "headerSpace"] [
    div [ class " m_home_topbox" ]
            [ img [ src "https://yourfitbucket.s3.ap-northeast-2.amazonaws.com/images/logo.png", alt "logo" ]
                []
            ]
     ]