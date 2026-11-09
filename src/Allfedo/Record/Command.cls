Class Allfedo.Record.Command Extends %Persistent
{
Property ActorId As %String [ Required ];
Property RequestId As %String(MAXLEN = 100) [ Required ];
Property Action As %String [ Required ];
Property PayloadJSON As %String(MAXLEN = 100000) [ Required ];
Property ResultJSON As %String(MAXLEN = 100000) [ Required ];
Property RecordedAt As %BigInt [ Required ];
/// Native worker identity for tracing persistent-worker execution and lock recovery.
Property WorkerJob As %String;
Index RetryKey On (ActorId, RequestId) [ Unique ];

Storage Default
{
<Data name="CommandDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ActorId</Value>
</Value>
<Value name="3">
<Value>RequestId</Value>
</Value>
<Value name="4">
<Value>Action</Value>
</Value>
<Value name="5">
<Value>PayloadJSON</Value>
</Value>
<Value name="6">
<Value>ResultJSON</Value>
</Value>
<Value name="7">
<Value>RecordedAt</Value>
</Value>
<Value name="8">
<Value>WorkerJob</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.CommandD</DataLocation>
<DefaultData>CommandDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.CommandD</IdLocation>
<IndexLocation>^Allfedo.Record.CommandI</IndexLocation>
<StreamLocation>^Allfedo.Record.CommandS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
