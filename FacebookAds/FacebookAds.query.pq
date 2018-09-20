
// Use this file to write queries to test your data connector
let
    accounts = FacebookAds.Ads(),
//    tables = accounts{[Name="Miild annoncer"]},
//    tables = accounts{[Name="Jesper Ellegaard"]},
//    tables = accounts{[Name="Michael Frost Billing"]},
    tables = accounts{[Name="1375481632694420"]},       // Columban Mission

//    r = tables[Data]{[Key="Facebook Active Ad Insights"]}[Data]
//    r = tables[Data]{[Key="Facebook Active Ad Insights Last 30 days"]}[Data]
//    r = tables[Data]{[Key="Facebook Active Ad Insights Last 90 days"]}[Data]

//    r = tables[Data]{[Key="Facebook All Ad Insights"]}[Data]
//    r = tables[Data]{[Key="Facebook All Ad Insights Last 30 days"]}[Data]
//    r = tables[Data]{[Key="Facebook All Ad Insights Last 90 days"]}[Data]

//     r = tables[Data]{[Key="Facebook Ad Actions"]}[Data]
//     r = tables[Data]{[Key="Facebook Ad Actions Last 30 days"]}[Data]
//     r = tables[Data]{[Key="Facebook Ad Actions Last 90 days"]}[Data]

//     r = tables[Data]{[Key="Facebook All Ad Insights Last 30 days"]}[Data]
     r = tables[Data]{[Key="Facebook Ad Action Values Last 30 days"]}[Data]
//     r = tables[Data]{[Key="Facebook Ad Actions Last 30 days"]}[Data]

//    r = tables[Data]{[Key="Facebook Ad Action Values"]}[Data]
//    r = tables[Data]{[Key="Facebook Ad Action Values Last 30 days"]}[Data]
//    r = tables[Data]{[Key="Facebook Ad Action Values Last 90 days"]}[Data]

in
   r
//   Table.RowCount(r)

//    #"Facebook Ad Actions"
//    #"Facebook Ad Action Values"
//    accounts