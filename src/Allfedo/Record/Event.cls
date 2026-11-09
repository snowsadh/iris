Class Allfedo.Record.Event Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property ActorId As %String [ Required ];
Property Kind As %String [ Required ];
Property ResourceId As %String [ Required ];
Property RecordedAt As %BigInt [ Required ];
Property BodyJSON As %String(MAXLEN = 100000) [ Required ];
Index ByCase On (NetworkId, ResourceId, RecordedAt);

Storage Default
{
<Data name="EventDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>NetworkId</Value>
</Value>
<Value name="3">
<Value>ActorId</Value>
</Value>
<Value name="4">
<Value>Kind</Value>
</Value>
<Value name="5">
<Value>ResourceId</Value>
</Value>
<Value name="6">
<Value>RecordedAt</Value>
</Value>
<Value name="7">
<Value>BodyJSON</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.EventD</DataLocation>
<DefaultData>EventDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.EventD</IdLocation>
<IndexLocation>^Allfedo.Record.EventI</IndexLocation>
<StreamLocation>^Allfedo.Record.EventS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
