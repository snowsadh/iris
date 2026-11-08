Class Allfedo.Record.Event Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property ActorId As %String [ Required ];
Property Kind As %String [ Required ];
Property ResourceId As %String [ Required ];
Property RecordedAt As %BigInt [ Required ];
Property BodyJSON As %String(MAXLEN = 100000) [ Required ];
Index ByCase On (NetworkId, ResourceId, RecordedAt);
}
