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
}
