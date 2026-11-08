Class Allfedo.Record.Offer Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property ContactActorId As %String [ Required ];
Property Description As %String(MAXLEN = 500) [ Required ];
Property DeclaredQuantity As %Integer(MINVAL = 1) [ Required ];
Property ObservedQuantity As %Integer(MINVAL = 0);
Property CurrentQuantity As %Integer(MINVAL = 0) [ Required ];
Property HeldQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property CommittedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property CollectedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property Unit As %String [ InitialExpression = "meal_box" ];
Property ReadyAt As %BigInt [ Required ];
Property CollectBy As %BigInt [ Required ];
Property Holding As %String(VALUELIST = ",chilled,hot,ambient") [ Required ];
Property PresentAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property AssessedAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property SourceId As %String [ Required ];
Property Revision As %Integer [ InitialExpression = 1 ];
Property State As %String [ InitialExpression = "open" ];
Index ByNetwork On (NetworkId, State);
}
