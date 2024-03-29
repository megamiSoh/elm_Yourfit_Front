module Page.Filter.Filter exposing (..)
import Browser exposing (..)
import Html.Events exposing(..)
import Html.Attributes exposing(..)
import Session exposing(..)
import Html exposing (..)
import Route exposing(..)
import Port as P
import Json.Encode as Encode
import Json.Decode as Decode
import Page.Common exposing(..)
import Http
import Api.Endpoint as Endpoint
import Api.Decoder as Decoder
import Api as Api
import Html.Lazy exposing (lazy, lazy5)
type alias Model = 
    { session : Session
    , isActivePart :  List String
    , isActiveLevel : List String
    , isActiveExer : List String
    , isActiveTool : List String
    -- , checkDevice : String
    , part : List CodeData
    , level : List CodeData
    , exer : List CodeData
    , tool : List CodeData
    , check : Bool
    , loading : Bool
    , title : String
    , page : Int
    , per_page : Int
    , errType : String
    }

type alias FilterCode =
    { data : List CodeData }

type alias CodeData =
    { code : String
    , name : String
    }

filterEncoder : Model -> Encode.Value
filterEncoder model = 
    Encode.object
        [ ("difficulty_code", (Encode.list Encode.string) model.isActiveLevel)
        , ("exercise_code", (Encode.list Encode.string) model.isActiveExer)
        , ("instrument_code", (Encode.list Encode.string) model.isActiveTool)
        , ("part_detail_code", (Encode.list Encode.string) model.isActivePart)
        , ("title", Encode.string model.title)
        , ("per_page", Encode.int model.per_page)
        , ("page", Encode.int model.page)
        ]


init : Session -> Bool ->(Model, Cmd Msg)
init session mobile
    = (
        { session = session
        , isActivePart = []
        , isActiveLevel = []
        , isActiveExer = []
        , isActiveTool = []
        , title = ""
        , part = []
        , level = []
        , exer = []
        , page = 1
        , per_page = 20
        , tool = []
        , loading = True
        , check= mobile
        , errType = ""}
        , Cmd.batch
        [ 
         Decoder.levelDecoder FilterCode CodeData
         |> Api.get GetPart Endpoint.partFilter (Session.cred session) 
        ]
        
       
    )

type Msg 
    = IsActivePart String
    | IsActiveLevel String
    | IsActiveExer String
    | IsActiveTool String
    | BackBtn
    | NextBtn
    | GetPart (Result Http.Error FilterCode)
    | GetLevel (Result Http.Error FilterCode)
    | GetTool (Result Http.Error FilterCode)
    | GetExer (Result Http.Error FilterCode)
    | GoNextPage
    | FilterSaveSuccess Encode.Value
    | GotSession Session
    | SessionCheck Encode.Value

toSession : Model -> Session
toSession model =
    model.session

toCheck : Model -> Bool
toCheck model =
    model.check


subscriptions :Model -> Sub Msg
subscriptions model=
    Sub.batch [ Api.saveFilter FilterSaveSuccess
    , Session.changes GotSession (Session.navKey model.session)
    , Api.onSucceesSession SessionCheck
    ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SessionCheck check ->
            let
                decodeCheck = Decode.decodeValue Decode.string check
            in
                case decodeCheck of
                    Ok continue ->
                        (model,
                        Cmd.batch [
                            (Decoder.levelDecoder FilterCode CodeData)
                            |> Api.get GetPart Endpoint.partFilter (Session.cred model.session) ,
                            (Decoder.levelDecoder FilterCode CodeData)
                            |> Api.get GetLevel Endpoint.levelFilter (Session.cred model.session) ,
                            (Decoder.levelDecoder FilterCode CodeData)
                            |> Api.get GetTool Endpoint.toolFilter (Session.cred model.session) ,
                            (Decoder.levelDecoder FilterCode CodeData)
                            |> Api.get GetExer Endpoint.exerFilter (Session.cred model.session) 
                        ])
                    Err _ ->
                        (model, Cmd.none)
        GotSession session ->
            ({model | session = session}
            , case model.errType of
                "part" ->
                    (Decoder.levelDecoder FilterCode CodeData)
                        |> Api.get GetPart Endpoint.partFilter (Session.cred session)
                "level" ->
                    (Decoder.levelDecoder FilterCode CodeData)
                        |> Api.get GetLevel Endpoint.levelFilter (Session.cred session)
                "tool" ->
                    (Decoder.levelDecoder FilterCode CodeData)
                        |> Api.get GetTool Endpoint.toolFilter (Session.cred session)
                "exer" ->
                    (Decoder.levelDecoder FilterCode CodeData)
                        |> Api.get GetExer Endpoint.exerFilter (Session.cred session) 
                _ ->
                    (Decoder.levelDecoder FilterCode CodeData)
                        |> Api.get GetExer Endpoint.exerFilter (Session.cred session) 
            )
        FilterSaveSuccess str ->
            (model,
             Route.pushUrl (Session.navKey model.session) Route.FilterS1
             )
        GoNextPage ->
            (model, Api.filter (filterEncoder model))
        GetPart(Ok ok) ->
            ({model | part = ok.data } ,
            (Decoder.levelDecoder FilterCode CodeData)
            |> Api.get GetExer Endpoint.exerFilter (Session.cred model.session) )
        GetPart(Err err) ->
            let
                serverErrors = Api.decodeErrors err
            in
            
            ({model | errType = "part"},(Session.changeInterCeptor (Just serverErrors) model.session))
        GetLevel(Ok ok) ->
            ({model | level = ok.data, loading = False }, Cmd.none)
        GetLevel(Err err) ->
            ({model | errType = "level"},Cmd.none)
        GetTool(Ok ok) ->
            ({model | tool = ok.data } , 
            (Decoder.levelDecoder FilterCode CodeData)
            |> Api.get GetLevel Endpoint.levelFilter (Session.cred model.session) )
        GetTool(Err err) ->
            ({model | errType = "tool"},Cmd.none)
        GetExer(Ok ok) ->
            ({model | exer = ok.data }, 
            (Decoder.levelDecoder FilterCode CodeData)
            |> Api.get GetTool Endpoint.toolFilter (Session.cred model.session) )
        GetExer(Err err) ->
            ({model | errType = "exer"},Cmd.none)
        IsActivePart part ->
            if filterItem part model.isActivePart > 0 then
                ({model | isActivePart = leastItem part model.isActivePart} , Cmd.none)
            else 
                ( {model | isActivePart = [part] ++ model.isActivePart }, Cmd.none )
                
        
        IsActiveLevel level ->
            if filterItem level model.isActiveLevel > 0 then
                ({model | isActiveLevel = leastItem level model.isActiveLevel} , Cmd.none)
            else
                ({model | isActiveLevel = [level] ++ model.isActiveLevel}, Cmd.none)

        IsActiveExer exer ->
            if filterItem exer model.isActiveExer > 0 then
                ({model | isActiveExer = leastItem exer model.isActiveExer} , Cmd.none)
            else
                ({model | isActiveExer = [exer] ++ model.isActiveExer}, Cmd.none)

        IsActiveTool tool ->
            if filterItem tool model.isActiveTool > 0 then
                ({model | isActiveTool = leastItem tool model.isActiveTool} , Cmd.none)
            else
                ({model | isActiveTool = [tool] ++ model.isActiveTool}, Cmd.none)
        BackBtn ->
            (model, 
            Route.pushUrl (Session.navKey model.session) Route.MakeExer 
            )
        NextBtn ->
            (model , Cmd.none)

view : Model -> {title : String , content : Html Msg}
view model =
    if model.check then
        { title = "맞춤운동 필터"
        , content = 
            div [] [
                appHeaderConfirmDetailR "맞춤운동" "makeExerHeader" BackBtn GoNextPage "확인"
                , div [] 
                    [ div [class "spinnerBack", style "display" (if model.loading then "flex" else "none")] [spinner]
                    , lazy5 filterbox2 model.part model.level model.exer model.tool model
                    ]
            ]
        }
    else
        { title = "맞춤운동 필터"
        , content = 
            div [] [
                web model
            ]
        }

web : Model -> Html Msg
web model = 
     div [ class "container" ]
            [
                lazy5 filterbox model.part model.level model.exer model.tool model,
                btnBox
            ]
        
leastItem : String -> List String -> List String
leastItem item list=
    List.filter (\x -> x /= item) list

filterItem : String -> List String -> Int
filterItem item list=
    List.length (List.filter (\x -> x == item) list)

filterbox : List CodeData -> List CodeData -> List CodeData -> List CodeData -> Model -> Html Msg
filterbox part level exer tool model=
    div [ class "filter_yf_box" ]
    
        [ul []
          [ li [ class "filter_yf_title" ]            
         [ img [ src "image/checkimage.png", alt "checkimage" ]
                []
                ],
                   h1 [ class "make_yf_h1" ]
                   [ text "원하는 운동 필터에 체크하세요" ]

          ],
          ul []
            [ li [ class "filter_yf_li" ]
                [ text "운동부위" ]
            , li [class "filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("yf_on",(filterItem x.code model.isActivePart) > 0 )
                    ], onClick (IsActivePart x.code) ]
                        [ text x.name ]
            ) part
            )
        ],
        ul []
            [ li [ class "filter_yf_li" ]
                [ text "난이도" ]
            , li [class "filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("yf_on",(filterItem x.code model.isActiveLevel) > 0 )
                    ], onClick (IsActiveLevel x.code) ]
                        [ text x.name ]
            )level
            )
        ],
        ul []
            [ li [ class "filter_yf_li" ]
                [ text "운동종류" ]
            , li [class "filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("yf_on",(filterItem x.code model.isActiveExer) > 0 )
                    ], onClick (IsActiveExer x.code) ]
                        [ text x.name ]
            ) exer
            )
        ],
        ul []
            [ li [ class "filter_yf_li" ]
                [ text "기구" ]
            , li [class "filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("yf_on",(filterItem x.code model.isActiveTool) > 0 )
                    ], onClick (IsActiveTool x.code) ]
                        [ text x.name ]
            ) tool
            )
            ]
            
        ]

btnBox : Html Msg
btnBox =
    div [ class "filter_yf_butbox" ]
        [ div [ class "filter_yf_nextbtm" ]
            [ div [ class "button is-dark", onClick GoNextPage ]
                [ text "다음" ]
            ]
        ]

filterbox2 : List CodeData -> List CodeData -> List CodeData -> List CodeData -> Model -> Html Msg
filterbox2  part level exer tool model=
    div [ class "m_filter_yf_box" ]
        [ ul []
            [ li [ class "m_filter_yf_li" ]
                [ text "운동부위" ]
            , li [class "m_filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("m_yf_on",(filterItem x.code model.isActivePart) > 0 )
                    ], onClick (IsActivePart x.code) ]
                        [ text x.name ]
            ) part
            )
        ],
        ul []
            [ li [ class "m_filter_yf_li" ]
                [ text "난이도" ]
            , li [class "m_filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("m_yf_on",(filterItem x.code model.isActiveLevel) > 0 )
                    ], onClick (IsActiveLevel x.code) ]
                        [ text x.name ]
            ) level
            )
        ],
        ul []
            [ li [ class "m_filter_yf_li" ]
                [ text "운동종류" ]
            , li [class "m_filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("m_yf_on",(filterItem x.code model.isActiveExer) > 0 )
                    ], onClick (IsActiveExer x.code) ]
                        [ text x.name ]
            ) exer
            )
        ],
        ul []
            [ li [ class "m_filter_yf_li" ]
                [ text "기구" ]
            , li [class "m_filter_btn"]
            (
            List.map(\x ->
                div [ classList [
                    ("button", True),
                    ("m_yf_on",(filterItem x.code model.isActiveTool) > 0 )
                    ], onClick (IsActiveTool x.code) ]
                        [ text x.name ]
            )tool
            )
            ]
            
        ]
