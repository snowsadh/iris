Class Allfedo.Message.CommandRequest Extends Ens.Request
{
Property ActorId As %String [ Required ];
Property RequestId As %String(MAXLEN = 100) [ Required ];
Property Action As %String [ Required ];
Property PayloadJSON As %String(MAXLEN = 100000) [ Required ];
}
