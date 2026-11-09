Include Ensemble

/// Called through an authenticated native process. The signed-in principal supplies identity.
Class Allfedo.CommandService Extends Ens.BusinessService
{
Parameter ADAPTER = "";

Method OnProcessInput(input As Allfedo.Message.CommandRequest, Output output As Allfedo.Message.CommandResponse) As %Status
{
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Actor WHERE UserName=? AND Active=1",$USERNAME)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    If 'query.%Next() Quit $$$ERROR($$$GeneralError,"This authenticated account has no active Allfedo membership.")
    // Deliberately overwrite any actor supplied by the caller.
    Set input.ActorId=""_query.ID
    Quit ..SendRequestSync("Allfedo.Rescue",input,.output,120)
}
}
