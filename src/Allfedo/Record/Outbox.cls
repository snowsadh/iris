Class Allfedo.Record.Outbox Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property AllocationId As %String [ Required ];
Property AllocationRevision As %Integer [ Required ];
Property Recipient As %String(MAXLEN = 320) [ Required ];
Property Subject As %String(MAXLEN = 300) [ Required ];
Property Body As %String(MAXLEN = 10000) [ Required ];
Property State As %String [ InitialExpression = "pending" ];
Property Attempts As %Integer [ InitialExpression = 0 ];
Property DueAt As %BigInt [ Required ];
Property LeaseUntil As %BigInt [ InitialExpression = 0 ];
Property LastError As %String(MAXLEN = 1000);
Property SentAt As %BigInt;
Index DueDelivery On (State, DueAt);

Storage Default
{
<Data name="OutboxDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>NetworkId</Value>
</Value>
<Value name="3">
<Value>AllocationId</Value>
</Value>
<Value name="4">
<Value>AllocationRevision</Value>
</Value>
<Value name="5">
<Value>Recipient</Value>
</Value>
<Value name="6">
<Value>Subject</Value>
</Value>
<Value name="7">
<Value>Body</Value>
</Value>
<Value name="8">
<Value>State</Value>
</Value>
<Value name="9">
<Value>Attempts</Value>
</Value>
<Value name="10">
<Value>DueAt</Value>
</Value>
<Value name="11">
<Value>LeaseUntil</Value>
</Value>
<Value name="12">
<Value>LastError</Value>
</Value>
<Value name="13">
<Value>SentAt</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.OutboxD</DataLocation>
<DefaultData>OutboxDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.OutboxD</IdLocation>
<IndexLocation>^Allfedo.Record.OutboxI</IndexLocation>
<StreamLocation>^Allfedo.Record.OutboxS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
