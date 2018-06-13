
// Use this file to write queries to test your data connector
let
    accounts = FacebookAds.Ads(),
//    tables = accounts{[Name="Miild annoncer"]},
//    tables = accounts{[Name="Michael Frost Billing"]},
//    tables = accounts{[Name="Columban Mission"]},


    tables = accounts{[Name="Jesper Ellegaard"]},
    jeAll = tables[Data]{[Key="Facebook All Ad Insights"]}[Data],
    je30 = tables[Data]{[Key="Facebook All Ad Insights Last 30 days"]}[Data],
    je90 = tables[Data]{[Key="Facebook All Ad Insights Last 90 days"]}[Data]



//    #"Facebook All Ad Insights" = tables[Data]{[Key="Facebook All Ad Insights"]}[Data]
//    #"Facebook All Ad Insights" = tables[Data]{[Key="Facebook All Ad Insights Last 30 days"]}[Data]
//    #"Facebook Ad Actions" = tables[Data]{[Key="Facebook All Ad Insights Last 90 days"]}[Data]
//    #"Facebook Ad Action Values" = tables[Data]{[Key="Facebook Ad Action Values"]}[Data]

//    #"Facebook All Ad Insights" = tables[Data]{[Key="Facebook All Ad Insights"]}[Data]
in
    jeAll
//    #"Facebook Ad Actions"
//    #"Facebook Ad Action Values"
//    accounts