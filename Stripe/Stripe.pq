section StripePlus;

windowWidth = 1200;
windowHeight = 1000;

// Data Source Kind description
StripePlus = [
    Authentication = [
        UsernamePassword = [
            UsernameLabel="Enter Stripe API key"
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
StripePlus.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/mbilling/pbiconnectors",
    SourceImage = StripePlus.Icons,
    SourceTypeImage = StripePlus.Icons
];

StripePlus.Icons = [
    Icon16 = { Extension.Contents("Stripe16.png"), Extension.Contents("Stripe20.png"), Extension.Contents("Stripe24.png"), Extension.Contents("Stripe32.png") },
    Icon32 = { Extension.Contents("Stripe32.png"), Extension.Contents("Stripe40.png"), Extension.Contents("Stripe48.png"), Extension.Contents("Stripe64.png") }
];

///////////////////////////////////////////////////////////////////////////////////////////////////
//                                      CONNECTOR METADATA
///////////////////////////////////////////////////////////////////////////////////////////////////
[DataSource.Kind="StripePlus", Publish="StripePlus.Publish"]
shared StripePlus.Navigation = Value.ReplaceType(Navigation, NavigationType);

NavigationType = type function () as table meta [                  
        Documentation.Name = "Stripe",
        Documentation.LongDescription = "Accesses all objects available through the Stripe API.",
        Documentation.Examples = {[
            Description = "",
            Code = "",
            Result = ""
        ]}
    ];

 Navigation = () =>
    let
        objects = #table(
            {"Name",                "Key",                      "Data",                     "ItemKind", "ItemName", "IsLeaf"},
            {
                {"Core Resources",  "NavTableCoreResources",    NavTableCoreResources(),    "Folder",   "Folder",   false},
                {"Subscriptions",   "NavTableSubscriptions",    NavTableSubscriptions(),    "Folder",   "Folder",   false},
                {"Orders",          "NavTableOrders",           NavTableOrders(),           "Folder",   "Folder",   false}
            }),
            NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf") 
    in
        NavTable;

NavTableCoreResources = () as table => 
    let
        objects = #table(
            {
                "Name",             "Key",                          "Data",                         "ItemKind", "ItemName", "IsLeaf"},{
                {"Balance History", "StripePlus.BalanceHistory",    StripePlus.BalanceHistory(),    "Table",    "Table",    true},
                {"Charges",         "StripePlus.Charges",           StripePlus.Charges(),           "Table",    "Table",    true},
                {"Customers",       "StripePlus.Customers",         StripePlus.Customers(),         "Table",    "Table",    true},
                {"Disputes",        "StripePlus.Disputes",          StripePlus.Disputes(),          "Table",    "Table",    true},
                {"Events",          "StripePlus.Events",            StripePlus.Events(),            "Table",    "Table",    true},
                {"Payouts",         "StripePlus.Payouts",           StripePlus.Payouts(),           "Table",    "Table",    true},
                {"Products",        "StripePlus.Products",          StripePlus.Products(),          "Table",    "Table",    true},
                {"Refunds",         "StripePlus.Refunds",           StripePlus.Refunds(),           "Table",    "Table",    true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

NavTableSubscriptions = () as table => 
    let
        objects = #table(
            {
                "Name",             "Key",                      "Data",                             "ItemKind", "ItemName", "IsLeaf"},{
                {"Coupons",         "StripePlus.Coupons",       StripePlus.Coupons(),               "Table",    "Table",    true},
                {"Invoices",        "StripePlus.Invoices",      StripePlus.Invoices(),              "Table",    "Table",    true},
                {"InvoiceItems",    "StripePlus.InvoiceItems",  StripePlus.InvoiceItems(),          "Table",    "Table",    true},
                {"Products",        "StripePlus.Products",      StripePlus.Products(),              "Table",    "Table",    true},
                {"Plans",           "StripePlus.Plans",         StripePlus.Plans(),                 "Table",    "Table",    true},
                {"Subscriptions",   "StripePlus.Subscriptions", StripePlus.Subscriptions(),         "Table",    "Table",    true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

NavTableOrders = () as table => 
    let
        objects = #table(
            {"Name",  "Key",   "Data",  "ItemKind", "ItemName", "IsLeaf"},{
                {"Orders",      "StripePlus.Orders",    StripePlus.Orders(),    "Table", "Table", true},
                {"Returns",     "StripePlus.Returns",   StripePlus.Returns(),   "Table", "Table", true},
                {"SKUs",        "StripePlus.SKUs",      StripePlus.SKUs(),      "Table", "Table", true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

///////////////////////////////////////////////////////////////////////////////////////////////////
//                                      STRIPE CORE RESOURCES API
///////////////////////////////////////////////////////////////////////////////////////////////////
[DataSource.Kind="StripePlus"]
shared StripePlus.BalanceHistory = () =>
    let
        columns = {"id", "object", "amount", "available_on", "created", "currency", "description", "exchange_rate", "fee", "fee_details", "net", "source", "status", "type"},
        url = "https://api.stripe.com/v1/balance/history?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{ "amount", type number}, {"created", type number}, {"exchange_rate", type number}, {"fee", type number}, {"net", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created"),
                createdAvailableOn = ConvertUnixToDateTime(createdConverted, "available_on")

            in 
                createdAvailableOn
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Charges = () =>
    let
        columns = {"id", "object", "amount", "amount_refunded", "application", "application_fee", "balance_transaction", "captured", "created", "currency", "customer", "description", "destination", "dispute", "failure_code", "failure_message", "fraud_details", "invoice", "livemode", "metadata", "on_behalf_of", "order", "outcome", "paid", "receipt_email", "receipt_number", "refunded", "refunds", "review", "shipping", "source", "source_transfer", "statement_descriptor", "status", "transfer", "transfer_group"},
        url = "https://api.stripe.com/v1/charges?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{ "amount", type number}, {"amount_refunded", type number}, {"captured", type logical}, {"created", type number}, {"livemode", type logical}, {"paid", type logical}, {"refunded", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Customers = () =>
    let
        columns = {"id", "object", "account_balance", "created", "currency", "default_source", "delinquent", "description", "discount", "email", "livemode", "metadata", "shipping", "sources", "subscriptions"},
        url = "https://api.stripe.com/v1/customers?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{ "account_balance", type number}, {"created", type number}, {"delinquent", type logical}, {"livemode", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Disputes = () =>
    let
        columns = {"id", "object", "amount", "balance_transactions", "charge", "created", "currency", "evidence", "evidence_details", "is_charge_refundable", "livemode", "metadata", "reason", "status"},
        url = "https://api.stripe.com/v1/disputes?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{ "amount", type number}, {"created", type number}, {"is_charge_refundable", type logical}, {"livemode", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Events = () =>
    let
        columns = {"id", "object", "api_version", "created", "data", "livemode", "pending_webhooks", "request", "type"},
        url = "https://api.stripe.com/v1/events?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"created", type number}, {"pending_webhooks", type number}, {"livemode", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Payouts = () =>
    let
        columns = {"id", "object", "amount", "arrival_date", "automatic", "balance_transaction", "created", "currency", "description", "destination", "failure_balance_transaction", "failure_code", "failure_message", "livemode", "metadata", "method", "source_type", "statement_descriptor", "status", "type"},
        url = "https://api.stripe.com/v1/payouts?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                arrivalDateConverted = ConvertUnixToDateTime(removedObject, "arrival_date"),
                createdConverted = ConvertUnixToDateTime(arrivalDateConverted, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Refunds = () =>
    let
        columns = {"id", "object", "amount", "balance_transaction", "charge", "created", "currency", "failure_balance_transaction", "failure_reason", "metadata", "reason", "receipt_number", "status"},
        url = "https://api.stripe.com/v1/refunds?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount", type number}, {"created", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;

///////////////////////////////////////////////////////////////////////////////////////////////////
//                                      STRIPE SUBSCRIPTIONS API
///////////////////////////////////////////////////////////////////////////////////////////////////
[DataSource.Kind="StripePlus"]
shared StripePlus.Coupons = () =>
    let
        columns = {"id", "object", "amount_off", "created", "charge", "currency", "duration", "duration_in_months", "livemode", "max_redemptions", "metadata", "percent_off", "redeem_by", "times_redeemed", "valid"},
        url = "https://api.stripe.com/v1/coupons?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),
                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount_off", type number}, {"created", type number}, {"duration_in_months", type number}, {"livemode", type logical}, {"max_redemptions", type number}, {"percent_off", type number}, {"redeem_by", type number}, {"times_redeemed", type number}, {"valid", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created"),
                redeemByConverted = ConvertUnixToDateTime(createdConverted, "redeem_by")
            in 
                redeemByConverted
        else 
            #table(columns, {})
    in
        table;

[DataSource.Kind="StripePlus"]
shared StripePlus.Invoices = () =>
    let
        columns = {"id", "object", "amount_due", "application_fee", "attempt_count", "attempted", "billing", "charge", "closed", "customer", "date", "description", "discount", "due_date", "ending_balance", "forgiven", "lines", "livemode", "metadata", "next_payment_attempt", "number", "paid", "period_end", "period_start", "receipt_number", "starting_balance", "statement_descriptor", "subscription", "subscription_proration_date", "subtotal", "tax", "tax_percent", "total", "webhooks_delivered_at"},
        url = "https://api.stripe.com/v1/invoices?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),
                expandDiscount = Table.ExpandRecordColumn(removedObject, "discount", {"coupon"}, {"discount.coupon"}),
                table = Table.ExpandRecordColumn(expandDiscount, "discount.coupon", {"id"}, {"discount.coupon.id"}),

                tableTyped = Table.TransformColumnTypes(table, {{"amount_due", type number}, {"application_fee", type number}, {"attempt_count", type number}, {"attempted", type logical}, {"closed", type logical}, {"date", type number}, {"due_date", type number}, {"ending_balance", type number}, {"forgiven", type logical}, {"livemode", type logical}, {"next_payment_attempt", type number}, {"paid", type logical}, {"period_end", type number}, {"period_start", type number}, {"starting_balance", type number}, {"subscription_proration_date", type number}, {"subtotal", type number}, {"tax_percent", type number}, {"total", type number}, {"webhooks_delivered_at", type number}}),
                dateConverted = ConvertUnixToDateTime(tableTyped, "date"),
                dueDateConverted = ConvertUnixToDateTime(dateConverted, "due_date"),
                nextPaymentAttemptConverted = ConvertUnixToDateTime(dueDateConverted, "next_payment_attempt"),
                periodEndConverted = ConvertUnixToDateTime(nextPaymentAttemptConverted, "period_end"),
                periodStartConverted = ConvertUnixToDateTime(periodEndConverted, "period_start"),
                webhooksDeliveredAtConverted = ConvertUnixToDateTime(periodStartConverted, "period_start"),
                subscriptionProrationDateConverted = ConvertUnixToDateTime(webhooksDeliveredAtConverted, "subscription_proration_date")
            in 
                subscriptionProrationDateConverted
        else 
            #table(columns, {})
    in
        table;

[DataSource.Kind="StripePlus"]
shared StripePlus.InvoiceItems = () =>
    let
        columns = {"id", "object", "amount", "currency", "customer", "date", "description", "discountable", "invoice", "livemode", "metadata", "period", "plan", "proration", "quantity", "subscription", "subscription_item"},
        url = "https://api.stripe.com/v1/invoiceitems?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),
                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount", type number}, {"date", type number}, {"discountable", type logical}, {"livemode", type logical}, {"proration", type logical}, {"quantity", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "date")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Products = () =>
    let
        columns = {"id", "object", "active", "attributes", "caption", "created", "deactivate_on", "description", "images", "livemode", "metadata", "name", "package_dimensions", "shippable", "skus", "statement_descriptor", "type", "unit_label", "updated", "url"},
        url = "https://api.stripe.com/v1/products?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),
                tableTyped = Table.TransformColumnTypes(removedObject, {{"created", type number}, {"active", type logical}, {"livemode", type logical}, {"shippable", type logical}, {"updated", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created"),
                updatedConverted = ConvertUnixToDateTime(createdConverted, "updated")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Plans = () =>
    let
        columns = {"id", "object", "amount", "created", "currency", "interval", "interval_count", "livemode", "metadata"},
        url = "https://api.stripe.com/v1/plans?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),
                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount", type number}, {"created", type number}, {"interval_count", type number}, {"livemode", type logical}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created")
            in 
                createdConverted
        else 
            #table(columns, {})
    in
        table;

[DataSource.Kind="StripePlus"]
shared StripePlus.Subscriptions = () =>
    let
        columns = {"id", "object", "application_fee_percent", "billing", "cancel_at_period_end", "canceled_at", "created", "current_period_end", "current_period_start", "customer", "days_until_due", "discount", "ended_at", "items", "livemode", "metadata", "plan", "quantity", "start", "status", "tax_percent", "trial_end", "trial_start"},
        url = "https://api.stripe.com/v1/subscriptions?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"application_fee_percent", type number}, {"cancel_at_period_end", type logical}, {"canceled_at", type number}, {"created", type number}, {"current_period_end", type number}, {"current_period_start", type number}, {"days_until_due", type number}, {"ended_at", type number}, {"livemode", type logical}, {"quantity", type number}, {"start", type number}, {"tax_percent", type number}, {"trial_end", type number}, {"trial_start", type number}}),
                canceledAtConverted = ConvertUnixToDateTime(tableTyped, "canceled_at"),
                createdConverted = ConvertUnixToDateTime(canceledAtConverted, "created"),
                currentPeriodEndConverted = ConvertUnixToDateTime(createdConverted, "current_period_end"),
                currentPeriodStartConverted = ConvertUnixToDateTime(currentPeriodEndConverted, "current_period_start"),
                endedAtConverted = ConvertUnixToDateTime(currentPeriodStartConverted, "ended_at"),
                startConverted = ConvertUnixToDateTime(endedAtConverted, "start"),
                trialEndConverted = ConvertUnixToDateTime(startConverted, "trial_end"),
                trialStartConverted = ConvertUnixToDateTime(trialEndConverted, "trial_start")
            in 
                trialStartConverted
        else 
            #table(columns, {})
    in
        table;


///////////////////////////////////////////////////////////////////////////////////////////////////
//                                      STRIPE ORDERS API
///////////////////////////////////////////////////////////////////////////////////////////////////
[DataSource.Kind="StripePlus"]
shared StripePlus.Orders = () =>
    let
        columns = {"id", "object", "amount", "amount_returned", "application", "application_fee", "charge", "created", "currency", "customer", "email", "external_coupon_code", "items", "livemode", "metadata", "returns", "selected_shipping_method", "shipping", "shipping_methods", "status", "status_transitions", "updated", "upstream_id"},
        url = "https://api.stripe.com/v1/orders?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let 
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount", type number}, {"amount_returned", type number}, {"application_fee", type number}, {"created", type number}, {"livemode", type logical}, {"updated", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created"),
                updatedConverted = ConvertUnixToDateTime(createdConverted, "updated")
            in 
                updatedConverted
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.Returns = () =>
    let
        columns = {"id", "object", "amount", "created", "currency", "items", "livemode", "order", "refund"},
        url = "https://api.stripe.com/v1/order_returns?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"amount", type number}, {"created", type number}, {"livemode", type logical}})
            in 
                tableTyped
        else 
            #table(columns, {})
    in
        table;


[DataSource.Kind="StripePlus"]
shared StripePlus.SKUs = () =>
    let
        columns = {"id", "object", "active", "attributes", "created", "currency", "image", "inventory","livemode","metadata","package_dimensions","price","product","updated"},
        url = "https://api.stripe.com/v1/skus?limit=100",
        tableOrEmpty = GetPagedData(url),

        table = if not Table.IsEmpty(tableOrEmpty) then 
            let
                expandRecords = Table.ExpandRecordColumn(tableOrEmpty, "Column1", columns),
                removedObject = Table.RemoveColumns(expandRecords,{"object"}),

                tableTyped = Table.TransformColumnTypes(removedObject, {{"active", type logical}, {"created", type number}, {"livemode", type logical},{"price", type number},{"updated", type number}}),
                createdConverted = ConvertUnixToDateTime(tableTyped, "created"),
                updatedConverted = ConvertUnixToDateTime(createdConverted, "updated")
            in 
                updatedConverted
        else 
            #table(columns, {})
    in
        table;


///////////////////////////////////////////////////////////////////////////////////////////////////
//                                      DATA TOOLS
///////////////////////////////////////////////////////////////////////////////////////////////////
_GetPagedData = (url) =>
    let
        seedResult = Json.Document(Web.Contents(url)),
        seedHasMore = seedResult[has_more],
        seedLastId = List.Last(seedResult[data])[id],

        joined_response = if seedHasMore
            then 
                List.Generate(
                    ()=> [result = seedResult, query = url, has_more = seedHasMore, lastId = seedLastId], 
                    each [has_more], 
                    each [
                        query = url & "&" & Uri.BuildQueryString([starting_after=lastId]),
                        result = Json.Document(Web.Contents([query])),
                        lastId = List.Last(result[data])[id],
                        has_more = result[has_more]
                    ], 
                    each [result]
                ) 
            else
                {seedResult},

        table = Table.FromList(joined_response, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    in
        table;

GetPagedData = (url) =>
    let
        seedResult = Json.Document(Web.Contents(url)),
        seedHasMore = seedResult[has_more],
        seedLastId = List.Last(seedResult[data])[id],

        getPages = (query, result) =>
            let
                response = Json.Document(Web.Contents(query)),
                newResult = List.Combine({result, response[data]}),
                nextQuery = if response[has_more] then url & "&" & Uri.BuildQueryString([starting_after=List.Last(response[data])[id]]) else  null
            in
                if nextQuery <> null then @getPages(nextQuery, newResult) else newResult,

        joined_pages = getPages(url, {}),

        table = Table.FromList(joined_pages, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    in
        table;


ConvertUnixToDateTime = (TableTyped as table, unixColumn as text) => 
    let 
        AddCreatedAsDateTime = Table.AddColumn(TableTyped, "temp_1", each try #datetime(1970, 1, 1, 0, 0, 0) + #duration(0, 0, 0, Record.Field(_, unixColumn)) otherwise null),
        Typed = Table.TransformColumnTypes(AddCreatedAsDateTime,{{"temp_1", type datetime}}),
        RemovedOriginal = Table.RemoveColumns(Typed,{unixColumn}),
        Converted = Table.RenameColumns(RemovedOriginal,{{"temp_1", unixColumn}})
    in
        Converted;

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
