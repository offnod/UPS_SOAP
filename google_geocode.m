--- M SCRIPT

let
    Source = Sql.Database("Server", "Database"),
    dbo_addresses = Source{[Schema="dbo",Item="addresses"]}[Data],
    #"Added Custom" = Table.AddColumn(dbo_addresses, "coord", each let
	        api = () => Json.Document(Web.Contents("https://maps.googleapis.com/maps/api/geocode/json?address=" & [Addr] & "&key=")),
		source = Function.InvokeAfter(api, #duration(0, 0, 0, 0.2)),
		results1 = source[results],
		results2 = results1{0},
		geometry1 = results2[geometry],
		location1 = geometry1[location],
		convtab = Record.ToTable(location1),

                coord1 = Table.Pivot(convtab ,List.Distinct(convtab[Name]),"Name" ,"Value"),
                coord2 = convtab[Value],
                coord3 = convtab[Name],
                coord = coord3{0}&":"&Text.From(coord2{0})&","&coord3{1}&":"&Text.From(coord2{1})
    in 
       coord),
    #"Split Column by Delimiter" = Table.SplitColumn(#"Added Custom", "coord", Splitter.SplitTextByDelimiter(",", QuoteStyle.Csv), {"coord.1", "coord.2"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Split Column by Delimiter",{{"coord.1", type text}, {"coord.2", type text}})
in
    #"Changed Type"

---------------------------------------------------------

		--https://maps.googleapis.com/maps/api/geocode/json?address=1600+Amphitheatre+Parkway,+Mountain+View,+CA&key=YOUR_API_KEY
		--	
	
		let
			api = () => Json.Document(Web.Contents("https://maps.googleapis.com/maps/api/geocode/json?address=" & [Addr] & "&key=apiKEY")),
			source = Function.InvokeAfter(api, #duration(0, 0, 0, 0.2)),
			results1 = source[results],
			results2 = results1{0},
			geometry1 = results2[geometry],
			location1 = geometry1[location],
			convtab = Record.ToTable(location1),
			coord = Table.Pivot(convtab , List.Distinct(convtab [Name]), "Name", "Value")
		in
			coord	
---------------------------------------------------------
		let
			api = () => Json.Document(Web.Contents("https://maps.googleapis.com/maps/api/geocode/json?address=" & [Addr] & "&key=apiKEY")),
			source1 = Function.InvokeAfter(api, #duration(0, 0, 0, 0.2)),
			results1 = source1[results],
			results2 = results1{0},
			geometry1 = results2[geometry],
			location1 = geometry1[location],
			coord = location1
		in
			coord
---------------------------------------------------------
	let
		api = () => Json.Document(Web.Contents("https://maps.googleapis.com/maps/api/geocode/json?address=" & [Addr] & "&key=apiKEY")),
		source = Function.InvokeAfter(api, #duration(0, 0, 0, 0.2)),
		results1 = source[results],
		results2 = results1{0},
		geometry1 = results2[geometry],
		location1 = geometry1[location],
		coord = location1
	in
		coord
---------------------------------------------------------
let
    Source = Sql.Database(“Server”, “Database”),
    dbo_addresses = Source{[Schema="dbo",Item="addresses"]}[Data]
in
    dbo_addresses
---------------------------------------------------------
let
    convtab = Table.FromRecords(
		    {  
		        [Name = "lat", Value = Text.From("38.8950936802915")],
		        [Name = "lng", Value = Text.From("-77.01308751970849")]  
		    }
	        ),

    coord = Table.Pivot(convtab ,List.Distinct(convtab[Name]),"Name" ,"Value")
    #"Added Custom" = Table.AddColumn(coord, "Custom", each dbo_addresses[Addr]),

in
    coord