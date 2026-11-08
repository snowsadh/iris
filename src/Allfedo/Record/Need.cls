Class Allfedo.Record.Need Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property ContactActorId As %String [ Required ];
Property RequestedQuantity As %Integer(MINVAL = 1) [ Required ];
Property HeldQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property CommittedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property Unit As %String [ InitialExpression = "meal_box" ];
Property ReceivingUntil As %BigInt [ Required ];
Property ConfirmedUntil As %BigInt [ Required ];
Property ExcludedAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property AcceptedHoldingJSON As %String(MAXLEN = 4000) [ Required ];
Property SourceId As %String [ Required ];
Property Revision As %Integer [ InitialExpression = 1 ];
Index ByNetwork On NetworkId;
}
