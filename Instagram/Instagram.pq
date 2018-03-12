// This file contains your Data Connector logic
section Instagram;


client_id       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_id];
client_secret   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_secret];
token_uri       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][token_uri];
authorize_uri   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][authorize_uri];

redirectUrl = "https://preview.powerbi.com/views/oauthredirect.html";

windowWidth = 1080;
windowHeight = 1024;

baseUrl = "https://graph.facebook.com/v2.12/";
scope_prefix = "";
scopes = {
	"manage_pages", "instagram_basic", "instagram_manage_insights"
};

Instagram = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            Refresh = Refresh,
            FinishLogin = FinishLogin
        ]
    ],
    Label =  Extension.LoadString ("DataSourceLabel")
];

// Data Source Kind description
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
        client_id = client_id,
        redirect_uri = redirectUrl,
        state = state,
        scope = GetScopeString(scopes, scope_prefix),
        response_type = "code"
    ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirectUrl,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                   TokenMethod("authorization_code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token);

TokenMethod = (grantType, code) =>
    let
        query = [
            grant_type = grantType,
            client_id = client_id,
            client_secret = client_secret,
            redirect_uri = redirectUrl
        ],

        // {CODE From Matt} added for Google API - field is "code" on initial auth, and "refresh_token" for refresh
        queryWithCode = if (grantType = "refresh_token") then [ refresh_token = code ] else [code = code],

        response = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(query & queryWithCode)),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"], ManualStatusHandling = {400}]),
        body = Json.Document(response),
        result = if  (Record.HasFields(body, {"error", "error_description"})) then  
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;



// Data Source UI publishing description
Instagram.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/mbilling/pbiconnectors",
    SourceImage = Instagram.Icons,
    SourceTypeImage = Instagram.Icons
];

Instagram.Icons = [
    Icon16 = { Extension.Contents("Instagram16.png"), Extension.Contents("Instagram20.png"), Extension.Contents("Instagram24.png"), Extension.Contents("Instagram32.png") },
    Icon32 = { Extension.Contents("Instagram32.png"), Extension.Contents("Instagram40.png"), Extension.Contents("Instagram48.png"), Extension.Contents("Instagram64.png") }
];




// Navigation entry point
[DataSource.Kind="Instagram", Publish="Instagram.Publish"]
shared Instagram.Contents = (optional url as text, optional params as record) =>
    let
        key = Extension.CurrentCredential()[access_token],
        accountRequest = Web.Contents(baseUrl & "me/accounts?" & Uri.BuildQueryString([access_token=key, fields="name,access_token,connected_instagram_account"])),
        accounts = Json.Document(accountRequest)[data],
        table = PagesToNavTabler(accounts)
    in
        table;

PagesToNavTabler = (users as list) =>
    let
        navHeader = {"Name","Key","Data","ItemKind", "ItemName", "IsLeaf"}, 
        navUsers = List.Accumulate(users, {}, (state, current) => state & {{current[name], current[name], GetDatePresets(current), "Table", "Table", false}} ),
        objects = #table(navHeader, navUsers),
        table = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        table;

GetDatePresets = (page as record) =>
    let 
        navHeader = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, 
        navInsights = List.Accumulate({1,2,3,4,5,6,12,24}, {}, (state, current) => state & {{"Last " & Number.ToText(current * 30) & " days", current, GetInsights(page, current), "Table", "Table", false}} ),
        objects = #table(navHeader, navInsights),
        table = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        table;

GetInsights = (page as record, months as number) =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
            {"Instagram Page Insights", "Instagram Page Insights", GetPageInsights(page, months), "Table", "Table", true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetPageInsights = (page as record, months as number) =>
    let
        // Pull 30 days per query, just to be efficient.
        unixToday =   Number.ToText(Number.Round(86400*(Number.From(DateTime.LocalNow())-Number.From(#datetime(1970,1,1,0,0,0))),0)),
        unix30DaysAgo =  Number.ToText(Number.Round(86400*(Number.From(DateTime.LocalNow())-Number.From(#datetime(1970,1,31,0,0,0))),0)),
        query = baseUrl & page[connected_instagram_account][id] & "/insights?" & Uri.BuildQueryString([metric="impressions,reach,profile_views,website_clicks,get_directions_clicks,text_message_clicks,phone_call_clicks,email_contacts,follower_count",period="day",access_token=page[access_token], until=unixToday, since=unix30DaysAgo]),

        // Traverse "month" months of data. Facebook returns a rest url to previous 30 days for each request. Follow the these previous rest urls until we have the right amount of 30-day-months back.
        joined_response = List.Generate(
            ()=> [result = null, previous = query, month = months], 
            each [month] >= 0, 
            each [
                result = Json.Document(Web.Contents([previous])), 
                previous = try result[paging][previous] otherwise null, 
                month = [month] - 1 ], 
            each [result]
        ),

        response = Table.FromList(List.Skip(joined_response, 1), Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(response, "Column1", {"data"}, {"data"}),
        data = #"Expanded Column1"[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column3" = Table.ExpandListColumn(#"From list", "Column1"),
        #"Expanded Column2" = Table.ExpandRecordColumn(#"Expanded Column3", "Column1", {"name", "period", "values"}, {"name", "period", "values"}),
        #"Expanded values" = Table.ExpandListColumn(#"Expanded Column2", "values"),
        #"Expanded values1" = Table.ExpandRecordColumn(#"Expanded values", "values", {"value", "end_time"}, {"value", "end_time"}),
        #"Changed Type1" = Table.TransformColumnTypes(#"Expanded values1",{{"value", Int64.Type}}),
        #"Pivoted Column1" = Table.Pivot(#"Changed Type1", List.Distinct(#"Changed Type1"[name]), "name", "value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column1",{{"end_time", type datetime}}),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"end_time", type date}}),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"end_time", "date"}}),
        #"Removed Column" = Table.RemoveColumns(#"Renamed to date", {"period"}),
        table = Table.TransformColumnTypes(#"Removed Column",{{"impressions", Int64.Type}, {"reach", Int64.Type}, {"profile_views", Int64.Type}, {"website_clicks", Int64.Type}, {"get_directions_clicks", Int64.Type}, {"text_message_clicks", Int64.Type}, {"phone_call_clicks", Int64.Type}, {"email_contacts", Int64.Type}, {"follower_count", Int64.Type}})
    in
        table;


////////////////////////////////////////////////////////////////////////////////////////////////////
////////////                                                                            ////////////
////////////The following functions are a set of helper functions provided by Microsoft ////////////
////////////                                                                           ////////////
///////////////////////////////////////////////////////////////////////////////////////////////////


//// Table Navigation function provided by Microsoft. 
//// Get the full example on how to create a Navigation Table from Microsoft here > https://github.com/Microsoft/DataConnectors/tree/master/samples/NavigationTable

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

//// Function to check if the text string exists or if it should grab the next string
//// Get the full example on why this function was created from Microsoft here > https://github.com/Microsoft/DataConnectors/blob/fe8cb91f694e476bd70c10b9295a815d7bfc42d7/samples/MyGraph/README.md

Value.IfNull = (a, b) => if a <> null then a else b;

//// Function to concatenate all the scopes and create a string for them
//// Get the full example on why this function was created from Microsoft here > https://github.com/Microsoft/DataConnectors/blob/fe8cb91f694e476bd70c10b9295a815d7bfc42d7/samples/MyGraph/README.md
GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

//// Helper function to create sample tables
SampleTable = ( OutputTable as table) as text =>

let
    TableToTransform = Table.FirstN(OutputTable,2),        
    Headers = Text.Combine(List.Transform(Table.ColumnNames(TableToTransform), each """"""&Text.From(_)&""""""), ","),
    Data = Text.Combine(List.Transform(List.Transform(Table.ToRows(TableToTransform), each Text.Combine(List.Transform(_, (_)=> """"""&Text.From(_)&""""""), ",")), each "{"&_&"}"), ","),
    TableFormat = "#table({"&Headers&"},{"&Data&"})"
in
    TableFormat;