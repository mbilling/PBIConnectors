
// Use this file to write queries to test your data connector
let
    accounts = FacebookAds.Ads(),
    tables = accounts{[Name="Miild annoncer"]},
    #"Facebook Ad Actions" = tables[Data]{[Key="Facebook Ad Actions"]}[Data]
//    #"Facebook Ad Action Values" = tables[Data]{[Key="Facebook Ad Action Values"]}[Data]

//    #"Facebook All Ad Insights" = tables[Data]{[Key="Facebook All Ad Insights"]}[Data]
in
//    #"Facebook All Ad Insights"
    #"Facebook Ad Actions"
//    #"Facebook Ad Action Values"