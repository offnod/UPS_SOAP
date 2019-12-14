USE [database]
GO

/****** Object:  StoredProcedure [dbo].[Update_Tracking]    Script Date: 2018 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[Update_Tracking] as

SET NOCOUNT ON;

--DECLARE VARIABLES FOR spHTTPRequest
DECLARE @xmlOut xml
DECLARE @xmloutnvarchar varchar(8000)
DECLARE @RequestText as varchar(1000)

--DECLARE THE VARIABLES FOR HOLDING DATA.
DECLARE @id int, @tracking_number nvarchar(80),@tracking_return nvarchar(80),@xmlresponse xml
	,@origindate datetime,@origincity nvarchar(250) ,@originstate nvarchar(2),@originpostalcode nvarchar(15) ,@origincountry nvarchar(5)
	,@statusdate datetime ,@status nvarchar(250) ,@statuscity nvarchar(250) ,@statusstate nvarchar(2) ,@statuscountry nvarchar(5)
	,@destcity nvarchar(250) ,@deststate nvarchar(2) ,@destpostalcode nvarchar(15) ,@destcountry nvarchar(5)
	,@estdeliverydate datetime ,@signedforbyname nvarchar(50) ,@delivered int

--DECLARE THE CURSOR FOR A QUERY.
DECLARE UpdateTracking CURSOR READ_ONLY
FOR
SELECT id, tracking_number ,tracking_return ,xmlresponse 
	,Origindate ,origincity ,originstate ,originpostalcode ,origincountry
	,statusdate ,[status] ,statuscity ,statusstate ,statuscountry
	,destcity ,deststate ,destpostalcode ,destcountry
	,estdeliverydate ,signedforbyname ,delivered
FROM shipment_tracking

--OPEN cursor
OPEN updatetracking

--FETCH next record
FETCH NEXT FROM updatetracking INTO
	@id ,@tracking_number ,@tracking_return ,@xmlresponse 
	,@origindate ,@origincity ,@originstate ,@originpostalcode ,@origincountry
	,@statusdate ,@status ,@statuscity ,@statusstate ,@statuscountry
	,@destcity ,@deststate ,@destpostalcode ,@destcountry
	,@estdeliverydate ,@signedforbyname ,@delivered


--LOOP UNTIL RECORDS ARE AVAILABLE.
WHILE @@FETCH_STATUS = 0
BEGIN
			SET @RequestText=
			'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
				xmlns:v1="http://www.ups.com/XMLSchema/XOLTWS/UPSS/v1.0"
				xmlns:v3="http://www.ups.com/XMLSchema/XOLTWS/Track/v2.0"
				xmlns:v11="http://www.ups.com/XMLSchema/XOLTWS/Common/v1.0">
				<soapenv:Header>
					<v1:UPSSecurity>
						<v1:UsernameToken>
							<v1:Username>username</v1:Username>
							<v1:Password>password</v1:Password>
						</v1:UsernameToken>
						<v1:ServiceAccessToken>
							<v1:AccessLicenseNumber>license</v1:AccessLicenseNumber>
						</v1:ServiceAccessToken>
					</v1:UPSSecurity>
				</soapenv:Header>
				<soapenv:Body>
					<v3:TrackRequest>
						<v3:TrackingOption>02</v3:TrackingOption>
						<v11:Request>
							<v11:RequestOption>0</v11:RequestOption>
						</v11:Request>
						<v3:InquiryNumber>'+
							CASE WHEN @delivered = 1 
								THEN @tracking_return
								ELSE @tracking_number
								END 						
						+'</v3:InquiryNumber>
					</v3:TrackRequest>
				</soapenv:Body>
			</soapenv:Envelope>'

			EXEC spHTTPRequest 
			'https://onlinetools.ups.com/webservices/Track', 
			'POST', 
			@RequestText,
			'track',
			‘username’,
			‘password’,
			@xmloutnvarchar out

			SET @xmlout = @xmloutnvarchar
	IF (len(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()'))) > 0 AND convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()')) != right(isnull((SELECT S.[status] FROM shipment_tracking S WHERE S.id = @id),'') ,len(isnull((SELECT S.[status] FROM shipment_tracking S WHERE S.id = @id),'______'))-6))
	BEGIN	
			UPDATE S SET [status] = 'Error '+convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()')) ,xmlresponse = @xmlout
			FROM shipment_tracking S
			WHERE S.id = @id
	END
	ELSE IF (len(convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()'))) > 0 AND convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) != isnull((SELECT S.[status] FROM shipment_tracking S WHERE S.id = @id),''))
	BEGIN
			UPDATE S SET xmlresponse = @xmlout
			FROM shipment_tracking S
			WHERE S.id = @id
			IF (convert(nvarchar (2) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Response/*:ResponseStatus/*:Code/text()')) = '1')
			BEGIN
				UPDATE S SET
				[OriginDate] = CASE WHEN convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:PickupDate/text()')) != ''
									THEN convert(datetime ,
									left(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:PickupDate/text()')) ,4) +'-'
									+right(left(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:PickupDate/text()')) ,6) ,2) +'-'
									+right(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:PickupDate/text()')) ,2)
									+' 00:00:00.000'
									)
									ELSE @origindate
									END
				,[OriginCity] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut)) != 0
									THEN substring(convert(nvarchar(4000) ,@xmlOut) 
									,charindex('<trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:City>')
									,charindex('</trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:City>') - charindex('<trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))))
									ELSE @origincity
									END
				,[OriginState] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut)) != 0
									THEN substring(convert(nvarchar(4000) ,@xmlOut) 
									,charindex('<trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:StateProvinceCode>')
									,charindex('</trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:StateProvinceCode>') - charindex('<trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))))
									ELSE @originstate
									END
				,[OriginPostalCode] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut)) != 0
										THEN substring(convert(nvarchar(4000) ,@xmlOut) 
										,charindex('<trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:PostalCode>')
										,charindex('</trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:PostalCode>') - charindex('<trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))))
										ELSE @originpostalcode
										END
				,[OriginCountry] =	CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut)) != 0
										THEN substring(convert(nvarchar(4000) ,@xmlOut) 
										,charindex('<trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:CountryCode>')
										,charindex('</trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:CountryCode>') - charindex('<trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>01' ,convert(nvarchar(4000) ,@xmlOut))))
										ELSE @origincountry
										END
			/*	,charindex('<trk:Description>' ,@xmlOut ,charindex('<trk:status>' ,@xmlout))
				,charindex('</trk:Description>' ,@xmlOut ,charindex('<trk:status>' ,@xmlout))
				,charindex('<trk:status>' ,@xmlout)*/
				,[StatusDate] = CASE WHEN convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) != ''
								THEN convert(datetime ,left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,4) +'-'
								+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,6) ,2) +'-'
								+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,2) +' '
								+left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +':'
								+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,4) ,2) +':'
								+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +'.000'
								)
								ELSE ''
								END
				,[Status] = convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()'))
				,[StatusCity] = convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:ActivityLocation/*:Address/*:City/text()'))
				,[StatusState] = convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:ActivityLocation/*:Address/*:StateProvinceCode/text()'))
	   		/*	,substring(@xmlout 
					,charindex('<trk:PostalCode>' ,@xmlOut ,charindex('<trk:ActivityLocation>' ,@xmlout)) + len('<trk:PostalCode>')
					,charindex('</trk:PostalCode>' ,@xmlOut ,charindex('<trk:ActivityLocation>' ,@xmlout)) - len('<trk:PostalCode>') - charindex('<trk:PostalCode>' ,@xmlOut ,charindex('<trk:ActivityLocation>' ,@xmlout)))
					as [StatusPostalCode]
			*/	,[StatusCountry] = convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:ActivityLocation/*:Address/*:CountryCode/text()'))
			/*	,charindex('<trk:Description>' ,@xmlOut ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,@xmlout))
				,charindex('</trk:Description>' ,@xmlOut ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,@xmlout))
				,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,@xmlout)*/
				
				,[DestCity] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut)) != 0
									THEN substring(convert(nvarchar(4000) ,@xmlOut) 
									,charindex('<trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:City>')
									,charindex('</trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:City>') - charindex('<trk:City>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))))
									ELSE @destcity
									END
				,[DestState] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut)) != 0 AND charindex('<trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) != 0
								THEN substring(convert(nvarchar(4000) ,@xmlOut) 
								,charindex('<trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:StateProvinceCode>')
								,charindex('</trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:StateProvinceCode>') - charindex('<trk:StateProvinceCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))))
								ELSE @deststate
								END
				,[DestPostalCode] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut)) != 0
										THEN substring(convert(nvarchar(4000) ,@xmlOut) 
										,charindex('<trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:PostalCode>')
										,charindex('</trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:PostalCode>') - charindex('<trk:PostalCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))))
 										ELSE @destpostalcode
										END
				,[DestCountry] = CASE WHEN charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut)) != 0
									THEN substring(convert(nvarchar(4000) ,@xmlOut) 
									,charindex('<trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) + len('<trk:CountryCode>')
									,charindex('</trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))) - len('<trk:CountryCode>') - charindex('<trk:CountryCode>' ,convert(nvarchar(4000) ,@xmlOut) ,charindex('<trk:ShipmentAddress><trk:Type><trk:Code>02' ,convert(nvarchar(4000) ,@xmlOut))))
 									ELSE @destcountry
									END
				,[EstDeliveryDate] = CASE WHEN convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:DeliveryDetail/*:Date/text()')) != ''
										THEN convert(datetime ,
										left(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:DeliveryDetail/*:Date/text()')) ,4) +'-'
										+right(left(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:DeliveryDetail/*:Date/text()')) ,6) ,2) +'-'
										+right(convert(nvarchar (100),@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:DeliveryDetail/*:Date/text()')) ,2)+' '
										+'00:00:00.000'
										)
										ELSE @estdeliverydate
										END
				,signedforbyname = convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:ActivityLocation/*:SignedForByName/text()'))
				,delivered = CASE WHEN convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Delivered'
										AND (SELECT S.delivered FROM shipment_tracking S WHERE S.id = @id) = 0
								THEN 1
								WHEN convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Delivered'
										AND (SELECT S.delivered FROM shipment_tracking S WHERE S.id = @id) = 1
										AND	replace( isnull ((SELECT S.tracking_return
															FROM shipment_tracking S
															WHERE S.id = @id)
															,'') ,' ' ,'') != ''
								THEN 2
								ELSE (SELECT S.delivered FROM shipment_tracking S WHERE S.id = @id)
								END
				,delivered1_date = iif( convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Delivered'
										AND (SELECT S.delivered FROM shipment_tracking S WHERE S.id = @id) = 0
									,CASE WHEN convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) != ''
										THEN convert(datetime ,left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,4) +'-'
										+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,6) ,2) +'-'
										+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,2) +' '
										+left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +':'
										+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,4) ,2) +':'
										+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +'.000'
										)
										ELSE 'delivered1 error'
										END
									,(SELECT S.delivered1_date FROM shipment_tracking S WHERE S.id = @id))
				,delivered2_date = iif( convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Delivered'
										AND (SELECT S.delivered FROM shipment_tracking S WHERE S.id = @id) = 1
										AND	replace( isnull ((SELECT S.tracking_return
															FROM shipment_tracking S
															WHERE S.id = @id)
															,'') ,' ' ,'') != ''
									,CASE WHEN convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) != ''
										THEN convert(datetime ,left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,4) +'-'
										+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,6) ,2) +'-'
										+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Date/text()')) ,2) +' '
										+left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +':'
										+right(left(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,4) ,2) +':'
										+right(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Time/text()')) ,2) +'.000'
										)
										ELSE 'delivered2 error'
										END
									,(SELECT S.delivered2_date FROM shipment_tracking S WHERE S.id = @id))
				FROM shipment_tracking S
				WHERE S.id = @id

				IF (convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Order Processed: Ready for UPS'
					OR convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) like '%scan')
					BEGIN			
						UPDATE C SET email_progress = 10
						FROM inventory C
						JOIN shipment_tracking S
							ON S.id = C.trackingid
				--		JOIN qry_shipment_tracking_10 SH10
				--			ON SH10.id = C.id
						WHERE S.id = @id
							AND C.email_progress not in (10,20,30)
					END
				ELSE IF (convert(nvarchar (250) ,@xmlout.query('/*:Envelope/*:Body/*:TrackResponse/*:Shipment/*:Package/*:Activity/*:Status/*:Description/text()')) = 'Delivered')
					BEGIN
						INSERT INTO history(asset_id ,delivered)
						SELECT C.id ,S.delivered1_date
						FROM inventory C
						JOIN shipment_tracking S
							ON S.id = C.trackingid
				--		JOIN qry_shipment_tracking_20 SH20
				--			ON SH20.id = C.id
						WHERE S.id = @id
/*
						UPDATE C SET email_progress = 20
						FROM inventory C
						JOIN shipment_tracking S
							ON S.id = C.trackingid
						JOIN qry_shipment_tracking_20 SH20
							ON SH20.id = C.id
						WHERE S.id = @id
*/
					END
			END
			ELSE
			BEGIN
				UPDATE S SET [status] = 'ErrorOut'
				FROM shipment_tracking S
				WHERE S.id = @id
			END
	END
	--FETCH NEXT RECORD INTO VARIABLES
	FETCH NEXT FROM updatetracking INTO
		@id , @tracking_number ,@tracking_return ,@xmlresponse 
		,@origindate ,@origincity ,@originstate ,@originpostalcode ,@origincountry
		,@statusdate ,@status ,@statuscity ,@statusstate ,@statuscountry
		,@destcity ,@deststate ,@destpostalcode ,@destcountry
		,@estdeliverydate ,@signedforbyname ,@delivered
END
CLOSE updatetracking
DEALLOCATE updatetracking
GO


