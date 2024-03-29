module Page.Edit.MakeExerEditStepLast exposing(..)

import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Page.Common exposing (..)
import Json.Decode as Decode exposing (Decoder, int, string, float)
import Json.Decode.Pipeline exposing (required, optional, hardcoded)
import Json.Encode as E
import Json.Decode as Decode
import Route exposing (..)
import Port as P
import Api as Api
import Api.Decoder as Decoder
import Http as Http
import Api.Endpoint as Endpoint
import Page.Edit.MakeExerEdit as Me

type alias Model = 
    { session : Session
    , addData : List FilterData
    , what: String
    , style: String
    , setData : Int
    , checkDevice : String
    , check : Bool
    , title : String
    , validation : String
    , errTitle : String
    , loading : Bool
    , cannotSave : String
    , saveItem : List Item
    , videoId : String
    , description : String
    , errType : String
    }

type alias FilterData =
    { difficulty_name: Maybe String
    , exercise_name: Maybe String
    , id: Int
    , instrument_name: Maybe String
    , part_detail_name: List String
    , title: Maybe String
    , value : Maybe Int
    , duration: Maybe String
    , thembnail : Maybe String
    }

type alias Item = 
    { action_id: String
    , is_rest: String
    , value : String}

type alias Items = 
    { action_id: Maybe Int
    , is_rest: Bool
    , value : Int}

type alias ResultData = 
    { result : String }

editItenEncoder item = 
    urlencoded 
        [ ("action_id", 
            if item.action_id == "0"then
                "null"
            else
                item.action_id
            )
        , ("is_rest", item.is_rest)
        , ("value", item.value)]

formUrlencoded object =
    object
        |> List.map
            (\( name, value ) ->
                name
                    ++ "="
                    ++ value
            )
        |> String.join "&"

urlencoded object =
    object
        |> List.map
            (\( name, value ) ->
                "\"" ++ name ++ "\""
                    ++ ":"
                    ++ value
            )
        |> String.join ","

listformUrlencoded object =
    object
        |> List.map
            (\x ->
                "{"
                ++ editItenEncoder x
                ++ "}"
            )
        |> String.join ","


registVideo model edit session=
    let
        newDescriptions = 
            model.description
                |> String.replace "&" "%26"
                |> String.replace "%" "%25"
        newtitle = 
            model.title
                |> String.replace "&" "%26"
                |> String.replace "%" "%25"
        body =
            formUrlencoded 
            [ ("title", newtitle)
            , ("description",newDescriptions)
            , ("items", "[" ++ listformUrlencoded edit ++ "]"
            )
            ]

            |> Http.stringBody "application/x-www-form-urlencoded"
    in
    Decoder.resultDecoder ResultData
    |>Api.post (Endpoint.editComplete model.videoId)(Session.cred session) GoRegistResult body

init session mobile
    = 
    (
        {session = session
        , addData = []
        , what = ""
        , style = ""
        , check= mobile
        , saveItem = []
        , videoId = ""
        , setData = 3
        , checkDevice = ""
        , title = ""
        , validation = ""
        , cannotSave = ""
        , errTitle = ""
        , loading = True
        , description = ""
        , errType = ""
        } 
        ,Cmd.batch[Api.sendData ()
        , Api.getId ()]
    )
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch[
    Api.receiveData ReceiveDataFromStorage
    , Api.getsaveFilter FilterSaveSuccess
    , Session.changes GotSession (Session.navKey model.session)
    , Api.onSucceesSession SessionCheck
    , Api.receiveId GetId]
   
type Msg 
    = ReceiveDataFromStorage E.Value
    | Test String
    | Expand (Int, Int)
    | Plus Int
    | Minus Int
    | Save Int
    | UpdateSet String
    | BackBtn
    | UpdateTitle String
    | GoRegist
    | SwitchItem Int
    | GoRegistResult (Result Http.Error ResultData)
    | NextPage
    | FilterSaveSuccess E.Value
    | SessionCheck E.Value
    | GotSession Session
    | GetId E.Value
    | GetList (Result Http.Error Me.DetailData)
    | Description String

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check

    

takeLists idx model = 
    List.take idx model

dropLists idx model = 
    List.drop idx model

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of 
        Description descriptions ->
            ({model | description = descriptions}, Cmd.none)
        GetList(Ok ok) ->
            let
                newTitle = 
                    ok.data.title 
                        |> String.replace "%26" "&" 
                        |> String.replace "%25" "%"    
            in
            
            ({model | title = newTitle, description = (justokData ok.data.description)}, Cmd.none)
            -- update GoVideo {model | getData = ok.data}
        GetList(Err err) ->
            let 
                serverErrors = 
                    Api.decodeErrors err  
            in
             ({model | errType = "getlist"},(Session.changeInterCeptor (Just serverErrors) model.session))
        GetId id ->
            let
                result = Decode.decodeValue Decode.string id
            in
            case result of
                Ok string ->
                    ({model | videoId = string}, 
                    (Decoder.makeEdit Me.DetailData Me.DetailItem Me.ExItem Me.Pair)
                    |> Api.get GetList (Endpoint.makeDetail string) (Session.cred model.session) )
            
                Err _ ->
                    (model,Cmd.none)
        GotSession session ->
            ({model | session = session}
            , case model.errType of
                "getlist" ->
                    Decoder.makeEdit Me.DetailData Me.DetailItem Me.ExItem Me.Pair
                    |> Api.get GetList (Endpoint.makeDetail model.videoId) (Session.cred session)
                "regist" ->
                    registVideo model model.saveItem session
                _ ->
                    registVideo model model.saveItem session
            )
        SessionCheck check ->
            let
                decodeCheck = Decode.decodeValue Decode.string check
            in
                case decodeCheck of
                    Ok continue ->
                        update GoRegist model
                    Err _ ->
                        (model, Cmd.none)
        FilterSaveSuccess str ->
            (model, 
            -- -- Api.historyUpdate (E.string "filterStep1")
            Route.pushUrl (Session.navKey model.session) Route.FilterS1
            )
        NextPage ->
            (model, Cmd.batch [
                 Api.getSomeFilter ()
            ] )
        GoRegistResult (Ok ok) ->
            let
                text = E.string "수정되었습니다."
            in
            
            (model, Cmd.batch [
                Api.deleteData ()
                , Route.pushUrl (Session.navKey model.session) Route.MakeExer
                , Api.showToast text
                -- , -- Api.historyUpdate (E.string "makeExercise")
                ]
                )
        GoRegistResult (Err err) ->
            let 
                serverErrors = Api.decodeErrors err
            in
            
            ({model | errType = "regist"}, (Session.changeInterCeptor (Just serverErrors) model.session)) 
        SwitchItem idx ->
            let 
                before = 
                    takeLists (len - 2) model.addData
                after =
                    dropLists (idx + 1) model.addData
                len = 
                    List.length (takeLists ( idx  + 1 ) model.addData)
                getVal = 
                    dropLists ( len - 2 ) (takeLists ( idx  + 1 ) model.addData)
                result item = 
                    List.reverse item
            in
            ({model | addData = before ++ List.reverse getVal ++ after} , Cmd.none)
        GoRegist ->
            let
                item = 
                    List.map(\x ->
                        {action_id = String.fromInt(x.id),
                        is_rest =
                            (if x.id == 0 then
                                "true"
                            else
                                "false"),
                        value = 
                        case x.value of
                            Just ok ->
                                String.fromInt(ok)
                            Nothing ->
                                String.fromInt(3)
                        }
                    ) model.addData

            in
            if model.title == "" then
            ({model|validation = "vaidColor", errTitle = "제목을 입력 해 주세요."}, Cmd.none)
            else
            ({model | loading = True, saveItem = item}, registVideo model item model.session)
        UpdateTitle title ->
            ({model | title = title}, Cmd.none)
        ReceiveDataFromStorage data ->
            let 
                last = Decode.decodeValue (Decode.list(Decoder.filterStep2 FilterData)) data
            in
            case last of
                Ok val ->
                    ( {model | addData = val, loading = False}, Cmd.none )
                Err _ -> 
                    (model, Cmd.none)
                
               
        Test data -> 
            ({model | what = data}, Cmd.none)
        
        Expand (idx, set)-> 
            let 
                f = 
                    List.filter(\x ->
                        x.value == Just 0
                    ) model.addData
            in
            if List.length f /= 0 then
            (model, Cmd.none)
            else
                if model.style == String.fromInt(idx) then
                    ({model | style = "", setData = set, cannotSave = ""}, Cmd.none)
                else
                    ({model | style = String.fromInt(idx), setData = set, cannotSave = ""}, Cmd.none)

        Plus idx ->
            if model.setData < 5 then
            ( {model | setData = model.setData + 1 },  Cmd.none)
            else
            (model, Cmd.none)
        Minus idx ->
            if (model.setData - 1) <= 0 then
                ( {model | setData = 0 },  Cmd.none)
            else
                ( {model | setData = model.setData - 1 },  Cmd.none)
        Save idx->
            let 
                result = 
                        List.indexedMap (\i x ->
                            if i == idx then
                                { difficulty_name=  x.difficulty_name
                                , exercise_name= x.exercise_name
                                , id= x.id
                                , instrument_name= x.instrument_name
                                , part_detail_name= x.part_detail_name
                                , title= x.title
                                , value = Just model.setData
                                , duration = x.duration
                                , thembnail = x.thembnail}
                            else
                                x
                        ) model.addData
            in
                if model.setData == 0 then
                ({model | cannotSave = "0 이하의 값은 저장할 수 없습니다."}, Cmd.none)
                else if model.setData > 5 then
                ({model | cannotSave = "6 이상의 값은 저장 할 수 없습니다."}, Cmd.none)
                else
                ( {model | addData = result, cannotSave  ="", style = "" },  Cmd.none)
        UpdateSet str->
            let 
                data = String.toInt str
            in
            case data of
                Just ok ->
                    if ok == 0 then
                    ({model | cannotSave = "0 이하의 값은 저장할 수 없습니다."}, Cmd.none)
                    else if ok > 5 then
                    ({model | cannotSave = "6 이상의 값은 저장 할 수 없습니다."}, Cmd.none)
                    else
                    ({model | setData = ok}, Cmd.none)
            
                Nothing ->
                    ({model | setData = -1 }, Cmd.none)
        BackBtn ->
            (model, 
            -- -- Api.historyUpdate (E.string "filterStep1")
            Route.pushUrl (Session.navKey model.session) Route.FilterS1
            )

view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
            { title = "맞춤운동 필터"
            , content = div [] 
            [ div [class "spinnerBack", style "display" (if model.loading then "flex" else "none")] [spinner]
            , app model ]
            }
    else
            { title = "맞춤운동 필터"
            , content = 
                div [] 
                [ div [class "spinnerBackWeb", style "display" (if model.loading then "flex" else "none")] [spinner]
                , web model ]
            }
justokData result = 
    case result of
        Just ok ->
            let
                replace = 
                    ok
                        |> String.replace "%26" "&"
                        |> String.replace "%25" "%"  
            in
                replace
        Nothing ->
            ""

justokIntData data =
    case data of
        Just ok ->
            ok
        Nothing ->
            3
app model =
    div [] [
        appHeaderConfirmDetailleft "운동추가" "makeExerHeader" NextPage GoRegist "저장"
        , appcontentsItem model
    ]

web model =
     div [ class "container" ]
            [   
                commonJustHeader "/image/icon_customworkout.png" "맞춤운동"
                , contentsItem model
                , goBtn
            ]

contentsItem model = 
    div [ class "filterstep2_yf_box" ]
            [
                thumbSetting model,
                itemCount model,
                div [ class "filterstep2_yf_listselect" ]
                ( List.indexedMap (\idx x ->
                selectedItem idx x model
                ) model.addData)
            ]

appcontentsItem model = 
    div [ class "m_filterstep2_yf_box" ]
            [
                appthumbSetting model,
                appitemCount model,
                div [ class "m_filterstep2_yf_listselect" ]
                ( List.indexedMap (\idx x ->
                appselectedItem idx x model
                ) model.addData)
            ]                    

thumbSetting model= 
    div [ class "yf_box_top" ]
        [ div [ class "yf_thumbnail" ]
            [ img [ src "/image/thumbnail.png" ]
                [], text "대표썸네일지정" 
            ]
        , div [ class "yf_titleinput" ]
            [ 
            div [class model.validation] [
                input [ class ( "input " ++ model.validation ), type_ "text", placeholder "운동제목을 수정해 주세요.", onInput UpdateTitle, value model.title , maxlength 50]
                []
                , textarea [placeholder "운동 설명을 수정해 주세요.", value model.description, onInput Description, maxlength 200] []
            ]
            , div [] [text model.errTitle]
            ]
        ]

appthumbSetting model = 
    div [ class "m_yf_box_top" ]
        [ div [ class "m_yf_thumbnail" ]
            [ img [ src "/image/thumbnail.png" ]
                []
            ]
        , div [ class "m_yf_titleinputbox" ]
            [ input [ class ( "input m_yf_titleinput " ++ model.validation ), type_ "text", placeholder "운동제목을 수정해 주세요.",  onInput UpdateTitle, value model.title, maxlength 50 ]
                []
            , textarea [placeholder "운동 설명을 수정해 주세요.", value model.description, onInput Description, maxlength 200] []
            ]
        , div [class "thubmTitle"] [text "썸네일지정" ]
        ]

itemCount model= 
    div [ class "filterstep2_yf_select" ]
        [ text ("총 "++ String.fromInt(List.length (model.addData)) ++" 건선택") ]
appitemCount model= 
    div [ class "m_filterstep2_yf_select" ]
        [ text ("총 "++ String.fromInt(List.length (model.addData)) ++" 건선택") ]
        
justData item = 
    case item of
        Just a ->
            a
    
        Nothing ->
            ""
selectedItem idx item model=
    div [ class "filterstep2_videolistbox" ]
        [ div [ class "yf_switch" ]
            [ 
                img [ src "/image/switch_up.png", class "upIcon", onClick (SwitchItem idx)]
                []
                , img [ src "/image/switch_down.png", class "downIcon" , onClick (SwitchItem idx)]
                []
            
            ]
        , div [ class "filterstep2_worklistbox" ]
            [ div [ class "filterstep2_iconbox" ]
                [ 
                    if justokData item.title == "" then
                    img [ src "/image/m_timeicon.png" ]
                    []
                    else
                    img [ src (justData item.thembnail) ]
                    []
                ]
            , 
            div [class"filterstep2_textbox"]
                [ 
            if justokData item.title == "" then
            ul [class "filterstep2_text"]
                [ li [ class "filterstep2_work1" ]
                    [ text ("휴식 - "++ String.fromInt(justokIntData item.value ) ++ "Min") ] 
                ]
            else
                ul [class "filterstep2_text"]
                    [ li [ class "filterstep2_work1" ]
                        [ text (justokData item.title ++ " - "++ String.fromInt(justokIntData item.value ) ++ "Set") ]
                    , li [ class "filterstep2_work2" ]
                        [ text (justokData item.difficulty_name ++ "-" ++ justokData item.instrument_name ++"-" ++justokData item.exercise_name)  ]
                    , li [ class "filterstep2_work3" ]
                        [ 
                            i [ class "fas fa-stopwatch" ]
                            []
                            , text " "
                            , text (justData item.duration) ]
                    ]
                ]
            , 
             div [ class "filterstep2_addbox", onClick (Expand (idx, justokIntData item.value)) ]
                [
                    if String.fromInt(idx) == model.style then
                     img [ src "/image/editicon2.png" ]
                        []
                    else 
                     img [ src "/image/editicon.png " ]
                        []
                    ]
                ], 
            expandPanel idx model item.title
        ]


appselectedItem idx item model=
    div [ class "m_filterstep2_videolistbox" ]
        [ div [ class "m_yf_switch" ]
            [ 
                img [ src "/image/m_down.png", class "m_downIcon",  onClick (SwitchItem idx) ]
                []
            , img [ src "/image/m_up.png", class "m_upIcon" , onClick (SwitchItem idx)]
                []
            ]
        , div [ class "m_filterstep2_worklistbox" ]
            [ div [ class "m_filterstep2_iconbox" ]
                [ 
                    if justokData item.title == "" then
                    img [ src "/image/m_timeicon.png" ]
                    []
                    else
                    img [ src  (justData item.thembnail) ]
                    []
                ]
            , div [class"m_filterstep2_textbox"]
                [
                    if justokData item.title =="" then
                    ul [class "filterstep2_text"]
                    [ li [ class "m_filterstep2_work1" ]
                        [ text ("휴식 - "++ String.fromInt(justokIntData item.value ) ++ "Min") ]
                    ]
                    else
                    ul [class "filterstep2_text"]
                    [ li [ class "m_filterstep2_work1" ]
                        [ text (justokData item.title ++ " - "++ String.fromInt(justokIntData item.value ) ++ "Set") ]
                    , li [ class "m_filterstep2_work2" ]
                        [ text (justokData item.difficulty_name ++ "-" ++ justokData item.instrument_name ++"-" ++justokData item.exercise_name) ]
                    , li [ class "m_filterstep2_work3" ]
                        [  i [ class "fas fa-stopwatch" ]
                            []
                            , text " "
                            , text (justData item.duration) ] 
                    ]
                ]
            , 
            div [ class "m_filterstep2_addbox", onClick (Expand (idx, justokIntData item.value )) ][
                if String.fromInt(idx) == model.style then
                    img [ src "/image/editicon2.png" ]
                        []
                else 
                    img [ src "/image/editicon.png " ]
                        []
                    ]
                ], 
            appexpandPanel idx model item.title
        ]
-- class ("settingbox expandStyle target " 
expandPanel idx model rest=
    div [ classList [
        (("filterstep2_settingbox" ++ String.fromInt(idx)), True),
        ("expandStyle", True),
        ("expandOn", (String.fromInt(idx) == model.style))
    ] ]
        [ div [ class "filterstep2_yf_setting" ]
            [ if justokData rest == "" then text "휴식 설정"  else text "세트 설정" ]
        , div [ class "filterstep2_yf_setting2" ]
            [ div [ class "button filterstep2_mbtn", onClick (Minus idx) ]
                [ text "-" ]
            , input [ class "input filterstep2_yf_num", type_ "text", value 
            (if model.setData == -1 then
            ""
            else 
            (String.fromInt(model.setData)))
            , onInput UpdateSet]
                [text (String.fromInt(model.setData))],
                if justokData rest == "" then text "분"  else text "회"
            , button [ class "button filterstep2_fbtn", onClick (Plus idx) ]
                [ text "+" ]
            , div [] [text model.cannotSave]
            , button [ class "button is-dark filterstep2_save_btn", onClick (Save idx) ]
                [ text "저장" ]
            ,button [ class "button is-danger filterstep2_del_btn", onClick (Save idx) ]
                [ text "삭제" ]    
            ]
        ]

-- class ("settingbox expandStyle target " 
appexpandPanel idx model rest=
    div [ classList [
        (("filterstep2_settingbox" ++ String.fromInt(idx)), True),
        ("expandStyle", True),
        ("m_expandOn", (String.fromInt(idx) == model.style))
    ] ]
        [ div [ class "m_filterstep2_yf_setting" ]
            [ if justokData rest == "" then text "휴식 설정"  else text "세트 설정"  ]
        , div [ class "m_filterstep2_yf_setting2" ]
            [ div [ class "button m_filterstep2_mbtn", onClick (Minus idx) ]
                [ text "-" ]
            , input [ class "input m_filterstep2_yf_num", type_ "text"
            , value (
                if model.setData == -1 then
                ""
                else 
                (String.fromInt(model.setData))),
             onInput UpdateSet]
                [text (String.fromInt(model.setData))], 
                 if justokData rest == "" then text "분"  else text "회"
            , button [ class "button m_filterstep2_fbtn", onClick (Plus idx) ]
                [ text "+" ]
            , br []
                []
            , button [ class "button is-dark m_filterstep2_save_btn", onClick (Save idx) ]
                [ text "저장" ]
            ,button [ class "button is-danger m_filterstep2_del_btn", onClick (Save idx) ]
                [ text "삭제" ]    
            ]
        ]

goBtn = 
    div [ class "make_yf_butbox" ]
        [ div [ class "yf_backbtm" ]
            [ div [ class "button is-middle", onClick NextPage ]
                [ text "뒤로" ]
            ]
        , div [ class "yf_nextbtm" ]
            [ div [ class "button is-dark is-middle next_btn", onClick GoRegist ]
                [ text "저장" ]
            ]
        ]