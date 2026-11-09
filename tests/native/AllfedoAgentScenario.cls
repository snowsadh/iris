/// Run in a local test session with OPENAI_API_KEY empty. Never contacts a provider.
Class AllfedoAgentScenario Extends %RegisteredObject
{
ClassMethod TestUnavailable() As %DynamicObject
{
    Do ##class(AllfedoScenario).Check($SYSTEM.Util.GetEnviron("OPENAI_API_KEY")="","This check requires an empty provider key in the test session only.")
    Do ##class(AllfedoScenario).Setup(.ids)
    Set operation=##class(Allfedo.Operation.Agent).%New("Allfedo.Agent"),request=##class(Allfedo.Message.AgentRequest).%New()
    Do ##class(AllfedoScenario).Check($IsObject(operation),"The failure check must construct the actual configured agent operation.")
    Set request.ActorId=ids.coordinator,request.OfferId=ids.offer,request.RequestId="unavailable-provider"
    Set status=operation.Decide(request,.response)
    Do ##class(AllfedoScenario).Check($SYSTEM.Status.IsOK(status),"An unavailable provider must return a saved outcome rather than break the caller.")
    Set result=##class(Allfedo.Rescue).Parse(response.ResultJSON)
    Do ##class(AllfedoScenario).Check('result.ok&&(result.error.code="AGENT_FAILED"),"Missing provider access must be reported without inventing a proposal.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.AgentRun WHERE ActorId=? AND RequestId=?",ids.coordinator,request.RequestId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ##class(AllfedoScenario).Check(query.%Next(),"The failed planning attempt must remain inspectable.")
    Set run=##class(Allfedo.Rescue).Open("Allfedo.Record.AgentRun",query.ID),saved=run.ResultJSON
    Do ##class(AllfedoScenario).Check((run.Outcome="failed")&&(run.ErrorLocation="Allfedo.Operation.Agent.Decide:provider_setup")&&(run.ProposalJSON=""),"Failure must be attributed to provider setup without a fake tool result.")
    Set status=operation.Decide(request,.retry)
    Do ##class(AllfedoScenario).Check($SYSTEM.Status.IsOK(status)&&(retry.ResultJSON=saved),"Checking the same failed request must return its original outcome.")
    Set request.OfferId=ids."second_offer",status=operation.Decide(request,.wrongOffer)
    Set preserved=##class(Allfedo.Rescue).Open("Allfedo.Record.AgentRun",run.%Id())
    Do ##class(AllfedoScenario).Check((preserved.OfferId=ids.offer)&&(preserved.ResultJSON=saved),"Reusing an ID for another offer must not overwrite the earlier attempt.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Do ##class(AllfedoScenario).Check((offer.HeldQuantity=0)&&(offer.CommittedQuantity=0),"A failed plan must not create a food hold.")
    Set plan=##class(AllfedoScenario).Plan(ids.coordinator,ids.offer,ids.need,"10")
    Set manual=##class(AllfedoScenario).Run(ids.coordinator,"manual-after-provider-failure","apply_plan",plan)
    Do ##class(AllfedoScenario).Check(manual.ok,"A checked manual plan must remain usable after model failure.")
    Quit {"ok":true,"checks":"provider unavailable, saved failed result, safe retry, request identity preserved, no automatic hold, checked manual fallback","provider_called":false,"fixture":(ids)}
}
}
