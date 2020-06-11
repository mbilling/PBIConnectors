// This file contains your Data Connector logic
section Thinkific;

// Data Source Kind description
// Key should be a combination of your Thinkific domain and your API key
// [domain]=[key]
// E.g. mycompanycom=XYXYXYXYXYXYXYX
Thinkific = [
 TestConnection = (dataSourcePath) => { "Thinkific.Navigation" },
    Authentication = [
        Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Thinkific.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Thinkific.Icons,
    SourceTypeImage = Thinkific.Icons
];

Thinkific.Icons = [
    Icon16 = { Extension.Contents("Thinkific16.png"), Extension.Contents("Thinkific20.png"), Extension.Contents("Thinkific24.png"), Extension.Contents("Thinkific32.png") },
    Icon32 = { Extension.Contents("Thinkific32.png"), Extension.Contents("Thinkific40.png"), Extension.Contents("Thinkific48.png"), Extension.Contents("Thinkific64.png") }
];

[DataSource.Kind="Thinkific", Publish="Thinkific.Publish"]
shared Thinkific.Navigation = Value.ReplaceType(Navigation, NavigationType);

NavigationType = type function () as table meta [                  
        Documentation.Name = "Thinkific",
        Documentation.LongDescription = "Accesses all objects available through the Thinkific API.",
        Documentation.Examples = {[
            Description = "",
            Code = "",
            Result = ""
        ]}
    ];

Navigation = () as table => 
    let
        objects = #table(
            {
                "Name", "Key", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
                {"Instructors", "Thinkific.Instructors", Thinkific.Instructors(), "Table", "Table", true},
                {"Categories", "Thinkific.Categories", Thinkific.Categories(), "Table", "Table", true},
                {"Courses", "Thinkific.Courses", Thinkific.Courses(), "Table", "Table", true},
                {"Users", "Thinkific.Users", Thinkific.Users(), "Table", "Table", true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

[DataSource.Kind="Thinkific"]
shared Thinkific.Instructors = () =>
    let
        url = "https://api.thinkific.com/api/public/v1/instructors",
        items = GetPagedData(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"id", "first_name", "last_name", "bio", "created_at", "user_id", "title", "slug", "avatar_url", "email"}, {"id", "first_name", "last_name", "bio", "created_at", "user_id", "title", "slug", "avatar_url", "email"})
    in
        expanded;

[DataSource.Kind="Thinkific"]
shared Thinkific.Categories = () =>
    let
        url = "https://api.thinkific.com/api/public/v1/collections",
        items = GetPagedData(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"id", "name", "description", "slug", "default", "created_at", "product_ids"}, {"id", "name", "description", "slug", "default", "created_at", "product_ids"})
    in
        expanded;

[DataSource.Kind="Thinkific"]
shared Thinkific.Courses = () =>
    let
        url = "https://api.thinkific.com/api/public/v1/courses",
        items = GetPagedData(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"id", "name", "slug", "subtitle", "product_id", "description", "intro_video_youtube", "contact_information", "keywords", "duration", "banner_image_url", "course_card_image_url", "intro_video_wistia_identifier", "administrator_user_ids", "user_id", "reviews_enabled", "instructor_id", "chapter_ids", "course_card_text"}, {"id", "name", "slug", "subtitle", "product_id", "description", "intro_video_youtube", "contact_information", "keywords", "duration", "banner_image_url", "course_card_image_url", "intro_video_wistia_identifier", "administrator_user_ids", "user_id", "reviews_enabled", "instructor_id", "chapter_ids", "course_card_text"})
    in
        expanded;

[DataSource.Kind="Thinkific"]
shared Thinkific.Users = () =>
    let
        url = "https://api.thinkific.com/api/public/v1/users",
        items = GetPagedData(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"id", "created_at", "first_name", "last_name", "full_name", "company", "email", "roles", "avatar_url", "bio", "headline", "affiliate_code", "external_source", "affiliate_commission", "affiliate_commission_type", "affiliate_payout_email", "administered_course_ids", "custom_profile_fields"}, {"id", "created_at", "first_name", "last_name", "full_name", "company", "email", "roles", "avatar_url", "bio", "headline", "affiliate_code", "external_source", "affiliate_commission", "affiliate_commission_type", "affiliate_payout_email", "administered_course_ids", "custom_profile_fields"})
    in
        expanded;

Thinkific.Raw = (url) =>
    
    let keys = Text.Split(Extension.CurrentCredential()[Key], "="),
    domain = keys{0},
    key = keys{1},
    headers = [
        #"X-Auth-API-Key" = key,
        #"X-Auth-Subdomain" = domain,
        Accept = "application/vnd.api+json",
        #"Content-Type" = "application/json"
        ],
        rawResponse = Web.Contents(url, [ Headers = headers, ManualCredentials = true ]),
        response = Json.Document(rawResponse)
    in
        response;

GetPagedData = (url) =>
    let getPages = (endpoint, page_index, items) =>
            let
                response = Thinkific.Raw(endpoint & "?limit=250&page=" & Number.ToText(page_index)),
                acc_items = List.Combine({items, response[items]}),
                pagination = response[meta][pagination]
            in
                if pagination[current_page] < pagination[total_pages] then @getPages(endpoint, pagination[next_page], acc_items) else acc_items
    in
        getPages(url, 1, {});

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

SampleTable = ( OutputTable as table) as text =>

let
    TableToTransform = Table.FirstN(OutputTable,2),        
    Headers = Text.Combine(List.Transform(Table.ColumnNames(TableToTransform), each """"""&Text.From(_)&""""""), ","),
    Data = Text.Combine(List.Transform(List.Transform(Table.ToRows(TableToTransform), each Text.Combine(List.Transform(_, (_)=> """"""&Text.From(_)&""""""), ",")), each "{"&_&"}"), ","),
    TableFormat = "#table({"&Headers&"},{"&Data&"})"
in
    TableFormat;
