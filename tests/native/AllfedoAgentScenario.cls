/// Run with OPENAI_API_KEY and AI_API_KEY empty in this test session. Never contacts a provider.
Class AllfedoAgentScenario Extends %RegisteredObject
{
ClassMethod TestUnavailable() As %DynamicObject
{
    Do ##class(AllfedoScenario).Check(($SYSTEM.Util.GetEnviron("OPENAI_API_KEY")="")&&($SYSTEM.Util.GetEnviron("AI_API_KEY")=""),"This check requires empty provider keys in the test session only.")
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

/// Uses fake credentials and a test-session quota. No provider request is sent.
ClassMethod TestSettings() As %DynamicObject
{
    Do ##class(AllfedoScenario).Check($SYSTEM.Util.GetEnviron("AI_DAILY_LIMIT")="1","Run this check with AI_DAILY_LIMIT=1 in this test session only.")
    Do ##class(AllfedoScenario).Setup(.ids)
    Do ##class(AllfedoScenario).Setup(.otherIds)
    Set actor=##class(Allfedo.Rescue).Actor(ids.coordinator),other=##class(Allfedo.Rescue).Actor(otherIds.coordinator),reference="",key="allfedo-settings-test-not-a-real-key"
    Try {
        Set reference=##class(Allfedo.AISettings).Store(actor,{"provider":"openai","model":"gpt-4.1-mini","api_key":(key)})
        Set connection=##class(Allfedo.AISettings).Connection(actor,reference)
        Do ##class(AllfedoScenario).Check((connection."api_key"=key)&&(connection.source="personal"),"The planning worker can resolve the owner's key from the wallet.")
        Do ##class(AllfedoScenario).Check('$Find(^Allfedo.AISettings(reference),key),"Session metadata contains no API key.")
        Set view=##class(Allfedo.AISettings).Read(actor,reference)
        Do ##class(AllfedoScenario).Check((view.source="personal")&&('$Find(view.%ToJSON(),key)),"The settings read reports the connection without returning its key.")
        Set rejected=0
        Try { Set stolen=##class(Allfedo.AISettings).Connection(other,reference) } Catch error { Set rejected=1 }
        Do ##class(AllfedoScenario).Check(rejected,"Another coordinator cannot use this reference.")
        Set rejected=0
        Try { Do ##class(Allfedo.AISettings).Clear(other,reference) } Catch error { Set rejected=1 }
        Do ##class(AllfedoScenario).Check(rejected&&##class(%Wallet.Secret).Exists(reference),"Another coordinator cannot remove the saved key.")
        Set choices=##class(Allfedo.AISettings).Choices()
        For i=0:1:choices.%Size()-1 {
            Set choice=choices.%Get(i),config={"provider":(choice.id),"model":(choice.model),"api_key":(key)}
            Set provider=##class(Allfedo.AISettings).Provider(config)
            Do ##class(AllfedoScenario).Check(provider.Name=choice.id,"Each listed provider can be constructed by the installed native AI Hub.")
        }
        Set metadata=##class(Allfedo.Rescue).Parse(^Allfedo.AISettings(reference)),metadata."expires_at"=##class(Allfedo.Policy).Now()-1
        Set ^Allfedo.AISettings(reference)=metadata.%ToJSON(),rejected=0
        Try { Set expired=##class(Allfedo.AISettings).Connection(actor,reference) } Catch error { Set rejected=1 }
        Do ##class(AllfedoScenario).Check(rejected,"An expired personal connection cannot silently use the default key.")
        Set expired=##class(Allfedo.AISettings).Read(actor,reference)
        Do ##class(AllfedoScenario).Check((expired.source="expired")&&('##class(%Wallet.Secret).Exists(reference)),"A settings read removes the expired wallet entry and requests a new choice.")
        Set reference=""
        TSTART
        Set seed=##class(Allfedo.Record.AgentRun).%New()
        Set seed.NetworkId=actor.NetworkId,seed.ActorId=actor.%Id(),seed.OfferId=ids.offer,seed.RequestId=$SYSTEM.Util.CreateGUID(),seed.StartedAt=##class(Allfedo.Policy).Now(),seed.SnapshotJSON="{}",seed.CredentialSource="default"
        Do ##class(Allfedo.Rescue).Save(seed)
        Set blocked=##class(Allfedo.Record.AgentRun).%New(),blocked.CredentialSource="default",rejected=0
        Try { Do ##class(Allfedo.AISettings).StartRun(blocked) } Catch error { Set rejected=(error.Code=1101) }
        Do ##class(AllfedoScenario).Check(rejected&&(blocked.CredentialSource="blocked"),"The shared default-key limit rejects excess attempts before a provider call.")
        Set model=$Translate($Justify("",150)," ","m")
        Do ##class(Allfedo.AISettings).Validate("openrouter",model)
        Set personal=##class(Allfedo.Record.AgentRun).%New()
        Set personal.NetworkId=actor.NetworkId,personal.ActorId=actor.%Id(),personal.OfferId=ids.offer,personal.RequestId=$SYSTEM.Util.CreateGUID(),personal.StartedAt=##class(Allfedo.Policy).Now(),personal.SnapshotJSON="{}",personal.CredentialSource="personal",personal.Model=model
        Do ##class(Allfedo.AISettings).StartRun(personal)
        Set saved=##class(Allfedo.Record.AgentRun).%OpenId(personal.%Id())
        Do ##class(AllfedoScenario).Check(saved.Model=model,"A personal-key attempt can save a 150-character model even when the default allowance is full.")
        Set rejected=0
        Try { Do ##class(Allfedo.AISettings).Validate("openrouter",model_"m") } Catch error { Set rejected=1 }
        Do ##class(AllfedoScenario).Check(rejected,"Model IDs longer than the saved field allows are refused.")
        TROLLBACK
    } Catch error {
        If $TLEVEL TROLLBACK
        If reference'="" Do ##class(Allfedo.AISettings).Clear(actor,reference)
        Throw error
    }
    Quit {"ok":true,"checks":"wallet resolution, no key echo, cross-account denial, three native provider factories, expiry, removal, shared limit, personal-key bypass and model length","provider_called":false}
}
}
