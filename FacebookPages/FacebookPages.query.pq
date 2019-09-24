// Use this file to write queries to test your data connector
let
    result = FacebookPages.Contents(),
    data = result{[Key="Miild Beauty"]}[Data]{[Key="last_7d"]}[Data]{[Key = "FB Page Fan Total"]}[Data]
in
    data