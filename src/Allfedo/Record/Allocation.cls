Class Allfedo.Record.Allocation Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OfferId As %String [ Required ];
Property NeedId As %String [ Required ];
Property Quantity As %Integer(MINVAL = 0) [ Required ];
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
Property HeldQuantity As %Integer(MINVAL = 0);
Property CancelledUnhandedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property LegacyCollectedQuantity As %Integer(MINVAL = 0);
Property LegacyReceivedQuantity As %Integer(MINVAL = 0);
Property TripHistoryJSON As %String(MAXLEN = 100000);
Property OfferedQuantity As %Integer(MINVAL = 0);
Property OriginalPromiseQuantity As %Integer(MINVAL = 0);
Property StockCommittedQuantity As %Integer(MINVAL = 0);
Property AccountedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property LostQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property RejectedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property ReturnedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property DisposedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property SettledHandedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property ConsentContextKey As %String(MAXLEN = 64);
Property ClosedUnknownQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property OriginalTripJSON As %String(MAXLEN = 100000);
Property TripContextJSON As %String(MAXLEN = 100000);
Property TripContextKey As %String(MAXLEN = 64);
Property PendingChangeId As %String;
Property ParentAllocationId As %String;
Property RootAllocationId As %String;
Property TransferredInQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property TransferredOutQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property DestinationIssueSourceId As %String;
Property HandlingBreakReported As %Boolean [ InitialExpression = 0 ];
Property CustodyIssue As %String(MAXLEN = 2000);
Index ByParent On ParentAllocationId;
Index ByRoot On RootAllocationId;
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
<Value name="23">
<Value>HeldQuantity</Value>
</Value>
<Value name="24">
<Value>CancelledUnhandedQuantity</Value>
</Value>
<Value name="25">
<Value>LegacyCollectedQuantity</Value>
</Value>
<Value name="26">
<Value>LegacyReceivedQuantity</Value>
</Value>
<Value name="27">
<Value>TripHistoryJSON</Value>
</Value>
<Value name="28">
<Value>OfferedQuantity</Value>
</Value>
<Value name="29">
<Value>OriginalPromiseQuantity</Value>
</Value>
<Value name="30">
<Value>StockCommittedQuantity</Value>
</Value>
<Value name="31">
<Value>AccountedQuantity</Value>
</Value>
<Value name="32">
<Value>LostQuantity</Value>
</Value>
<Value name="33">
<Value>RejectedQuantity</Value>
</Value>
<Value name="34">
<Value>ReturnedQuantity</Value>
</Value>
<Value name="35">
<Value>DisposedQuantity</Value>
</Value>
<Value name="36">
<Value>SettledHandedQuantity</Value>
</Value>
<Value name="37">
<Value>ConsentContextKey</Value>
</Value>
<Value name="38">
<Value>ClosedUnknownQuantity</Value>
</Value>
<Value name="39">
<Value>OriginalTripJSON</Value>
</Value>
<Value name="40">
<Value>TripContextJSON</Value>
</Value>
<Value name="41">
<Value>TripContextKey</Value>
</Value>
<Value name="42">
<Value>PendingChangeId</Value>
</Value>
<Value name="43">
<Value>CustodyIssue</Value>
</Value>
<Value name="44">
<Value>ParentAllocationId</Value>
</Value>
<Value name="45">
<Value>RootAllocationId</Value>
</Value>
<Value name="46">
<Value>TransferredInQuantity</Value>
</Value>
<Value name="47">
<Value>TransferredOutQuantity</Value>
</Value>
<Value name="48">
<Value>DestinationIssueSourceId</Value>
</Value>
<Value name="49">
<Value>HandlingBreakReported</Value>
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
