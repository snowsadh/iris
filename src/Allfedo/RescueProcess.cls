Include Ensemble

/// Routes planning to AI Hub and separate partner commands to guarded rescue changes.
Class Allfedo.RescueProcess Extends Ens.BusinessProcess
{
Method OnRequest(request As Allfedo.Message.CommandRequest, Output response As Allfedo.Message.CommandResponse) As %Status
{
    Set response=##class(Allfedo.Message.CommandResponse).%New()
    If request.Action="check_plan" {
        // Run Embedded Python in the existing trusted worker, keeping browser-user privileges narrow.
        Set actor=##class(Allfedo.Rescue).Actor(request.ActorId)
        Do ##class(Allfedo.Rescue).Require(actor.Role="coordinator","Only the coordinator can check a recipient plan.")
        Set proposal=##class(Allfedo.Rescue).Parse(request.PayloadJSON)
        Do ##class(Allfedo.Rescue).Require(proposal.%IsDefined("offer_id"),"A plan check needs the food offer ID.")
        Set snapshot=##class(Allfedo.Rescue).Snapshot(request.ActorId,proposal."offer_id")
        // Read only: a later explicit send must validate again under resource locks.
        Set checked=##class(Allfedo.Rescue).Parse(##class(Allfedo.Policy).Validate(snapshot.%ToJSON(),request.PayloadJSON))
        Do checked.%Set("check_only",1,"boolean")
        Do checked.%Set("reservation_created",0,"boolean")
        Set checked."checked_at"=##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now())
        Set response.ResultJSON=checked.%ToJSON()
    } ElseIf request.Action="plan_offer" {
        Set actor=##class(Allfedo.Rescue).Actor(request.ActorId)
        Do ##class(Allfedo.Rescue).Require(actor.Role="coordinator","Only the coordinator can ask for a plan.")
        Set body=##class(Allfedo.Rescue).Parse(request.PayloadJSON)
        Do ##class(Allfedo.Rescue).Require((body.%Size()=1)&&body.%IsDefined("offer_id"),"Planning needs only offer_id.")
        Set agentRequest=##class(Allfedo.Message.AgentRequest).%New()
        Set agentRequest.ActorId=request.ActorId, agentRequest.RequestId=request.RequestId, agentRequest.OfferId=body."offer_id"
        Set status=..SendRequestSync("Allfedo.Agent",agentRequest,.agentResponse,100)
        If $$$ISERR(status) Quit status
        // Planning is a suggestion. The coordinator reviews it and sends a separate apply_plan command.
        Set response.ResultJSON=agentResponse.ResultJSON
    } Else {
        Set response.ResultJSON=##class(Allfedo.Rescue).Execute(request.ActorId,request.RequestId,request.Action,request.PayloadJSON)
    }
    Quit $$$OK
}
}
