/// Tools can read only this trusted case and submit a proposal. None can reserve or approve food.
Class Allfedo.CaseTools Extends %AI.ToolSet
{
Property ActorId As %String;
Property SnapshotJSON As %String(MAXLEN = 100000);
Property DeadlineAt As %BigInt;
Property ProposalJSON As %String(MAXLEN = 100000);
Property ReviewReason As %String(MAXLEN = 1000);
Property Audit As %DynamicArray;

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="AllfedoCase">
  <Tool Name="ReadOffer" Method="ReadOffer"/>
  <Tool Name="ReadCurrentNeeds" Method="ReadCurrentNeeds"/>
  <Tool Name="ReadCollectionFacts" Method="ReadCollectionFacts"/>
  <Tool Name="ReadCaseEvidence" Method="ReadCaseEvidence"/>
  <Tool Name="SubmitProposal" Method="SubmitProposal"/>
  <Tool Name="RequestReview" Method="RequestReview"/>
</ToolSet>
}

/// Read confirmed food facts, current revision, quantities, and evidence IDs for this offer.
Method ReadOffer() As %String
{
    Do ..Guard()
    Set snapshot=##class(Allfedo.Rescue).Parse(..SnapshotJSON)
    Do ..Log("ReadOffer",{})
    Quit snapshot.offer.%ToJSON()
}

/// Read current receiving needs in this network. Quantities are shared across all kitchens.
Method ReadCurrentNeeds() As %String
{
    Do ..Guard()
    Set snapshot=##class(Allfedo.Rescue).Parse(..SnapshotJSON)
    Do ..Log("ReadCurrentNeeds",{})
    Quit snapshot.needs.%ToJSON()
}

/// Read actual recorded collection agreements. Missing collector agreement is never confirmed transport.
Method ReadCollectionFacts() As %String
{
    Do ..Guard()
    Set snapshot=##class(Allfedo.Rescue).Parse(..SnapshotJSON), records=[]
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Allocation WHERE OfferId=? ORDER BY ID",snapshot.offer.id)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    While query.%Next() {
        Set item=##class(Allfedo.Record.Allocation).%OpenId(query.ID)
        Do records.%Push({"allocation_id":(""_item.%Id()),"need_id":(item.NeedId),"quantity":(""_item.Quantity),"state":(item.State),"transport_confirmed":(item.TransportConfirmed),"pickup_at":(item.PickupAt),"collector_actor_id":(item.CollectorActorId)})
    }
    Do ..Log("ReadCollectionFacts",{})
    Quit records.%ToJSON()
}

/// Read a cited source only when it belongs to this offer or one of its authorized receiving needs.
Method ReadCaseEvidence(sourceId As %String) As %String
{
    Do ..Guard()
    Set snapshot=##class(Allfedo.Rescue).Parse(..SnapshotJSON), permitted=0
    For i=0:1:snapshot.offer."source_ids".%Size()-1 { If snapshot.offer."source_ids".%Get(i)=sourceId Set permitted=1 }
    For i=0:1:snapshot.needs.%Size()-1 {
        Set need=snapshot.needs.%Get(i)
        For j=0:1:need."source_ids".%Size()-1 { If need."source_ids".%Get(j)=sourceId Set permitted=1 }
    }
    Do ##class(Allfedo.Rescue).Require(permitted,"This evidence is outside the authorized case.")
    Set source=##class(Allfedo.Record.Source).%OpenId(sourceId)
    Do ##class(Allfedo.Rescue).Require($IsObject(source)&&(source.NetworkId=snapshot."network_id"),"This source is not available to the case.")
    Do ..Log("ReadCaseEvidence",{"source_id":(sourceId)})
    Quit {"source_id":(sourceId),"actor_id":(source.ActorId),"sender_name":(source.SenderName),"organization_id":(source.OrganizationId),"confirmation_method":(source.ConfirmationMethod),"event_at":(##class(Allfedo.Policy).ISO(source.EventAt)),"recorded_at":(##class(Allfedo.Policy).ISO(source.RecordedAt)),"facts":(##class(Allfedo.Rescue).Parse(source.BodyJSON))}.%ToJSON()
}

/// Submit offer_id, offer_revision, reason, and requests with need_id, need_revision, quantity string, unit, evidence_ids. This checks a proposal only.
Method SubmitProposal(proposal As %DynamicObject) As %String
{
    Do ..Guard()
    Set checked=##class(Allfedo.Rescue).Parse(##class(Allfedo.Policy).Validate(..SnapshotJSON,proposal.%ToJSON()))
    Do ..Log("SubmitProposal",checked)
    If checked.ok Set ..ProposalJSON=proposal.%ToJSON(), ..ReviewReason=""
    Quit checked.%ToJSON()
}

/// Ask the coordinator a concrete question when no safe plan can be proposed. Do not invent missing facts.
Method RequestReview(reason As %String) As %String
{
    Do ..Guard()
    Do ##class(Allfedo.Rescue).Require((reason'="")&&($Length(reason)<=1000),"Give a short concrete question or obstacle.")
    Set ..ReviewReason=reason, ..ProposalJSON=""
    Do ..Log("RequestReview",{"reason":(reason)})
    Quit {"ok":true,"state":"review_required","reason":(reason)}.%ToJSON()
}

Method Guard()
{
    Set actor=##class(Allfedo.Rescue).Actor(..ActorId), snapshot=##class(Allfedo.Rescue).Parse(..SnapshotJSON)
    Do ##class(Allfedo.Rescue).Require((actor.Role="coordinator")&&(actor.NetworkId=snapshot."network_id"),"Your membership changed; this decision is no longer authorized.")
    Do ##class(Allfedo.Rescue).Require(##class(Allfedo.Policy).Now()<=..DeadlineAt,"This agent decision has expired. Start a fresh review.")
}

Method Log(tool As %String, outcome As %DynamicObject)
{
    If '$IsObject(..Audit) Set ..Audit=[]
    Do ..Audit.%Push({"tool":(tool),"at":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now())),"outcome":(outcome)})
}
}
