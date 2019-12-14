
/*

	set nocount off;

*/

SET NOCOUNT ON;
--DECLARE VARIABLES FOR spHTTPRequest
		DECLARE @xmlOut xml
		DECLARE @xmloutnvarchar as varchar(8000)
		DECLARE @RequestText as varchar(2000)
		set @xmloutnvarchar = ''
		set @RequestText = ''


--DECLARE THE VARIABLES FOR HOLDING DATA.
DECLARE @Aid int ,@xmlresponse xml
	,@address nvarchar(75) ,@state nvarchar(2) ,@city nvarchar(30) ,@postal nvarchar(15) ,@clean bit ,@xmlo xml
	,@countrycode nvarchar(2)
--DECLARE THE CURSOR FOR A QUERY
DECLARE UpdatePostal CURSOR READ_ONLY
FOR
SELECT A.id ,A.[address] ,A.city ,A.[state] ,A.[zip code] ,A.xlmout
FROM [Mizzing_ZIP] A
where [zip code] like 'error%'

--OPEN cursor
OPEN UpdatePostal

--FETCH next record
FETCH NEXT FROM UpdatePostal INTO
	@Aid ,@address ,@city ,@state ,@postal ,@xmlo

IF (@state in  ('AK','AL','AR','AZ','CA','CO','CT','DC','DE','FL','GA','HI','ID','IL','IN'
,'IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY'
,'NC','ND','OH','OK','OR','PA','RI','SC','SD'
,'TN','TX','UT','VT','VA','WA','WV','WI','WY'))
	SET @countrycode = 'US'	
ELSE IF @state is null
	SET @state = ''
ELSE
	SET @countrycode = @state
	SET @state = @city
	SET @city = null

--LOOP UNTIL RECORDS ARE AVAILABLE.
WHILE @@FETCH_STATUS = 0
BEGIN
		set @RequestText =
			'<envr:Envelope 
				xmlns:envr="http://schemas.xmlsoap.org/soap/envelope/"
				xmlns:auth="http://www.ups.com/schema/xpci/1.0/auth"
				xmlns:xsd="http://www.w3.org/2001/XMLSchema"
				xmlns:upss="http://www.ups.com/XMLSchema/XOLTWS/UPSS/v1.0"
				xmlns:common="http://www.ups.com/XMLSchema/XOLTWS/Common/v1.0"
				xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
				<envr:Header>
					<upss:UPSSecurity>
						<upss:UsernameToken>
							<upss:Username>username</upss:Username>
							<upss:Password>password</upss:Password>
						</upss:UsernameToken>
						<upss:ServiceAccessToken>
							<upss:AccessLicenseNumber>license</upss:AccessLicenseNumber>
						</upss:ServiceAccessToken>
					</upss:UPSSecurity>
				</envr:Header>
				<envr:Body>
					<XAV:XAVRequest
						xsi:schemaLocation="http://www.ups.com/XMLSchema/XOLTWS/xav/v1.0"
						xmlns:XAV="http://www.ups.com/XMLSchema/XOLTWS/xav/v1.0">
						<common:Request>
							<common:RequestOption>1</common:RequestOption>
							<common:TransactionReference>
								<common:CustomerContext>Verify</common:CustomerContext>
							</common:TransactionReference>
						</common:Request>
						<XAV:MaximumCandidateListSize>1</XAV:MaximumCandidateListSize>
						<XAV:AddressKeyFormat>
							<XAV:ConsigneeName></XAV:ConsigneeName>
							<XAV:BuildingName></XAV:BuildingName>
							<XAV:AddressLine>'+@address+'</XAV:AddressLine>
							<XAV:PoliticalDivision2>'+@city+'</XAV:PoliticalDivision2>
							<XAV:PoliticalDivision1>'+@state+'</XAV:PoliticalDivision1>
							<XAV:PostcodePrimaryLow></XAV:PostcodePrimaryLow>
							<XAV:CountryCode>'+@countrycode+'</XAV:CountryCode>
						</XAV:AddressKeyFormat>
					</XAV:XAVRequest>
				</envr:Body>
			</envr:Envelope>'


		EXEC spHTTPRequest 
--		'https://wwwcie.ups.com/webservices/XAV',
		'https://onlinetools.ups.com/webservices/XAV', 
		'POST', 
		@RequestText,
		'verify',
		'username',
		'password',
		@xmloutnvarchar out

		set @xmlout = @xmloutnvarchar
		
	--	UPDATE A SET xlmout = @xmlout
	--	FROM [Mizzing_ZIP] A
	--	WHERE A.id = @Aid

		IF (len(convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()'))) > 0)
		BEGIN
			select 'Error'+convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()'))
	--		UPDATE A SET [zip code] = 'Error'+convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:Fault/*:detail/*:Errors/*:ErrorDetail/*:PrimaryErrorCode/*:Code/text()'))
			FROM [Mizzing_ZIP] A
			WHERE A.id = @Aid
		END
		ELSE IF (len(convert(nvarchar (5) ,@xmlout.query('/*:Envelope/*:Body/*:XAVResponse/*:Candidate/*:AddressKeyFormat/*:PostcodePrimaryLow/text()'))) > 0)
		BEGIN
			select convert(nvarchar (5) ,@xmlout.query('/*:Envelope/*:Body/*:XAVResponse/*:Candidate/*:AddressKeyFormat/*:PostcodePrimaryLow/text()'))		
	--		UPDATE A SET [zip code] = convert(nvarchar (100) ,@xmlout.query('/*:Envelope/*:Body/*:XAVResponse/*:Candidate/*:AddressKeyFormat/*:PostcodePrimaryLow/text()'))
			FROM [Mizzing_ZIP] A
			WHERE A.id = @Aid
		END
		ELSE
			SELECT 'Error End'
	--		UPDATE A SET [zip code] = 'Error End'
			FROM [Mizzing_ZIP] A
			WHERE A.id = @Aid
	
	--FETCH next record
	FETCH NEXT FROM UpdatePostal INTO
		@Aid ,@address ,@city ,@state ,@postal ,@xmlo
END


SET NOCOUNT OFF;
CLOSE UpdatePostal;
DEALLOCATE UpdatePostal;
GO
