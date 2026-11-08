Class Allfedo.Record.Actor Extends %Persistent
{
Property UserName As %String(MAXLEN = 200) [ Required ];
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property DisplayName As %String(MAXLEN = 200) [ Required ];
Property Email As %String(MAXLEN = 320) [ Required ];
Property Role As %String(VALUELIST = ",kitchen,recipient,collector,coordinator") [ Required ];
Property Active As %Boolean [ InitialExpression = 1 ];
Index Login On UserName [ Unique ];
}
