Class Allfedo.Message.AgentRequest Extends Ens.Request
{
Property ActorId As %String [ Required ];
Property RequestId As %String(MAXLEN = 100) [ Required ];
Property OfferId As %String [ Required ];
/// Opaque session reference only. The provider key stays in the secure wallet.
Property AISettingsRef As %String(MAXLEN = 100);
}
