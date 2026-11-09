Class Allfedo.Record.Source Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property SenderName As %String(MAXLEN = 200) [ Required ];
Property ActorId As %String [ Required ];
Property Kind As %String [ Required ];
Property RecordedAt As %BigInt [ Required ];
Property EventAt As %BigInt [ Required ];
Property BodyJSON As %String(MAXLEN = 100000) [ Required ];
/// A signed-in partner confirmation, never raw model extraction.
Property ConfirmationMethod As %String(VALUELIST = ",authenticated_submission") [ InitialExpression = "authenticated_submission" ];

Storage Default
{
<Data name="SourceDefaultData">
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
<Value>SenderName</Value>
</Value>
<Value name="5">
<Value>ActorId</Value>
</Value>
<Value name="6">
<Value>Kind</Value>
</Value>
<Value name="7">
<Value>RecordedAt</Value>
</Value>
<Value name="8">
<Value>EventAt</Value>
</Value>
<Value name="9">
<Value>BodyJSON</Value>
</Value>
<Value name="10">
<Value>ConfirmationMethod</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.SourceD</DataLocation>
<DefaultData>SourceDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.SourceD</IdLocation>
<IndexLocation>^Allfedo.Record.SourceI</IndexLocation>
<StreamLocation>^Allfedo.Record.SourceS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
