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
}
