Class Allfedo.Record.Command Extends %Persistent
{
Property ActorId As %String [ Required ];
Property RequestId As %String(MAXLEN = 100) [ Required ];
Property Action As %String [ Required ];
Property PayloadJSON As %String(MAXLEN = 100000) [ Required ];
Property ResultJSON As %String(MAXLEN = 100000) [ Required ];
Property RecordedAt As %BigInt [ Required ];
Index RetryKey On (ActorId, RequestId) [ Unique ];
}
