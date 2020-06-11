// This file contains your Data Connector logic
section GoLearn;

// Data Source Kind description
GoLearn = [
 TestConnection = (dataSourcePath) => { "GoLearn.Navigation" },
    Authentication = [
        Key = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
GoLearn.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = GoLearn.Icons,
    SourceTypeImage = GoLearn.Icons
];

GoLearn.Icons = [
    Icon16 = { Extension.Contents("GoLearn16.png"), Extension.Contents("GoLearn20.png"), Extension.Contents("GoLearn24.png"), Extension.Contents("GoLearn32.png") },
    Icon32 = { Extension.Contents("GoLearn32.png"), Extension.Contents("GoLearn40.png"), Extension.Contents("GoLearn48.png"), Extension.Contents("GoLearn64.png") }
];

[DataSource.Kind="GoLearn", Publish="GoLearn.Publish"]
shared GoLearn.Navigation = Value.ReplaceType(Navigation, NavigationType);

NavigationType = type function () as table meta [                  
        Documentation.Name = "GoLearn",
        Documentation.LongDescription = "Accesses all objects available through the GoLearn API.",
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
                {"Bundles", "GoLearn.Bundles", GoLearn.Bundles(), "Table", "Table", true},
                {"Users", "GoLearn.Users", GoLearn.Users(), "Table", "Table", true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

[DataSource.Kind="GoLearn"]
shared GoLearn.Bundles = () =>
    let
        url = "https://www.golearn.dk/?webhook_golearn_pmpro_bundes=getall",
        items = GoLearn.Raw(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"ID", "name", "thinkific_bundle_id", "pmpro_level_id"}, {"ID", "name", "thinkific_bundle_id", "pmpro_level_id"})
    in
        expanded;

[DataSource.Kind="GoLearn"]
shared GoLearn.Users = () =>
    let
        url = "https://www.golearn.dk/?webhook_golearn_pmpro_bundes=usersandbundles",
        items = GoLearn.Raw(url),
        table = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        expanded = Table.ExpandRecordColumn(table, "Column1", {"ID", "name", "thinkific_bundle_id", "pmpro_level_id"}, {"ID", "name", "thinkific_bundle_id", "pmpro_level_id"})
    in
        items;

GoLearn.Raw = (url) =>
    
    let key = Extension.CurrentCredential()[Key],
        headers = [
            Accept = "application/vnd.api+json",
            #"Content-Type" = "application/json"
        ],
        raw_response = Web.Contents(url & "&token=" & key, [ Headers = headers, ManualCredentials = true ]),
        response = Json.Document(raw_response)
    in
        response;

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
