Class Allfedo.Record.Source Extends %Persistent
{
Property NetworkId As %String [ Required ];
Property OrganizationId As %String [ Required ];
Property SenderName As %String(MAXLEN = 200) [ Required ];
Property ActorId As %String [ Required ];
Property Kind As %String [ Required ];
Property RecordedAt As %BigInt [ Required ];
Property EventAt As %BigInt [ Required ];
Property BodyJSON As %String(MAXLEN = 100000) [ Required ];
/// A signed-in partner confirmation, never raw model extraction.
Property ConfirmationMethod As %String(VALUELIST = ",authenticated_submission") [ InitialExpression = "authenticated_submission" ];
}
