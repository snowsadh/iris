Class Allfedo.Record.Allocation Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OfferId As %String [ Required ];
Property NeedId As %String [ Required ];
Property Quantity As %Integer(MINVAL = 1) [ Required ];
Property Unit As %String [ InitialExpression = "meal_box" ];
Property State As %String [ InitialExpression = "held" ];
Property HoldUntil As %BigInt [ Required ];
Property Revision As %Integer [ InitialExpression = 1 ];
Property OfferRevision As %Integer [ Required ];
Property NeedRevision As %Integer [ Required ];
Property DecisionJSON As %String(MAXLEN = 100000) [ Required ];
Property CollectorActorId As %String;
Property AssignedByActorId As %String;
Property PickupAt As %BigInt;
Property ArrivalBy As %BigInt;
Property TransportConfirmed As %Boolean [ InitialExpression = 0 ];
Property AcceptedByActorId As %String;
Property CollectedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property ReceivedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property UnresolvedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property OutcomeNote As %String(MAXLEN = 2000);
Index ByOffer On OfferId;
Index ByNeed On NeedId;
Index ByCollector On (CollectorActorId, PickupAt, ArrivalBy);
Index DueHolds On (State, HoldUntil);

Storage Default
{
<Data name="AllocationDefaultData">
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
<Value>NeedId</Value>
</Value>
<Value name="5">
<Value>Quantity</Value>
</Value>
<Value name="6">
<Value>Unit</Value>
</Value>
<Value name="7">
<Value>State</Value>
</Value>
<Value name="8">
<Value>HoldUntil</Value>
</Value>
<Value name="9">
<Value>Revision</Value>
</Value>
<Value name="10">
<Value>OfferRevision</Value>
</Value>
<Value name="11">
<Value>NeedRevision</Value>
</Value>
<Value name="12">
<Value>DecisionJSON</Value>
</Value>
<Value name="13">
<Value>CollectorActorId</Value>
</Value>
<Value name="14">
<Value>AssignedByActorId</Value>
</Value>
<Value name="15">
<Value>PickupAt</Value>
</Value>
<Value name="16">
<Value>ArrivalBy</Value>
</Value>
<Value name="17">
<Value>TransportConfirmed</Value>
</Value>
<Value name="18">
<Value>AcceptedByActorId</Value>
</Value>
<Value name="19">
<Value>CollectedQuantity</Value>
</Value>
<Value name="20">
<Value>ReceivedQuantity</Value>
</Value>
<Value name="21">
<Value>UnresolvedQuantity</Value>
</Value>
<Value name="22">
<Value>OutcomeNote</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.AllocationD</DataLocation>
<DefaultData>AllocationDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.AllocationD</IdLocation>
<IndexLocation>^Allfedo.Record.AllocationI</IndexLocation>
<StreamLocation>^Allfedo.Record.AllocationS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
