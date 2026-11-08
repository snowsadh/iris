Class Allfedo.Record.AgentRun Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property ActorId As %String [ Required ];
Property OfferId As %String [ Required ];
Property RequestId As %String(MAXLEN = 100) [ Required ];
Property ResultJSON As %String(MAXLEN = 100000);
Property StartedAt As %BigInt [ Required ];
Property FinishedAt As %BigInt;
Property Model As %String;
Property SnapshotJSON As %String(MAXLEN = 100000) [ Required ];
Property ProposalJSON As %String(MAXLEN = 100000);
Property ToolAuditJSON As %String(MAXLEN = 100000);
Property UsageJSON As %String(MAXLEN = 10000);
Property Outcome As %String;
/// Sanitized native class/code and fixed execution stage; never provider text or configuration.
Property ErrorCategory As %String(MAXLEN = 200);
Property ErrorLocation As %String(MAXLEN = 200);
Index RetryKey On (ActorId, RequestId) [ Unique ];
Index ByOffer On (OfferId, StartedAt);
}
