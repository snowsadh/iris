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
Property Holding As %String(VALUELIST = ",chilled,hot,ambient");
Property HandlingUntil As %BigInt;
Property Packaging As %String(MAXLEN = 1000);
Property PresentAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property AssessedAllergensJSON As %String(MAXLEN = 4000) [ Required ];
Property SourceId As %String [ Required ];
/// Original signed quantity/description source remains evidence after later food confirmations.
Property OriginalSourceId As %String;
Property ObservationConflict As %Boolean [ InitialExpression = 0 ];

Property ObservationSourceId As %String;
Property ObservationAt As %BigInt;
Property QuarantinedQuantity As %Integer(MINVAL = 0) [ InitialExpression = 0 ];
Property StockProjectionJSON As %String(MAXLEN = 100000);
Property LegacyCollectedQuantity As %Integer(MINVAL = 0);
Property LegacyRecordedUntil As %BigInt;
Property Revision As %Integer [ InitialExpression = 1 ];
Property State As %String [ InitialExpression = "open" ];
Index ByNetwork On (NetworkId, State);

Storage Default
{
<Data name="OfferDefaultData">
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
<Value>Description</Value>
</Value>
<Value name="6">
<Value>DeclaredQuantity</Value>
</Value>
<Value name="7">
<Value>ObservedQuantity</Value>
</Value>
<Value name="8">
<Value>CurrentQuantity</Value>
</Value>
<Value name="9">
<Value>HeldQuantity</Value>
</Value>
<Value name="10">
<Value>CommittedQuantity</Value>
</Value>
<Value name="11">
<Value>CollectedQuantity</Value>
</Value>
<Value name="12">
<Value>Unit</Value>
</Value>
<Value name="13">
<Value>ReadyAt</Value>
</Value>
<Value name="14">
<Value>CollectBy</Value>
</Value>
<Value name="15">
<Value>Holding</Value>
</Value>
<Value name="16">
<Value>PresentAllergensJSON</Value>
</Value>
<Value name="17">
<Value>AssessedAllergensJSON</Value>
</Value>
<Value name="18">
<Value>SourceId</Value>
</Value>
<Value name="19">
<Value>Revision</Value>
</Value>
<Value name="20">
<Value>State</Value>
</Value>
<Value name="21">
<Value>HandlingUntil</Value>
</Value>
<Value name="22">
<Value>Packaging</Value>
</Value>
<Value name="23">
<Value>OriginalSourceId</Value>
</Value>
<Value name="24">
<Value>ObservationConflict</Value>
</Value>
<Value name="25">
<Value>ObservationSourceId</Value>
</Value>
<Value name="26">
<Value>ObservationAt</Value>
</Value>
<Value name="27">
<Value>QuarantinedQuantity</Value>
</Value>
<Value name="28">
<Value>StockProjectionJSON</Value>
</Value>
<Value name="29">
<Value>LegacyCollectedQuantity</Value>
</Value>
<Value name="30">
<Value>LegacyRecordedUntil</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.OfferD</DataLocation>
<DefaultData>OfferDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.OfferD</IdLocation>
<IndexLocation>^Allfedo.Record.OfferI</IndexLocation>
<StreamLocation>^Allfedo.Record.OfferS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
