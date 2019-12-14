# UPS_SOAP
UPS and Google SOAP requests related to delivery and tracking data

API_SOAP
- Requests from UPS API
- Passes SOAP request to spHTTPRequest which is a stored procedure that uses the sp_OAmethod. Well documented elsewhere.
- Meant for tracking both shipping and return numbers.

API_SOAP_addrverify2
- Requests from UPS API
- Visual output to compare potential ZIP codes given address information.

google_geocode
- Requests from Google API
- Returns coordinates in decimal degrees
