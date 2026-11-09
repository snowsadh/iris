/// A partner's own confirmed place and contact. One site per network/organization in this release.
Class Allfedo.Record.Site Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property Name As %String(MAXLEN = 200) [ Required ];
Property Address As %String(MAXLEN = 1000) [ Required ];
Property Entrance As %String(MAXLEN = 1000);
Property TimeZone As %String(MAXLEN = 100) [ Required ];
Property ContactActorId As %String [ Required ];
Property ContactPhone As %String(MAXLEN = 100);
Property SourceId As %String [ Required ];
Property Revision As %Integer [ InitialExpression = 1 ];
Index PartnerSite On (NetworkId, OrganizationId) [ Unique ];

Storage Default
{
<Data name="SiteDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>NetworkId</Value>
</Value>
<Value name="3">
<Value>OrganizationId</Value>
</Value>
<Value name="4">
<Value>Name</Value>
</Value>
<Value name="5">
<Value>Address</Value>
</Value>
<Value name="6">
<Value>Entrance</Value>
</Value>
<Value name="7">
<Value>TimeZone</Value>
</Value>
<Value name="8">
<Value>ContactActorId</Value>
</Value>
<Value name="9">
<Value>ContactPhone</Value>
</Value>
<Value name="10">
<Value>SourceId</Value>
</Value>
<Value name="11">
<Value>Revision</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.SiteD</DataLocation>
<DefaultData>SiteDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.SiteD</IdLocation>
<IndexLocation>^Allfedo.Record.SiteI</IndexLocation>
<StreamLocation>^Allfedo.Record.SiteS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
