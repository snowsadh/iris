/// One immutable proposed promise/instruction change and the responsible people's replies.
Class Allfedo.Record.ChangeRequest Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property AllocationId As %String [ Required ];
Property RequestedByActorId As %String [ Required ];
Property AllocationRevision As %Integer [ Required ];
Property NeedBaseSourceId As %String;
Property UnconfirmedSettlementQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property Revision As %Integer [ InitialExpression = 1 ];
Property State As %String [ InitialExpression = "awaiting_response" ];
Property OriginalQuantity As %Integer(MINVAL = 0) [ Required ];
Property NewQuantity As %Integer(MINVAL = 0) [ Required ];
Property Reason As %String(MAXLEN = 2000) [ Required ];
Property ContextJSON As %String(MAXLEN = 100000) [ Required ];
Property ContextKey As %String(MAXLEN = 64) [ Required ];
Property CreatedAt As %BigInt [ Required ];
Property RecipientRequired As %Boolean [ InitialExpression = 1 ];
Property KitchenRequired As %Boolean [ InitialExpression = 0 ];
Property RecipientSourceId As %String;
Property RecipientNeedSourceId As %String;
Property KitchenSourceId As %String;
Property KitchenStockSourceId As %String;
Property CollectorSourceId As %String;
Property StockReleaseQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property HandedSettlementQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property CompletedAt As %BigInt;
Index AllocationChanges On (AllocationId, CreatedAt);

Storage Default
{
<Data name="ChangeRequestDefaultData">
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
<Value>RequestedByActorId</Value>
</Value>
<Value name="5">
<Value>AllocationRevision</Value>
</Value>
<Value name="6">
<Value>NeedBaseSourceId</Value>
</Value>
<Value name="7">
<Value>UnconfirmedSettlementQuantity</Value>
</Value>
<Value name="8">
<Value>Revision</Value>
</Value>
<Value name="9">
<Value>State</Value>
</Value>
<Value name="10">
<Value>OriginalQuantity</Value>
</Value>
<Value name="11">
<Value>NewQuantity</Value>
</Value>
<Value name="12">
<Value>Reason</Value>
</Value>
<Value name="13">
<Value>ContextJSON</Value>
</Value>
<Value name="14">
<Value>ContextKey</Value>
</Value>
<Value name="15">
<Value>CreatedAt</Value>
</Value>
<Value name="16">
<Value>RecipientRequired</Value>
</Value>
<Value name="17">
<Value>KitchenRequired</Value>
</Value>
<Value name="18">
<Value>RecipientSourceId</Value>
</Value>
<Value name="19">
<Value>RecipientNeedSourceId</Value>
</Value>
<Value name="20">
<Value>KitchenSourceId</Value>
</Value>
<Value name="21">
<Value>KitchenStockSourceId</Value>
</Value>
<Value name="22">
<Value>CollectorSourceId</Value>
</Value>
<Value name="23">
<Value>StockReleaseQuantity</Value>
</Value>
<Value name="24">
<Value>HandedSettlementQuantity</Value>
</Value>
<Value name="25">
<Value>CompletedAt</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.ChangeRequestD</DataLocation>
<DefaultData>ChangeRequestDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.ChangeRequestD</IdLocation>
<IndexLocation>^Allfedo.Record.ChangeRequestI</IndexLocation>
<StreamLocation>^Allfedo.Record.ChangeRequestS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
