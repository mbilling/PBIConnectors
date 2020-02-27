// This file contains your Data Connector logic
section LinkedIn;


appKey = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_id];
appSecret = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_secret];
redirectUrl = Json.Document ( Extension.Contents( "WebApp.json") )  [web][redirect_uris]{0};
token_uri = Json.Document ( Extension.Contents( "WebApp.json") )  [web][token_uri];
authorize_uri = Json.Document ( Extension.Contents( "WebApp.json") )  [web][auth_uri];
logout_uri = "https://www.linkedin.com/oauth/v2/logout";

//// We define the scopes which are simply the types of access the the OAuth will provide
//// See https://developer.linkedin.com/docs/oauth2 for scopes 
scope_prefix = "";
scopes = {
	"r_liteprofile",
    "rw_organization_admin"
};

LinkedIn = [
    TestConnection = (dataSourcePath) => { "LinkedIn.Navigation" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh
        ]
    ],
    Label =  Extension.LoadString ("DataSourceLabel")
];

// Data Source Kind description
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
        client_id = appKey,
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
            client_id = appKey,
            client_secret = appSecret,
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
LinkedIn.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/mbilling/pbiconnectors",
    SourceImage = LinkedIn.Icons,
    SourceTypeImage = LinkedIn.Icons
];

LinkedIn.Icons = [
    Icon16 = { Extension.Contents("LinkedIn16.png"), Extension.Contents("LinkedIn20.png"), Extension.Contents("LinkedIn24.png"), Extension.Contents("LinkedIn32.png") },
    Icon32 = { Extension.Contents("LinkedIn32.png"), Extension.Contents("LinkedIn40.png"), Extension.Contents("LinkedIn48.png"), Extension.Contents("LinkedIn64.png") }
];


[DataSource.Kind="LinkedIn", Publish="LinkedIn.Publish"]
shared LinkedIn.Navigation = Value.ReplaceType(Navigation, NavigationType);

NavigationType = type function () as table meta [                  
        Documentation.Name = "LinkedIn API",
        Documentation.LongDescription = "Returns a table with LinkedIn API analytics",
        Documentation.Examples = {[
            Description = "",
            Code = "",
            Result = ""
        ]}
    ];

 Navigation = () =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},
            {
                {"historical-status-update-statistics", "LinkedIn.historicalStatusUpdateStatistics", LinkedIn.historicalStatusUpdateStatistics(), "Table", "Table", true},
                {"historical-follow-statistics", "LinkedIn.historicalFollowStatistics", LinkedIn.historicalFollowStatistics(), "Table", "Table", true}
            }),
            NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf") 
    in
        NavTable;



[DataSource.Kind="LinkedIn"]
shared LinkedIn.test = ()  =>
  let
    requesturl = "https://api.linkedin.com/v2/organizationalEntityAcls?q=roleAssignee",
    Source = Json.Document(Web.Contents(requesturl))
in
    Source;


[DataSource.Kind="LinkedIn"]
shared LinkedIn.historicalStatusUpdateStatistics = Value.ReplaceType(historicalStatusUpdateStatistics, historicalStatusUpdateStatisticsType);

historicalStatusUpdateStatisticsType = type function () 
        as table meta [
        Documentation.Name = "Get historical status update statistics about a company",
        Documentation.LongDescription = "The Historical Status Update Statistics API provides impression and engagement data on company shares for a given company page. The API can support statistics at both the aggregate and individual status update level. In addition, statistics retrieved by this API are up-to-date in real time.",
        Documentation.Examples = {[
            Description = "",
            Code = "",
            Result = ""
        ]}
    ];

historicalStatusUpdateStatistics = ()  =>
  let
    requesturl = "https://api.linkedin.com/v1/companies?format=json&is-company-admin=true",
    Source = Json.Document(Web.Contents(requesturl)),
	Table = Record.ToTable(Source),
    ValidRows = Table.Skip(Table, 1),
    ValuesOnly = Table.RemoveColumns(ValidRows, {"Name"}),
    CompanyRecords = Table.ExpandListColumn(ValuesOnly, "Value"),
    CompanyRecordsAsColumns = Table.ExpandRecordColumn(CompanyRecords, "Value", {"id", "name"}, {"id", "name"}),

    AddedStats = Table.AddColumn(
        CompanyRecordsAsColumns, 
        "stats",
        each 
            Record.ToTable(
                Json.Document(
                    Web.Contents(
                        Text.Combine({
                            "https://api.linkedin.com/v1/companies/",
                            Number.ToText([id]), 
                            "/historical-status-update-statistics?format=json&start-timestamp=",
                            Number.ToText(Int64.From(Duration.TotalSeconds(Date.AddMonths(DateTime.Date(DateTime.LocalNow()),-14)  - Date.FromText("1970-01-01")) * 1000)),
                            "&time-granularity=day"
                        })
                    )
                )
            )
    ),

    #"Tilføjet brugerdefineret" = Table.AddColumn(AddedStats, "Brugerdefineret", each [stats]{1}),
    #"Udvidet Brugerdefineret" = Table.ExpandRecordColumn(#"Tilføjet brugerdefineret", "Brugerdefineret", {"Value"}, {"Brugerdefineret.Value"}),
    #"Udvidet Brugerdefineret.Value" = Table.ExpandListColumn(#"Udvidet Brugerdefineret", "Brugerdefineret.Value"),
    #"Fjernede kolonner" = Table.RemoveColumns(#"Udvidet Brugerdefineret.Value",{"stats"}),
    #"Udvidet Brugerdefineret.Value1" = Table.ExpandRecordColumn(#"Fjernede kolonner", "Brugerdefineret.Value", {"impressionCount", "time"}, {"Brugerdefineret.Value.impressionCount", "Brugerdefineret.Value.time"}),
    #"Ændret type" = Table.TransformColumnTypes(#"Udvidet Brugerdefineret.Value1",{{"Brugerdefineret.Value.time", type number}}),
    #"Tilføjet brugerdefineret1" = Table.AddColumn(#"Ændret type", "date", each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, [Brugerdefineret.Value.time]/1000)),
    #"Fjernede kolonner1" = Table.RemoveColumns(#"Tilføjet brugerdefineret1",{"Brugerdefineret.Value.time"}),
    #"Omdøbte kolonner" = Table.RenameColumns(#"Fjernede kolonner1",{{"Brugerdefineret.Value.impressionCount", "statusUpdates"}}),
    #"Ændret type1" = Table.TransformColumnTypes(#"Omdøbte kolonner",{{"statusUpdates", Int64.Type}, {"date", type date}})

    in
        #"Ændret type1";

[DataSource.Kind="LinkedIn"]
shared LinkedIn.historicalFollowStatistics = Value.ReplaceType(historicalFollowStatistics, historicalFollowStatisticsType);

historicalFollowStatisticsType = type function () 
        as table meta [
        Documentation.Name = "Get historical follower statistics about a company",
        Documentation.LongDescription = "This call retrieves statistics about followers for a companhy pages. The request returns a follower count for both paid and organic followers within all of the days the past 14 months, based on the requested granularity. 

Statistics retrieved by this API are up-to-date in real time.",
        Documentation.Examples = {[
            Description = "",
            Code = "",
            Result = ""
        ]}
    ];

historicalFollowStatistics = ()  =>
  let
    requesturl = "https://api.linkedin.com/v2/search?q=companiesV2&baseSearchParams.keywords=LinkedIn%20Corporation",
    Source = Json.Document(Web.Contents(requesturl)),
	Table = Record.ToTable(Source),
    ValidRows = Table.Skip(Table, 1),
    ValuesOnly = Table.RemoveColumns(ValidRows, {"Name"}),
    CompanyRecords = Table.ExpandListColumn(ValuesOnly, "Value"),
    CompanyRecordsAsColumns = Table.ExpandRecordColumn(CompanyRecords, "Value", {"id", "name"}, {"id", "name"}),

    AddedStats = Table.AddColumn(
        CompanyRecordsAsColumns, 
        "stats",
        each 
            Record.ToTable(
                Json.Document(
                    Web.Contents(
                        Text.Combine({
                            "https://api.linkedin.com/v1/companies/", 
                            Number.ToText([id]), 
                            "/historical-follow-statistics?format=json&start-timestamp=",
                            Number.ToText(Int64.From(Duration.TotalSeconds(Date.AddMonths(DateTime.Date(DateTime.LocalNow()),-14)  - Date.FromText("1970-01-01")) * 1000)),
                            "&time-granularity=day"
                        })
                    )
                )
            )
    ),

    #"Tilføjet brugerdefineret" = Table.AddColumn(AddedStats, "Brugerdefineret", each [stats]{1}),
    #"Removed Columns" = Table.RemoveColumns(#"Tilføjet brugerdefineret",{"stats"}),
    #"Expanded Brugerdefineret" = Table.ExpandRecordColumn(#"Removed Columns", "Brugerdefineret", {"Value"}, {"Value"}),
    #"Expanded Value" = Table.ExpandListColumn(#"Expanded Brugerdefineret", "Value"),
    #"Expanded Value1" = Table.ExpandRecordColumn(#"Expanded Value", "Value", {"organicFollowerCount", "paidFollowerCount", "time", "totalFollowerCount"}, {"organicFollowerCount", "paidFollowerCount", "time", "totalFollowerCount"}),
    #"Tilføjet brugerdefineret1" = Table.AddColumn( #"Expanded Value1", "date", each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, [time]/1000)),
    #"Changed Type" = Table.TransformColumnTypes(#"Tilføjet brugerdefineret1",{{"id", type text}, {"name", type text}, {"organicFollowerCount", Int64.Type}, {"paidFollowerCount", Int64.Type}, {"totalFollowerCount", Int64.Type}}),
    #"Removed Columns1" = Table.RemoveColumns(#"Changed Type",{"time"}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Removed Columns1",{{"date", type datetime}})

/*    #"Udvidet Brugerdefineret" = Table.ExpandRecordColumn(#"Tilføjet brugerdefineret", "Brugerdefineret", {"Value"}, {"Brugerdefineret.Value"}),
    #"Udvidet Brugerdefineret.Value" = Table.ExpandListColumn(#"Udvidet Brugerdefineret", "Brugerdefineret.Value"),
    #"Fjernede kolonner" = Table.RemoveColumns(#"Udvidet Brugerdefineret.Value",{"stats"}),
    #"Udvidet Brugerdefineret.Value1" = Table.ExpandRecordColumn(#"Fjernede kolonner", "Brugerdefineret.Value", {"impressionCount", "time"}, {"Brugerdefineret.Value.impressionCount", "Brugerdefineret.Value.time"}),
    #"Ændret type" = Table.TransformColumnTypes(#"Udvidet Brugerdefineret.Value1",{{"Brugerdefineret.Value.time", type number}}),
    #"Tilføjet brugerdefineret1" = Table.AddColumn(#"Ændret type", "date", each #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, [Brugerdefineret.Value.time]/1000)),
    #"Fjernede kolonner1" = Table.RemoveColumns(#"Tilføjet brugerdefineret1",{"Brugerdefineret.Value.time"}),
    #"Omdøbte kolonner" = Table.RenameColumns(#"Fjernede kolonner1",{{"Brugerdefineret.Value.impressionCount", "follows"}}),
    #"Ændret type1" = Table.TransformColumnTypes(#"Omdøbte kolonner",{{"follows", Int64.Type}, {"date", type date}})
*/
    in
        #"Changed Type1";



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