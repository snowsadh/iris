Class Allfedo.Record.Need Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property ContactActorId As %String [ Required ];
Property RequestedQuantity As %Integer(MINVAL = 0) [ Required ];
Property HeldQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property CommittedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property Unit As %String [ InitialExpression = "meal_box" ];
Property ReceivingUntil As %BigInt [ Required ];
Property ConfirmedUntil As %BigInt [ Required ];
Property ExcludedAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property AcceptedHoldingJSON As %String(MAXLEN = 4000) [ Required ];
Property SourceId As %String [ Required ];
Property State As %String [ InitialExpression = "open" ];
Property Revision As %Integer [ InitialExpression = 1 ];
Index ByNetwork On NetworkId;

Storage Default
{
<Data name="NeedDefaultData">
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
<Value>ContactActorId</Value>
</Value>
<Value name="5">
<Value>RequestedQuantity</Value>
</Value>
<Value name="6">
<Value>HeldQuantity</Value>
</Value>
<Value name="7">
<Value>CommittedQuantity</Value>
</Value>
<Value name="8">
<Value>Unit</Value>
</Value>
<Value name="9">
<Value>ReceivingUntil</Value>
</Value>
<Value name="10">
<Value>ConfirmedUntil</Value>
</Value>
<Value name="11">
<Value>ExcludedAllergensJSON</Value>
</Value>
<Value name="12">
<Value>AcceptedHoldingJSON</Value>
</Value>
<Value name="13">
<Value>SourceId</Value>
</Value>
<Value name="14">
<Value>Revision</Value>
</Value>
<Value name="15">
<Value>State</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.NeedD</DataLocation>
<DefaultData>NeedDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.NeedD</IdLocation>
<IndexLocation>^Allfedo.Record.NeedI</IndexLocation>
<StreamLocation>^Allfedo.Record.NeedS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
