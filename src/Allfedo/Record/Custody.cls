/// Signed physical facts. Recorded time and reported occurrence time remain separate.
Class Allfedo.Record.Custody Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OfferId As %String [ Required ];
Property AllocationId As %String;
Property ActorId As %String [ Required ];
Property Kind As %String [ Required ];
Property Active As %Boolean [ InitialExpression = 1 ];
Property Revision As %Integer [ InitialExpression = 1 ];
Property SupersedesId As %String;
Property Quantity As %Integer(MINVAL = 0) [ Required ];
Property OccurredAt As %BigInt [ Required ];
Property RecordedAt As %BigInt [ Required ];
Property SourceId As %String [ Required ];
Property AgreementIssue As %String(MAXLEN = 2000);
Index OfferHistory On (OfferId, OccurredAt);
Index AllocationHistory On (AllocationId, OccurredAt);

Storage Default
{
<Data name="CustodyDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>NetworkId</Value>
</Value>
<Value name="3">
<Value>OfferId</Value>
</Value>
<Value name="4">
<Value>AllocationId</Value>
</Value>
<Value name="5">
<Value>ActorId</Value>
</Value>
<Value name="6">
<Value>Kind</Value>
</Value>
<Value name="7">
<Value>Active</Value>
</Value>
<Value name="8">
<Value>Revision</Value>
</Value>
<Value name="9">
<Value>SupersedesId</Value>
</Value>
<Value name="10">
<Value>Quantity</Value>
</Value>
<Value name="11">
<Value>OccurredAt</Value>
</Value>
<Value name="12">
<Value>RecordedAt</Value>
</Value>
<Value name="13">
<Value>SourceId</Value>
</Value>
<Value name="14">
<Value>AgreementIssue</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.CustodyD</DataLocation>
<DefaultData>CustodyDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.CustodyD</IdLocation>
<IndexLocation>^Allfedo.Record.CustodyI</IndexLocation>
<StreamLocation>^Allfedo.Record.CustodyS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
