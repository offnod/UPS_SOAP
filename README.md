# UPS_SOAP
UPS and Google SOAP requests related to delivery and tracking data

API_SOAP
- Requests from UPS API using T-SQL.
- Passes SOAP request to spHTTPRequest which is a stored procedure that uses the sp_OAmethod. Well documented elsewhere.
- Meant for tracking both shipping and return numbers.
- Integrated with shipment_tracking and inventory tables for automated email notifications.

API_SOAP_addrverify2
- Requests from UPS API using T-SQL.
- Visual output to compare potential ZIP codes given address information.

google_geocode
- Requests from Google API using R.
- Transforms results into two columns of coordinates in decimal degrees.
