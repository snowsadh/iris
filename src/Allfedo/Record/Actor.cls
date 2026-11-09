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

Storage Default
{
<Data name="ActorDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>UserName</Value>
</Value>
<Value name="3">
<Value>NetworkId</Value>
</Value>
<Value name="4">
<Value>OrganizationId</Value>
</Value>
<Value name="5">
<Value>DisplayName</Value>
</Value>
<Value name="6">
<Value>Email</Value>
</Value>
<Value name="7">
<Value>Role</Value>
</Value>
<Value name="8">
<Value>Active</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.ActorD</DataLocation>
<DefaultData>ActorDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.ActorD</IdLocation>
<IndexLocation>^Allfedo.Record.ActorI</IndexLocation>
<StreamLocation>^Allfedo.Record.ActorS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
