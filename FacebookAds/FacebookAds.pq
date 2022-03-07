// This file contains your Data Connector logic
section FacebookAds;

client_id       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_id];
client_secret   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_secret];
token_uri       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][token_uri];
authorize_uri   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][authorize_uri];
redirectUrl = "https://oauth.powerbi.com/views/oauthredirect.html";
    
baseUrl = "https://graph.facebook.com/v13.0/";
fetchLimit = "100";

scope_prefix = "";
scopes = { "read_insights", "pages_manage_ads", "pages_manage_metadata", "pages_read_engagement", "pages_read_user_content", "pages_manage_posts", "pages_manage_engagement", "ads_management" };

FacebookAds = [
    TestConnection = (dataSourcePath) => { "FacebookAds.Ads" },
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
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
        response_type = "token"
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
        access_token = Text.Split(Text.Split(Text.Split(callbackUri, "#"){1}, "&"){0}, "="){1},
        result = TokenMethod("fb_exchange_token", "fb_exchange_token", access_token)
    in
        result;

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = grantType,
            client_id = client_id,
            client_secret = client_secret,
            redirect_uri = redirectUrl
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        response = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"], 
            ManualStatusHandling = {400}
        ]),
        body = Json.Document(response),
        result = if(Record.HasFields(body, {"error", "error_description"})) then  
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

// Data Source UI publishing description
FacebookAds.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/mbilling/pbiconnectors",
    SourceImage = FacebookAds.Icons,
    SourceTypeImage = FacebookAds.Icons
];

FacebookAds.Icons = [
    Icon16 = { Extension.Contents("FacebookAds16.png"), Extension.Contents("FacebookAds20.png"), Extension.Contents("FacebookAds24.png"), Extension.Contents("FacebookAds32.png") },
    Icon32 = { Extension.Contents("FacebookAds32.png"), Extension.Contents("FacebookAds40.png"), Extension.Contents("FacebookAds48.png"), Extension.Contents("FacebookAds64.png") }
];


// Navigation entry point
[DataSource.Kind="FacebookAds", Publish="FacebookAds.Publish"]
shared FacebookAds.Ads = (optional url as text, optional params as record) =>
    let
        key = Extension.CurrentCredential()[access_token],
        seed = baseUrl & "me/adaccounts?" & Uri.BuildQueryString([access_token=key,fields="id,name",limit="1"]),
        pagedResult = FacebookAds.GetPagedData(seed, {}),
        table = FacebookAds.AdAccountsToNavigationTable(pagedResult)
    in
        table;

shared FacebookAds.AdAccountsToNavigationTable = (adAccounts as list) =>
    
    let
        a = Diagnostics.Trace(TraceLevel.Warning, "Hello", "test"),
        navHeader = {"Name","Key","Data","ItemKind", "ItemName", "IsLeaf"}, 
        navAdAccounts = List.Accumulate(adAccounts, {}, (state, current) => state & {{current[name], current[name], FacebookAds.GetInsights(current), "Table", "Table", false}} ),
        objects = #table(navHeader, navAdAccounts),
        table = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        
        table;

shared FacebookAds.GetInsights = (adAccount as record) =>
    let
        objects = #table(
            {"Name",                                            "Key",                                      "Data",                                                                 "ItemKind", "ItemName", "IsLeaf"},{
            {"Facebook All Ad Insights",                        "Facebook All Ad Insights",                         FacebookAds.GetAdInsights(adAccount, "maximum", false),        "Table",    "Table",    true},
            {"Facebook All Ad Insights Last 30 days",           "Facebook All Ad Insights Last 30 days",            FacebookAds.GetAdInsights(adAccount, "last_30d", false),        "Table",    "Table",    true},
            {"Facebook All Ad Insights Last 90 days",           "Facebook All Ad Insights Last 90 days",            FacebookAds.GetAdInsights(adAccount, "last_90d", false),        "Table",    "Table",    true},

            {"Facebook Ad Actions",                             "Facebook Ad Actions",                              FacebookAds.GetAdActions(adAccount, "maximum", false),         "Table",    "Table",    true},
            {"Facebook Ad Actions Last 30 days",                "Facebook Ad Actions Last 30 days",                 FacebookAds.GetAdActions(adAccount, "last_30d", false),         "Table",    "Table",    true},
            {"Facebook Ad Actions Last 90 days",                "Facebook Ad Actions Last 90 days",                 FacebookAds.GetAdActions(adAccount, "last_90d", false),         "Table",    "Table",    true},

            {"Facebook Ad Action Values",                       "Facebook Ad Action Values",                        FacebookAds.GetAdActionValues(adAccount, "maximum", false),    "Table",    "Table",    true},
            {"Facebook Ad Action Values Last 30 days",          "Facebook Ad Action Values Last 30 days",           FacebookAds.GetAdActionValues(adAccount, "last_30d", false),    "Table",    "Table",    true},
            {"Facebook Ad Action Values Last 90 days",          "Facebook Ad Action Values Last 90 days",           FacebookAds.GetAdActionValues(adAccount, "last_90d", false),    "Table",    "Table",    true},


            {"Facebook Active Ad Insights",                     "Facebook Active Ad Insights",                      FacebookAds.GetAdInsights(adAccount, "maximum", true),         "Table",    "Table",    true},
            {"Facebook Active Ad Insights Last 30 days",        "Facebook Active Ad Insights Last 30 days",         FacebookAds.GetAdInsights(adAccount, "last_30d", true),         "Table",    "Table",    true},
            {"Facebook Active Ad Insights Last 90 days",        "Facebook Active Ad Insights Last 90 days",         FacebookAds.GetAdInsights(adAccount, "last_90d", true),         "Table",    "Table",    true},

            {"Facebook Active Ad Actions",                      "Facebook Active Ad Actions",                       FacebookAds.GetAdActions(adAccount, "maximum", true),          "Table",    "Table",    true},
            {"Facebook Active Ad Actions Last 30 days",         "Facebook Active Ad Actions Last 30 days",          FacebookAds.GetAdActions(adAccount, "last_30d", true),          "Table",    "Table",    true},
            {"Facebook Active Ad Actions Last 90 days",         "Facebook Active Ad Actions Last 90 days",          FacebookAds.GetAdActions(adAccount, "last_90d", true),          "Table",    "Table",    true},

            {"Facebook Active Ad Action Values",                "Facebook Active Ad Action Values",                 FacebookAds.GetAdActionValues(adAccount, "maximum", true),     "Table",    "Table",    true},
            {"Facebook Active Ad Action Values Last 30 days",   "Facebook Active Ad Action Values Last 30 days",    FacebookAds.GetAdActionValues(adAccount, "last_30d", true),     "Table",    "Table",    true},
            {"Facebook Active Ad Action Values Last 90 days",   "Facebook Active Ad Action Values Last 90 days",    FacebookAds.GetAdActionValues(adAccount, "last_90d", true),     "Table",    "Table",    true}

        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
        
shared FacebookAds.GetAdInsights = (adAccount as record, date_preset as text, activeOnly as logical) =>
    let
        access_token = Extension.CurrentCredential()[access_token],
        seed = baseUrl & adAccount[id] & "/ads?" & Uri.BuildQueryString([access_token=access_token, fields="name, effective_status", date_preset=date_preset, limit="500"]),

        joined_response = List.Accumulate(
            {1}, 
            {},
            (state, adId) => List.Combine(
                { 
                  state, 
                  FacebookAds.GetPagedData(seed, {})
                }
            )
        ),

        response = () =>
            let 
                response = Table.FromList(joined_response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                tableOfAdIds = Table.ExpandRecordColumn(response, "Column1", {"id", "effective_status"}),
 
                adIds = tableOfAdIds[data]{0},
                selectedAdIds = if activeOnly then Table.SelectRows(tableOfAdIds, each _[effective_status] = "ACTIVE") else tableOfAdIds,
                
                list = if List.Count(selectedAdIds[id]) > 0 
                    then
                        List.Accumulate(
                            selectedAdIds[id], 
                            {},
                            (state, adId) => List.Combine(
                                { 
                                  state, 
                                  FacebookAds.GetPagedData(baseUrl & adId & "/insights?" & Uri.BuildQueryString([access_token=access_token,fields="ad_id,campaign_id,adset_id,ad_name,account_id,adset_name,campaign_name,reach,impressions,frequency,unique_clicks,spend,unique_inline_link_clicks,cpc,cpm,clicks,account_currency,account_name,social_spend,objective,inline_link_clicks,inline_post_engagement", level="ad", date_preset=date_preset, time_increment="1", limit=fetchLimit]), {})
                                }
                            )
                        )
                    else
                        {},

                unwrapResults = (list) => 
                    let 
                        table = Table.FromList(list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                        expanded = Table.ExpandRecordColumn(table, "Column1", {"date_start", "ad_id", "campaign_id", "adset_id", "ad_name", "account_id", "adset_name", "campaign_name", "total_actions", "reach", "impressions", "frequency", "unique_clicks", "spend", "unique_inline_link_clicks", "unique_social_clicks", "cpc", "cpm", "call_to_action_clicks", "clicks", "account_currency", "account_name", "social_impressions", "social_clicks", "social_reach", "social_spend", "objective", "inline_link_clicks", "inline_post_engagement", "has_error","error_reason", "error_message"}, {"date", "Ad ID", "Campaign ID", "Adset ID", "Ad Name", "Account ID", "Adset Name", "Campaign Name", "Total Actions", "Reach", "Impressions", "Frequency", "Unique Clicks", "Spend", "Unique Inline Link Clicks", "Unique Social Clicks", "CPC", "CPM", "Call To Action Clicks", "Clicks", "Account Currency", "Account Name", "Social Impressions", "Social Clicks", "Social Reach", "Social Spend", "Objective", "Inline Link Clicks", "Inline Post Engagement", "Connector Has Error", "Connector Error Reason", "Connector Error Message"}),
                        tableWithFBKey = Table.AddColumn(expanded, "facebook_ad_key", each [date] & "_" & [Account ID] & "_" & [Campaign ID] & "_" & [Adset ID] & "_" & [Ad ID]),
                        tableTyped = Table.TransformColumnTypes(tableWithFBKey, {{"Ad ID", type text}, {"Campaign ID", type text}, {"Adset ID", type text}, {"Ad Name", type text}, {"Account ID", type text}, {"Adset Name", type text}, {"Campaign Name", type text}, {"Account Name", type text}, {"Objective", type text}, {"date", type date}, {"Total Actions", Int64.Type}, {"Reach", Int64.Type}, {"Impressions", Int64.Type}, {"Unique Inline Link Clicks", Int64.Type}, {"Unique Social Clicks", Int64.Type}, {"Call To Action Clicks", Int64.Type}, {"Clicks", Int64.Type}, {"Social Impressions", Int64.Type}, {"Social Clicks", Int64.Type}, {"Social Reach", Int64.Type}, {"Inline Link Clicks", Int64.Type}, {"Inline Post Engagement", Int64.Type}, {"Frequency", type number}, {"Spend", type number}, {"CPC", type number}, {"CPM", type number}, {"Social Spend", type number}}, "en-US"),
                        tableOrderedColumns = Table.ReorderColumns(tableTyped, {"facebook_ad_key", "date", "Ad ID", "Campaign ID", "Adset ID", "Ad Name", "Account ID", "Adset Name", "Campaign Name", "Total Actions", "Reach", "Impressions", "Frequency", "Unique Clicks", "Spend", "Unique Inline Link Clicks", "Unique Social Clicks", "CPC", "CPM", "Call To Action Clicks", "Clicks", "Account Currency", "Account Name", "Social Impressions", "Social Clicks", "Social Reach", "Social Spend", "Objective", "Inline Link Clicks", "Inline Post Engagement"})
                    in 
                        tableOrderedColumns,

                changed = if List.Count(list) > 0 then
                        let
                            unwrappedResults = unwrapResults(list),
                            JoinedTables = Table.NestedJoin(unwrappedResults,{"Ad ID"},selectedAdIds,{"id"},"JoinedTable",JoinKind.LeftOuter),
                            out = Table.ExpandTableColumn(JoinedTables, "JoinedTable", {"effective_status"})
                        in
                            out
                    else
                        {}
            in 
                changed,

        result = if List.Count(joined_response) > 0 then 
            response()
        else 
            null
    in
        result;

shared FacebookAds.GetAdActions = (adAccount as record, date_preset as text, activeOnly as logical) =>
    let
        access_token = Extension.CurrentCredential()[access_token],
        seed = baseUrl & adAccount[id] & "/ads?" & Uri.BuildQueryString([access_token=access_token, fields="name, effective_status", date_preset=date_preset, limit="500"]),

        joined_response = List.Accumulate(
            {1}, 
            {},
            (state, adId) => List.Combine(
                { 
                  state, 
                  FacebookAds.GetPagedData(seed, {})
                }
            )
        ),

        response = () =>
            let 
                response = Table.FromList(joined_response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                tableOfAdIds = Table.ExpandRecordColumn(response, "Column1", {"id", "effective_status"}),
 
                adIds = tableOfAdIds[data]{0},
                selectedAdIds = if activeOnly then Table.SelectRows(tableOfAdIds, each _[effective_status] = "ACTIVE") else tableOfAdIds,
                
                list = if List.Count(selectedAdIds[id]) > 0 
                    then
                        List.Accumulate(
                            selectedAdIds[id], 
                            {},
                            (state, adId) => List.Combine(
                                { 
                                  state, 
                                  FacebookAds.GetPagedData(baseUrl & adId & "/insights?" & Uri.BuildQueryString([access_token=access_token,fields="ad_id,campaign_id,adset_id,account_id,actions", level="ad", date_preset=date_preset, time_increment="1", limit=fetchLimit]), {})
                                }
                            )
                        )
                    else
                        {},

                unwrapResults = (list) => 
                    let 
                        table = Table.FromList(list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                        expanded = Table.ExpandRecordColumn(table, "Column1", {"date_start", "ad_id", "campaign_id", "adset_id", "account_id", "actions", "has_error","error_reason", "error_message"}, {"date", "Ad ID", "Campaign ID", "Adset ID", "Account ID", "Actions", "Connector Has Error", "Connector Error Reason", "Connector Error Message"}),
                        tableWithFBKey = Table.AddColumn(expanded, "facebook_ad_key", each [date] & "_" & [Account ID] & "_" & [Campaign ID] & "_" & [Adset ID] & "_" & [Ad ID]),
                        tableTyped = Table.TransformColumnTypes(tableWithFBKey, {{"Ad ID", type text}, {"Campaign ID", type text}, {"Adset ID", type text}, {"Account ID", type text}, {"date", type date}}, "en-US"),
                        tableOrderedColumns = Table.ReorderColumns(tableTyped, {"facebook_ad_key", "date", "Ad ID", "Campaign ID", "Adset ID", "Account ID", "Actions"}),
                        expandedActionsList = Table.ExpandListColumn(tableOrderedColumns, "Actions"),
                        expandedActionsRecord = Table.ExpandRecordColumn(expandedActionsList, "Actions", {"action_type", "value"}, {"action_type", "value"}),
                        expandedActionValuesTyped = Table.TransformColumnTypes(expandedActionsRecord,{{"value", type number}, {"action_type", type text}}, "en-US"),
                        removedNulls = Table.ReplaceValue(expandedActionValuesTyped,null,"(unknown)",Replacer.ReplaceValue,{"action_type"}),
                        tableWithAddedMetricsAsColumns = Table.Pivot(removedNulls, List.Distinct(removedNulls[action_type]), "action_type", "value", List.Sum),
                        removedArtifactUnknownColumn = try Table.RemoveColumns(tableWithAddedMetricsAsColumns, {"(unknown)"}) otherwise tableWithAddedMetricsAsColumns
                    in 
                        removedArtifactUnknownColumn,

                changed = if List.Count(list) > 0 then
                        let
                            unwrappedResults = unwrapResults(list),
                            JoinedTables = Table.NestedJoin(unwrappedResults,{"Ad ID"},selectedAdIds,{"id"},"JoinedTable",JoinKind.LeftOuter),
                            out = Table.ExpandTableColumn(JoinedTables, "JoinedTable", {"effective_status"})
                        in
                            out
                    else
                        {}
            in 
                changed,

        result = if List.Count(joined_response) > 0 then 
            response()
        else 
            null
    in
        result;

shared FacebookAds.GetAdActionValues = (adAccount as record, date_preset as text, activeOnly as logical) =>
    let
        access_token = Extension.CurrentCredential()[access_token],
        seed = baseUrl & adAccount[id] & "/ads?" & Uri.BuildQueryString([access_token=access_token, fields="name, effective_status", date_preset=date_preset, limit="500"]),

        joined_response = List.Accumulate(
            {1}, 
            {},
            (state, adId) => List.Combine(
                { 
                  state, 
                  FacebookAds.GetPagedData(seed, {})
                }
            )
        ),

        response = () =>
            let 
                response = Table.FromList(joined_response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                tableOfAdIds = Table.ExpandRecordColumn(response, "Column1", {"id", "effective_status"}),
 
                adIds = tableOfAdIds[data]{0},
                selectedAdIds = if activeOnly then Table.SelectRows(tableOfAdIds, each _[effective_status] = "ACTIVE") else tableOfAdIds,
                
                list = if List.Count(selectedAdIds[id]) > 0 
                    then
                        List.Accumulate(
                            selectedAdIds[id], 
                            {},
                            (state, adId) => List.Combine(
                                { 
                                  state,
                                  FacebookAds.GetPagedData(baseUrl & adId & "/insights?" & Uri.BuildQueryString([access_token=access_token,fields="ad_id,campaign_id,adset_id,account_id,action_values", level="ad", date_preset=date_preset, time_increment="1", limit=fetchLimit]), {})
                                }
                            )
                        )
                    else
                        {},

                unwrapResults = (list) => 
                    let 
                        table = Table.FromList(list, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                        expanded = Table.ExpandRecordColumn(table, "Column1", {"date_start", "ad_id", "campaign_id", "adset_id", "account_id", "action_values", "has_error","error_reason", "error_message"}, {"date", "Ad ID", "Campaign ID", "Adset ID", "Account ID", "Action Values", "Connector Has Error", "Connector Error Reason", "Connector Error Message"}),
                        tableWithFBKey = Table.AddColumn(expanded, "facebook_ad_key", each [date] & "_" & [Account ID] & "_" & [Campaign ID] & "_" & [Adset ID] & "_" & [Ad ID]),
                        tableTyped = Table.TransformColumnTypes(tableWithFBKey, {{"Ad ID", type text}, {"Campaign ID", type text}, {"Adset ID", type text}, {"Account ID", type text}, {"date", type date}}, "en-US"),
                        tableOrderedColumns = Table.ReorderColumns(tableTyped, {"facebook_ad_key", "date", "Ad ID", "Campaign ID", "Adset ID", "Account ID", "Action Values"}),
                        expandedActionValuesList = Table.ExpandListColumn(tableOrderedColumns, "Action Values"),
                        expandedActionValuesRecord = Table.ExpandRecordColumn(expandedActionValuesList, "Action Values", {"action_type", "value"}, {"action_type", "value"}),
                        expandedActionValuesTyped = Table.TransformColumnTypes(expandedActionValuesRecord,{{"value", type number}, {"action_type", type text}}, "en-US"),
                        removedNulls = Table.ReplaceValue(expandedActionValuesTyped,null,"(unknown)",Replacer.ReplaceValue,{"action_type"}),
                        tableWithAddedMetricsAsColumns = Table.Pivot(removedNulls, List.Distinct(removedNulls[action_type]), "action_type", "value", List.Sum),
                        removedArtifactUnknownColumn = try Table.RemoveColumns(tableWithAddedMetricsAsColumns, {"(unknown)"}) otherwise tableWithAddedMetricsAsColumns
                    in 
                        removedArtifactUnknownColumn,

                changed = if List.Count(list) > 0 then
                        let
                            unwrappedResults = unwrapResults(list),
                            JoinedTables = Table.NestedJoin(unwrappedResults,{"Ad ID"},selectedAdIds,{"id"},"JoinedTable",JoinKind.LeftOuter),
                            out = Table.ExpandTableColumn(JoinedTables, "JoinedTable", {"effective_status"})
                        in
                            out
                    else
                        {}
            in 
                changed,

        result = if List.Count(joined_response) > 0 then 
            response()
        else 
            null
    in
        result;


FacebookAds.GetPagedData = (query, result) =>
    let
        response = Json.Document(Web.Contents(query)),
        newResult = List.Combine({result, response[data]}),
        nextQuery = try response[paging][next] otherwise null,
        testForError = try response
    in
        if testForError[HasError] then 
            {[has_error = testForError[HasError], error_value = try testForError[Value], error_reason = testForError[Error][Reason], error_message = testForError[Error][Message]]}
        else 
            if nextQuery <> null then 
                FacebookAds.GetPagedData(nextQuery, newResult)
            else
                newResult;

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