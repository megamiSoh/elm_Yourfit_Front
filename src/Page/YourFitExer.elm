port module Page.YourFitExer exposing (..)

import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Json.Decode as Decode
import Route exposing(..)
import Page.Common exposing (..)
import Api.Endpoint as Endpoint
import Api as Api
import Http as Http
import Api.Decoder as Decoder
import Json.Encode as Encode
import Swiper
import Html.Lazy exposing (lazy, lazy2, lazy3)
import Page.Common exposing (..)
import Page.Detail.YourFitDetail as YfD

type alias Model = 
    { session : Session
    , title : String
    , checkDevice : String
    , data : List ListData
    , check : Bool
    , loading : Bool
    , sumCount : Int
    , menuOpen : Bool
    , swipingState : Swiper.SwipingState
    , swipeCode : String
    , leftWidth : Int
    , lazyImg : String
    , count : Int
    , scrap : Bool
    , need2login : Bool
    , videoId : String
    , zindex : String
    , listData : YfD.DetailData
    , detailShow : Bool
    , errType : String
    }

type alias YourFitList =
    { data : List ListData }

type alias ListData = 
    { code : String
    , exercises : List ExerciseList
    , name : String
    }

type alias ExerciseList = 
    { difficulty_name : String
    , duration : String
    , exercise_part_name : String
    , id : Int
    , mediaid : String
    , thembnail: String
    , title : String
    }

init : Session -> Bool ->(Model, Cmd Msg)
init session mobile =
     (
        { session = session
        , check = mobile
        , title = ""
        , checkDevice = ""
        , data = []
        , swipeCode = ""
        , scrap = False
        , loading = True
        , zindex = ""
        , sumCount = 0
        , menuOpen = False
        , count = 1
        , leftWidth = 0
        , videoId = ""
        , detailShow = False
        , need2login = False
        , listData = 
            { difficulty_name = Nothing
            , duration = ""
            , exercise_items = []
            , exercise_part_name = Nothing
            , id = 0
            , inserted_at = ""
            , pairing = []
            , title = ""
            , nickname = Nothing
            , thumbnail = ""
            , description = Nothing}
        , lazyImg = "../image/05iu6bgl-320.jpg"
        , swipingState = Swiper.initialSwipingState
        , errType = ""
        }
        , Cmd.batch
        [  
            Decoder.yourfitList YourFitList ListData ExerciseList
                |> Api.get GetList Endpoint.yourfitVideoList (Session.cred session) 
            , Api.removeJw ()
            , mydata session
            , scrollToTop NoOp
            , Api.hamburgerShut ()
        ]
    )
mydata : Session -> Cmd Msg
mydata session = 
    Decoder.sessionCheckMydata
        |> Api.get MyInfoData Endpoint.myInfo (Session.cred session)
type Msg 
    = CheckDevice Encode.Value
    | GetList (Result Http.Error YourFitList)
    | GoDetail String
    | MyInfoData (Result Http.Error Decoder.DataWrap)
    | Success Encode.Value
    | GoContentsDetail Int
    | SuccessId Encode.Value
    | GotSession Session
    | Swiped String Swiper.SwipeEvent 
    | GetIndex String
    | OnLoad String
    | MoveMore Int
    | MoveLeft Int
    | NoOp
    | Scrap
    | ScrapComplete (Result Http.Error Decoder.Success)
    | BackPage
    | GoVideo (List YfD.Pairing)
    | GetListData (Result Http.Error YfD.GetData)

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check

onLoad msg =
    on "load" (Decode.succeed msg)

subscriptions :Model -> Sub Msg
subscriptions model=
    Sub.batch
    [ Api.successSave Success
    , Session.changes GotSession (Session.navKey model.session)
    , Api.successId SuccessId]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GetListData (Ok ok) -> 
             ({model | listData = ok.data, scrap = False, loading = False}, scrollToTop NoOp)
        GetListData (Err err) -> 
            let 
                serverErrors = Api.decodeErrors err
            in
            if serverErrors == "401" then
            (model, (Session.changeInterCeptor(Just serverErrors)model.session))
            else
            (model, Cmd.none)
        GoVideo pairing->
            let
                videoList = 
                    Encode.object 
                        [("pairing", (Encode.list videoEncode) pairing) ]

                videoEncode p=
                    Encode.object
                        [ ("file", Encode.string p.file)
                        , ("image", Encode.string p.image)
                        , ("title", Encode.string p.title)
                        ]
            in
             ({model | zindex = "zindex"}, Api.videoData videoList)
        BackPage ->
            if model.need2login then
            ({model |  need2login = False, zindex = ""}, Cmd.none)
            else
            ({model | detailShow = False, zindex = "", need2login = False}, Api.hideFooter ())
        ScrapComplete (Ok ok) ->
            let
                text = Encode.string "스크랩 되었습니다."
            in
            
            ({model | scrap = not model.scrap}, Api.showToast text )
        ScrapComplete (Err err) ->
            let
                error = Api.decodeErrors err
                cannotScrap = Encode.string "이미 스크랩 되었습니다."
            in
            if error == "401" then
                ({model | need2login = True, detailShow = False, errType ="scrap"}, 
                Cmd.batch [
                    Api.hideFooter () 
                    , scrollToTop NoOp
                    , Session.changeInterCeptor (Just error) model.session
                ])
            else
                (model, Api.showToast cannotScrap)
        Scrap ->
            (model, 
            Decoder.resultD
            |> Api.get ScrapComplete (Endpoint.scrap model.videoId)(Session.cred model.session) )
        NoOp ->
            (model, Cmd.none)
        MyInfoData (Ok ok) ->
            (model, Cmd.none) 
        MyInfoData (Err err) ->
           let
                serverErrors =
                    Api.decodeErrors err
            in  
            ({model | errType = "myInfo"}, (Session.changeInterCeptor (Just serverErrors) model.session))
        MoveLeft idx ->
            (model, Api.scrollL (Encode.string (String.fromInt idx)) )
        MoveMore idx ->
            (model, Api.scrollR (Encode.string (String.fromInt idx)))
        OnLoad idx->
            if model.count >= model.sumCount then
            ({model | loading = False}, Cmd.none)
            else
            ({model | count = model.count + 1}, Cmd.none)
        GetIndex str -> 
            (model, Cmd.none)
        Swiped str evt ->
            let 
                ( newState, swipedLeft ) =
                    Swiper.hasSwipedRight evt model.swipingState
            in
                ( { model | menuOpen = swipedLeft, swipingState = newState, swipeCode = str , leftWidth = -200}, Cmd.none )
        GotSession session ->
            ({model | session = session}
            , case model.errType of
                "scrap" ->
                    Decoder.resultD
                    |> Api.get ScrapComplete (Endpoint.scrap model.videoId)(Session.cred session)
                    
                "myInfo" ->
                    mydata session
                _ ->
                    mydata session
            )
        SuccessId str ->  
            (model, 
            Route.pushUrl (Session.navKey model.session) Route.YourfitDetail
            )

        GoContentsDetail id ->
            let 
                encodeId = Encode.int id
                stringId = String.fromInt id
            in
            if model.check then
                    ({model | detailShow = True,  videoId = stringId}, 
                    Cmd.batch[(Decoder.yfDetailDetail YfD.GetData YfD.DetailData YfD.DetailDataItem YfD.Pairing)
                    |>Api.get GetListData (Endpoint.yfDetailDetail (stringId) ) (Session.cred model.session) 
                    , Api.hideFooter ()
                    , Api.videoData (Encode.string "") ]
                    )
            else
            (model, Api.saveId (encodeId))
        Success str ->
            (model,
            Route.pushUrl (Session.navKey model.session) Route.YourFitList
            )
        GoDetail code ->
            let
                go = Encode.string code
            in
            (model, Api.saveKey go)
        GetList (Ok ok) ->
            let
                new = List.map (\x ->
                        List.length (x.exercises)
                    ) ok.data
                result = List.sum new
            in
            if model.check then
                if ok.data == [] then
                ({model | data = ok.data, sumCount = result, loading = False}, Cmd.none)
                else
                ({model | data = ok.data, sumCount = result, loading = False}, Cmd.none)
            else 
                if ok.data == [] then
                    ({model | data = ok.data, sumCount = result, loading = False}, Cmd.none)
                else
                    ({model | data = ok.data, sumCount = result, loading = True}, Cmd.none)
        GetList (Err err) ->
            let
                serverErrors =
                    Api.decodeErrors err
            in  
            (model, (Session.changeInterCeptor (Just serverErrors) model.session))

        CheckDevice str ->
           let 
                result =
                    Decode.decodeValue Decode.string str
            in
                case result of
                    Ok string ->
                        ({model| checkDevice = string}, Cmd.none)
                    Err _ -> 
                        ({model | checkDevice = ""}, Cmd.none)







    
view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
            { title = "유어핏 운동"
            , content = 
            div [][
                div [class (if model.detailShow then "eventDefault" else "")] []
                , div [class ("container topSearch_container " ++ if model.detailShow then "fadeContainer" else "")] [
                    
                     justappHeader "유어핏운동" "yourfitHeader",
                    div [][
                        div [class "spinnerBack", style "display" (if model.loading then "flex" else "none")] [
                            spinner
                            ]
                        , div [] [app model]
                    ]
                    
                    ], 
                   div [class ("container myaccountStyle dispalyNO " ++ if model.need2login then "account yfdetailShow displayYes" else ""), id (if model.need2login then "noScrInput" else "")] [
                        appHeaderRDetailClick "로그인" "yourfitHeader" BackPage "fas fa-times"
                        , need2loginAppDetail BackPage
                    ]
                    , YfD.app model BackPage Scrap GoVideo
                ]
            }
    else
        { title = "유어핏 운동"
        , content = 
            div [][
                div [class "spinnerBackWeb", style "display" (if model.loading then "block" else "none")] [
                    spinner
                ]
                , div [] [ web model ]
            ]
            
        }

web : Model -> Html Msg            
web model =
    div [ class "yourfitExercise_yf_workoutcontainerwrap" ]
            [ div [ class "container" ]
                [ div [ class "notification yf_workout" ]
                    [
                        commonHeader "/image/icon_workout.png" "유어핏운동",
                        div [] (List.indexedMap (\idx x -> 
                            bodyContents idx x model
                            ) model.data)
                    ]
                ]
            ]

app : Model -> Html Msg
app model =
        div [ class "container yourfitExerContainer" ]
            [ 
                    div [] (List.map (\x -> 
                            lazy2 bodyContentsApp x model
                            ) model.data)
            ]
            

bodyContents : Int -> ListData -> Model -> Html Msg
bodyContents idx item model = 
    div [class "webFxWrap"]
    [  
        div [class "webMoveKeyR", onClick (MoveLeft idx)] [
            i[class "fas fa-caret-left "] []
        ]
       ,
       div [ class "menubox_wrap", id ("scrollCtr" ++ (String.fromInt idx))] [
            div [ class "yf_workoutmenubox1", style "width" (String.fromInt(200 * 6 + 120) ++ "px") ]
        [  div [ class "yf_workoutvideopic" ]
            [    if item.code == "10" then
                img [src "/image/workout_menu1.png", alt item.name ]
                []
                else if item.code == "20" then
                img [src "/image/workout_menu2.png", alt item.name ]
                []
                else
                img [src "/image/workout_menu3.png", alt item.name ]
                []
            ,
             div [ class "yf_workouttext1" ]
                [ text item.name ]
            ]
        , div [] (List.indexedMap (\i x-> videoItem i x item.code model.loading) item.exercises )
        , div [ class "yf_workoutaddwarp" ]
                [ div [ class "yf_workoutadd" , onClick (GoDetail item.code)]
                    [ div [ class "yf_workouttext3" ]
                        [ text "더보기" ]
                    ]
                ]
         
        ]
       ]
       ,div [class "webMoveKey", onClick (MoveMore idx)] [
           i[class "fas fa-caret-right "] []
       ]
    ]

bodyContentsApp : ListData -> Model -> Html Msg
bodyContentsApp item model= 
    div [class "notification m_yfwo_menubox1"][
    div [ class "m_menubox_wrap" ]
    [
         div ([class "originSwipeStyle"]
         ++ [style "width" ( String.fromInt ((15 * (List.length(item.exercises)))+ 7 ) ++ "rem")]
                        ++ Swiper.onSwipeEvents (Swiped item.code )++ [onClick (GetIndex item.code)]) 
                    [    
         div [ class "m_yf_workoutmenubox" ]
        [ div [ class "yf_workoutvideopic" ]
            [ if item.code == "10" then
                img [ class "bigpic1", src "/image/workout_menu1.png", alt item.name ]
                []
                else if item.code == "20" then
                img [ class "bigpic1", src "/image/workout_menu2.png", alt item.name ]
                []
                else
                img [ class "bigpic1", src "/image/workout_menu3.png", alt item.name ]
                []
            , div [ class "m_yf_stretchingtext" ]
                [ text item.name ]
            ]
        ,
        div [] (List.indexedMap (\idx x -> videoItemApp idx x model item.code) item.exercises)
        , div [ class "yf_workoutaddwarp" ]
                [ div [ class "m_yf_workoutadd", onClick (GoDetail item.code) ]
                    [ div [ class "m_addtext" ]
                        [ text "더보기" ]
                    ]
                ]
                ]
        
                    ]
    ]]


videoItem : Int -> ExerciseList -> String -> Bool -> Html Msg
videoItem idx item code loading = 
    div [ class "yf_workoutvideoboxwrap" , onClick (GoContentsDetail item.id)]
        [ div [class"list_overlay"]
        [i [ class "fas fa-play overlayplay_list" ][]],

             div [ class "yf_workoutvideo_image" ]
                [ 
                    img [ class "yf_workoutvpic1", src item.thembnail, onLoad (OnLoad (code ++ String.fromInt idx)) ]
                    []
                ]
            , div [ class "yf_workoutvideo_lavel_bg" ]
                [ div [ class "level" ]
                    [ text item.difficulty_name ]
                ]
            , div [ class "yf_workoutworkout_title" ]
                [ text item.title ]
            , div [ class "m_timebox" ]
                [
                    i [ class "fas fa-stopwatch" ]
                    []
                    , text " "
                    , text item.duration ]
            ]
lazyImageview : String -> Html Msg
lazyImageview item = 
    img [class "m_workoutvpic",  src item ] [
       
    ]

videoItemApp : Int -> ExerciseList -> Model -> String -> Html Msg
videoItemApp idx item model code = 
    div [ class "m_workoutvideoboxwrap" , onClick (GoContentsDetail item.id)]
            [   
                div [ class "m_yf_workoutvideo_image" ]
                [ img [ class "m_workoutvpic"
                , src item.thembnail, onLoad (OnLoad (code ++ String.fromInt idx))  ]
                    []
                ]
            , div [ class "m_yf_workoutvideo_lavel_bg" ]
                [ div [ class "m_level" ]
                    [ text item.difficulty_name ]
                ]
            , div [ class "m_yf_workoutworkout_title" ]
                [ text item.title ]
            , div [ class "m_timebox" ]
                [ 
                    i [ class "fas fa-stopwatch" ]
                    []
                    , text " "
                    , text item.duration ]
            
            ]


