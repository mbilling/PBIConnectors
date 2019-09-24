// This file contains your Data Connector logic
section FacebookPages;

client_id       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_id];
client_secret   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][client_secret];
token_uri       = Json.Document ( Extension.Contents( "WebApp.json") ) [web][token_uri];
authorize_uri   = Json.Document ( Extension.Contents( "WebApp.json") ) [web][authorize_uri];

redirectUrl = "https://oauth.powerbi.com/views/oauthredirect.html";

baseUrl = "https://graph.facebook.com/v4.0/";
scope_prefix = "";
scopes = {
	"manage_pages", "read_insights"
};

FacebookPages = [
    TestConnection = (dataSourcePath) => { "FacebookPages.Contents" },
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

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", refresh_token);

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
FacebookPages.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/mbilling/pbiconnectors",
    SourceImage = FacebookPages.Icons,
    SourceTypeImage = FacebookPages.Icons
];

FacebookPages.Icons = [
    Icon16 = { Extension.Contents("FacebookPages16.png"), Extension.Contents("FacebookPages20.png"), Extension.Contents("FacebookPages24.png"), Extension.Contents("FacebookPages32.png") },
    Icon32 = { Extension.Contents("FacebookPages32.png"), Extension.Contents("FacebookPages40.png"), Extension.Contents("FacebookPages48.png"), Extension.Contents("FacebookPages64.png") }
];


// Navigation entry point
[DataSource.Kind="FacebookPages", Publish="FacebookPages.Publish"]
shared FacebookPages.Contents = (optional url as text, optional params as record) =>
    let
        key = Extension.CurrentCredential()[access_token],
        seed = baseUrl & "me/accounts?" & Uri.BuildQueryString([access_token=key, fields="name,access_token", limit="500"]),
        pagedResult = FacebookPages.GetPagedData(seed, {}),
        table = PagesToNavTabler(pagedResult)
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
        presets = {"last_7d", "last_14d", "last_28d", "last_30d", "last_90d", "lifetime"},
        navHeader = {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, 
        navInsights = List.Accumulate(presets, {}, (state, current) => state & {{current, current, GetInsights(page, current), "Table", "Table", false}} ),
        objects = #table(navHeader, navInsights),
        table = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        table;

GetInsights = (page as record, preset as text) =>
    let
        objects = #table(
            {"Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"},{
//            {"FB Page Story Insights", "FB Page Story Insights", GetPageStoryInsights(page, preset), "Table", "Table", true},
            {"FB Page Impression Insights", "FB Page Impression Insights", GetPageImpressionInsights(page, preset), "Table", "Table", true},
            {"FB Page Engagement Insights", "FB Page Engagement Insights", GetPageEngagementInsights(page, preset), "Table", "Table", true},
            {"FB Page Reaction Insights", "FB Page Reaction Insights", GetPageReactionInsights(page, preset), "Table", "Table", true},
            {"FB Page CTA Click Insights", "FB Page CTA Click Insights", GetPageCTAClickInsights(page, preset), "Table", "Table", true},
            {"FB Page View Insights", "FB Page View Insights", GetPageViewInsights(page, preset), "Table", "Table", true},
            {"FB Page Fan Total", "FB Page Fan Total", GetPageFanTotal(page), "Table", "Table", true},
            {"FB Page Fan Insights", "FB Page Fan Insights", GetPageFanInsights(page, preset), "Table", "Table", true},
            {"FB Page Video Insights", "FB Page Video Insights", GetPageVideoInsights(page, preset), "Table", "Table", true},
            {"FB Page Post Insights", "FB Page Post Insights", GetPagePostInsights(page, preset), "Table", "Table", true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

GetPageStoryInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_content_activity",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_content_activity", Int64.Type}}, "en-US")
    in
        table;

GetPageImpressionInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_impressions,page_impressions_unique,page_impressions_paid,page_impressions_paid_unique,page_impressions_organic,page_impressions_organic_unique,page_impressions_viral,page_impressions_viral_unique,page_impressions_nonviral,page_impressions_nonviral_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_impressions_organic", Int64.Type}, {"page_impressions_organic_unique", Int64.Type}, {"page_impressions", Int64.Type}, {"page_impressions_unique", Int64.Type}, {"page_impressions_paid", Int64.Type}, {"page_impressions_paid_unique", Int64.Type}, {"page_impressions_viral", Int64.Type}, {"page_impressions_viral_unique", Int64.Type}, {"page_impressions_nonviral", Int64.Type}, {"page_impressions_nonviral_unique", Int64.Type}}, "en-US")
    in
        table;


GetPageEngagementInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_engaged_users,page_post_engagements,page_consumptions,page_consumptions_unique,page_negative_feedback,page_negative_feedback_unique,page_places_checkin_total,page_places_checkin_total_unique,page_places_checkin_mobile,page_places_checkin_mobile_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_engaged_users", Int64.Type}, {"page_post_engagements", Int64.Type}, {"page_consumptions", Int64.Type}, {"page_consumptions_unique", Int64.Type}, {"page_negative_feedback", Int64.Type}, {"page_negative_feedback_unique", Int64.Type}, {"page_places_checkin_total", Int64.Type}, {"page_places_checkin_total_unique", Int64.Type}, {"page_places_checkin_mobile", Int64.Type}, {"page_places_checkin_mobile_unique", Int64.Type}}, "en-US")
    in
        table;

GetPageReactionInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_actions_post_reactions_like_total,page_actions_post_reactions_love_total,page_actions_post_reactions_wow_total,page_actions_post_reactions_haha_total,page_actions_post_reactions_sorry_total,page_actions_post_reactions_anger_total,page_actions_post_reactions_total",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_actions_post_reactions_like_total", Int64.Type}, {"page_actions_post_reactions_love_total", Int64.Type}, {"page_actions_post_reactions_wow_total", Int64.Type}, {"page_actions_post_reactions_haha_total", Int64.Type}, {"page_actions_post_reactions_sorry_total", Int64.Type}, {"page_actions_post_reactions_anger_total", Int64.Type}, {"page_actions_post_reactions_total", Int64.Type}}, "en-US")
    in
        table;

GetPageCTAClickInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_total_actions,page_call_phone_clicks_logged_in_unique,page_get_directions_clicks_logged_in_unique,page_website_clicks_logged_in_unique,page_cta_clicks_logged_in_total,page_cta_clicks_logged_in_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_total_actions", Int64.Type}, {"page_call_phone_clicks_logged_in_unique", Int64.Type}, {"page_get_directions_clicks_logged_in_unique", Int64.Type}, {"page_website_clicks_logged_in_unique", Int64.Type}, {"page_cta_clicks_logged_in_unique", Int64.Type}}, "en-US")
    in
        table;

GetPageViewInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_views_total,page_views_logout,page_views_logged_in_total,page_views_logged_in_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_views_total", Int64.Type}, {"page_views_logout", Int64.Type}, {"page_views_logged_in_total", Int64.Type}, {"page_views_logged_in_unique", Int64.Type}}, "en-US")
    in
        table;

GetPageFanTotal = (page as record) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_fans",period="day",show_description_from_api_doc="false",date_preset="yesterday",access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_fans", Int64.Type}}, "en-US")
    in
        table;

GetPageFanInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_fans,page_fan_adds,page_fan_adds_unique,page_fan_removes,page_fan_removes_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_fans", Int64.Type}, {"page_fan_adds", Int64.Type}, {"page_fan_adds_unique", Int64.Type}, {"page_fan_removes", Int64.Type}, {"page_fan_removes_unique", Int64.Type}}, "en-US")
    in
        table;

GetPageVideoInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_video_views,page_video_views_paid,page_video_views_organic,page_video_views_autoplayed,page_video_views_click_to_play,page_video_views_unique,page_video_repeat_views,page_video_complete_views_30s,page_video_complete_views_30s_paid,page_video_complete_views_30s_organic,page_video_complete_views_30s_autoplayed,page_video_complete_views_30s_click_to_play,page_video_complete_views_30s_unique,page_video_views_10s,page_video_views_10s_paid,page_video_views_10s_organic,page_video_views_10s_autoplayed,page_video_views_10s_click_to_play,page_video_views_10s_unique,page_video_views_10s_repeat,page_video_view_time",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_video_views", Int64.Type},{"page_video_views_paid", Int64.Type},{"page_video_views_organic", Int64.Type},{"page_video_views_autoplayed", Int64.Type},{"page_video_views_click_to_play", Int64.Type},{"page_video_views_unique", Int64.Type},{"page_video_repeat_views", Int64.Type},{"page_video_complete_views_30s", Int64.Type},{"page_video_complete_views_30s_paid", Int64.Type},{"page_video_complete_views_30s_organic", Int64.Type},{"page_video_complete_views_30s_autoplayed", Int64.Type},{"page_video_complete_views_30s_click_to_play", Int64.Type},{"page_video_complete_views_30s_unique", Int64.Type},{"page_video_views_10s", Int64.Type},{"page_video_views_10s_paid", Int64.Type},{"page_video_views_10s_organic", Int64.Type},{"page_video_views_10s_autoplayed", Int64.Type},{"page_video_views_10s_click_to_play", Int64.Type},{"page_video_views_10s_unique", Int64.Type},{"page_video_views_10s_repeat", Int64.Type},{"page_video_view_time", Int64.Type}}, "en-US")
 
 in
        table;

GetPagePostInsights = (page as record, preset as text) =>
    let
        response = Web.Contents(baseUrl & page[id] & "/insights?" & Uri.BuildQueryString([metric="page_posts_impressions,page_posts_impressions_unique,page_posts_impressions_paid,page_posts_impressions_paid_unique,page_posts_impressions_organic,page_posts_impressions_organic_unique,page_posts_impressions_viral,page_posts_impressions_viral_unique,page_posts_impressions_nonviral,page_posts_impressions_nonviral_unique",period="day",show_description_from_api_doc="false",date_preset=preset,access_token=page[access_token]])),
        data = Json.Document(response)[data],
        #"From list" = Table.FromList(data, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded {0}" = Table.ExpandRecordColumn(#"From list", "Column1", {"name", "period", "values"}, {"Column1.name", "Column1.period", "Column1.values"}),
        #"Expanded {0}1" = Table.ExpandListColumn(#"Expanded {0}", "Column1.values"),
        #"Removed Columns" = Table.RemoveColumns(#"Expanded {0}1",{"Column1.period"}),
        #"Expanded {0}2" = Table.ExpandRecordColumn(#"Removed Columns", "Column1.values", {"value", "end_time"}, {"Column1.values.value", "Column1.values.end_time"}),
        #"Pivoted Column" = Table.Pivot(#"Expanded {0}2", List.Distinct(#"Expanded {0}2"[Column1.name]), "Column1.name", "Column1.values.value", List.Sum),
        #"Changed Type" = Table.TransformColumnTypes(#"Pivoted Column",{{"Column1.values.end_time", type datetime}}, "en-US"),
        #"Changed Type Date" = Table.TransformColumnTypes(#"Changed Type",{{"Column1.values.end_time", type date}}, "en-US"),
        #"Renamed to date" = Table.RenameColumns(#"Changed Type Date",{{"Column1.values.end_time", "date"}}),
        table = Table.TransformColumnTypes(#"Renamed to date",{{"page_posts_impressions", Int64.Type},{"page_posts_impressions_unique", Int64.Type},{"page_posts_impressions_paid", Int64.Type},{"page_posts_impressions_paid_unique", Int64.Type},{"page_posts_impressions_organic", Int64.Type},{"page_posts_impressions_organic_unique", Int64.Type},{"page_posts_impressions_viral", Int64.Type},{"page_posts_impressions_viral_unique", Int64.Type},{"page_posts_impressions_nonviral", Int64.Type},{"page_posts_impressions_nonviral_unique", Int64.Type}}, "en-US")
 in
        table;


FacebookPages.GetPagedData = (query, result) =>
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
                FacebookPages.GetPagedData(nextQuery, newResult)
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