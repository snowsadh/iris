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

Storage Default
{
<Data name="AgentRunDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>NetworkId</Value>
</Value>
<Value name="3">
<Value>ActorId</Value>
</Value>
<Value name="4">
<Value>OfferId</Value>
</Value>
<Value name="5">
<Value>RequestId</Value>
</Value>
<Value name="6">
<Value>ResultJSON</Value>
</Value>
<Value name="7">
<Value>StartedAt</Value>
</Value>
<Value name="8">
<Value>FinishedAt</Value>
</Value>
<Value name="9">
<Value>Model</Value>
</Value>
<Value name="10">
<Value>SnapshotJSON</Value>
</Value>
<Value name="11">
<Value>ProposalJSON</Value>
</Value>
<Value name="12">
<Value>ToolAuditJSON</Value>
</Value>
<Value name="13">
<Value>UsageJSON</Value>
</Value>
<Value name="14">
<Value>Outcome</Value>
</Value>
<Value name="15">
<Value>ErrorCategory</Value>
</Value>
<Value name="16">
<Value>ErrorLocation</Value>
</Value>
</Data>
<DataLocation>^Allfedo.Record.AgentRunD</DataLocation>
<DefaultData>AgentRunDefaultData</DefaultData>
<IdLocation>^Allfedo.Record.AgentRunD</IdLocation>
<IndexLocation>^Allfedo.Record.AgentRunI</IndexLocation>
<StreamLocation>^Allfedo.Record.AgentRunS</StreamLocation>
<Type>%Storage.Persistent</Type>
}
}
