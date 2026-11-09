/// Native integration checks. Synthetic partners are explicit fixtures, not authenticated browser accounts.
Class AllfedoScenario Extends %RegisteredObject
{
ClassMethod Setup(Output ids As %DynamicObject)
{
    Set network="native-test-"_$Job_"-"_$Increment(^Allfedo.Test.Sequence)
    Set ids={"network":(network)}
    Set ids.coordinator=..Actor(network,"coordinator","network-office","Alex Morgan")
    Set ids.kitchen=..Actor(network,"kitchen","harbor-kitchen","Jamie Reed")
    Set ids."second_kitchen"=..Actor(network,"kitchen","market-kitchen","Robin Clarke")
    Set ids.recipient=..Actor(network,"recipient","westside-center","Taylor Hayes")
    Set ids."second_recipient"=..Actor(network,"recipient","riverside-center","Casey Bell")
    Set ids."third_recipient"=..Actor(network,"recipient","northside-center","Jordan Avery")
    Set ids.collector=..Actor(network,"collector","rescue-team","Sam Carter")
    Set profiles=[{"actor":(ids.kitchen),"name":"Harbor Kitchen","address":"24 Canal Street","entrance":"Loading entrance beside the courtyard"},{"actor":(ids."second_kitchen"),"name":"Market Kitchen","address":"18 Market Lane","entrance":"Kitchen door at the rear"},{"actor":(ids.recipient),"name":"Westside Center","address":"6 West Street","entrance":"Reception entrance"},{"actor":(ids."second_recipient"),"name":"Riverside Center","address":"12 River Lane","entrance":"Delivery door beside reception"},{"actor":(ids."third_recipient"),"name":"Northside Center","address":"9 North Road","entrance":"Community dining entrance"}]
    For index=0:1:profiles.%Size()-1 {
        Set profile=profiles.%Get(index)
        Set result=..Run(profile.actor,"confirm-site","save_site",{"revision":0,"name":(profile.name),"address":(profile.address),"entrance":(profile.entrance),"time_zone":"Etc/UTC","contact_phone":""})
        Do ..Check(result.ok,"A partner's confirmed place must be saved.")
    }
    Set now=##class(Allfedo.Policy).Now(), event=##class(Allfedo.Policy).ISO(now-120)
    Set offer={"description":"Sealed vegetable meal boxes","quantity":"40","unit":"meal_box","ready_at":(##class(Allfedo.Policy).ISO(now-60)),"collect_by":(##class(Allfedo.Policy).ISO(now+3600)),"holding":"chilled","handling_until":(##class(Allfedo.Policy).ISO(now+4200)),"packaging":"Four carry cartons, ten sealed meal boxes each","present_allergens":[],"assessed_allergens":["milk","peanut"],"event_at":(event)}
    Set result=..Run(ids.kitchen,"create-offer","create_offer",offer)
    Do ..Check(result.ok,"Fixture kitchen offer was rejected.")
    Set ids.offer=""_result."offer_id"
    Set result=..Run(ids."second_kitchen","create-offer","create_offer",offer)
    Do ..Check(result.ok,"Second kitchen offer was rejected.")
    Set ids."second_offer"=""_result."offer_id"
    Set need={"quantity":"50","unit":"meal_box","receiving_from":(##class(Allfedo.Policy).ISO(now-60)),"receiving_until":(##class(Allfedo.Policy).ISO(now+4500)),"confirmed_until":(##class(Allfedo.Policy).ISO(now+4000)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(event)}
    Set result=..Run(ids.recipient,"create-need","create_need",need)
    Do ..Check(result.ok,"Fixture receiving need was rejected.")
    Set ids.need=""_result."need_id"
    Set need.quantity="20", result=..Run(ids."second_recipient","create-need","create_need",need)
    Do ..Check(result.ok,"Second receiving need was rejected.")
    Set ids."second_need"=""_result."need_id"
    Set need.quantity="15", need."excluded_allergens"=["milk"], result=..Run(ids."third_recipient","create-need","create_need",need)
    Do ..Check(result.ok,"Third receiving need was rejected.")
    Set ids."third_need"=""_result."need_id"
}

ClassMethod TestArithmeticGuards() As %DynamicObject
{
    Set item=##class(Allfedo.Record.Allocation).%New(),item.StockCommittedQuantity=0,item.CollectedQuantity=20,item.ReceivedQuantity=18,item.AccountedQuantity=4,item.TransferredOutQuantity=0
    Set balance=##class(Allfedo.Recovery).Balance(item)
    Do ..Check((balance."physical_unknown_quantity"="0")&&(balance."unmatched_report_quantity"="2"),"An excess report must expose two unmatched boxes, never negative unknown custody.")
    Set item.ReceivedQuantity=5,item.AccountedQuantity=0,item.TransferredOutQuantity=10,balance=##class(Allfedo.Recovery).Balance(item)
    Do ..Check((balance."physical_unknown_quantity"="5")&&(balance."unmatched_report_quantity"="0"),"Transferred and accepted portions must be added before comparing physical custody.")
    Do ..Setup(.ids)
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),source=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",food.SourceId),data=##class(Allfedo.Rescue).Parse(source.BodyJSON)
    Set data."event_at"=##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()+3600)
    Set future=..Run(ids.kitchen,"future-source-guard","create_offer",data)
    Do ..Check('future.ok,"A future source timestamp cannot bypass the allowed clock tolerance.")
    Set allocation=..ReadyCase(ids,"20"),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=..Run(ids.kitchen,"short-stock-guard","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"10","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Only ten boxes remain physically here against a twenty-box promise."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),resumed=..Run(ids.coordinator,"cannot-resume-short-stock","resume_offer",{"offer_id":(ids.offer),"revision":(food.Revision)})
    Do ..Check(counted.ok&&'resumed.ok,"Stock cannot resume while committed food exceeds the actual usable quantity.")
    Quit {"ok":true,"checks":"nonnegative custody, transfer sums, future source tolerance, short-stock resume guard"}
}

ClassMethod TestCommands() As %DynamicObject
{
    Do ..Setup(.ids)
    Set plan=..Plan(ids.coordinator,ids.offer,ids.need,"35")
    Set original=..Run(ids.coordinator,"first-hold","apply_plan",plan)
    Do ..Check(original.ok,"The first valid hold should succeed.")
    Set duplicate=..Run(ids.coordinator,"first-hold","apply_plan",plan)
    Do ..Check(original.%ToJSON()=duplicate.%ToJSON(),"Retry must return the same saved outcome.")
    Set changedRequest=plan.requests.%Get(0), changedRequest.quantity="34"
    Set changed=..Run(ids.coordinator,"first-hold","apply_plan",plan)
    Do ..Check('changed.ok&&(changed.error.code="REQUEST_ID_REUSED"),"Changed input must not reuse a request ID.")
    Set plan=..Plan(ids.coordinator,ids."second_offer",ids.need,"35"), competing=..Run(ids.coordinator,"too-much-shared-need","apply_plan",plan)
    Do ..Check('competing.ok,"A second kitchen cannot hold beyond shared need.")
    Set food=##class(Allfedo.Record.Offer).%OpenId(ids."second_offer")
    Do ..Check(food.HeldQuantity=0,"Rejected multi-resource commands must leave food unchanged.")
    Set plan=..Plan(ids.coordinator,ids."second_offer",ids.need,"15"), second=..Run(ids.coordinator,"remaining-shared-need","apply_plan",plan)
    Do ..Check(second.ok,"A second kitchen can use the actual remaining need.")
    Set need=##class(Allfedo.Record.Need).%OpenId(ids.need)
    Do ..Check(need.HeldQuantity=50,"Both kitchens must consume one shared need.")
    Set allocationId=original."allocation_ids".%Get(0)
    Set accepted=..Run(ids.recipient,"accept-thirty","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"30","context_key":(..ContextKey(allocationId))})
    Do ..Check(accepted.ok&&(accepted.state="accepted"),"Recipient acceptance should convert the hold.")
    Set now=##class(Allfedo.Policy).Now()
    Set unassigned=..Run(ids.collector,"cannot-self-claim","confirm_transport",{"allocation_id":(allocationId),"revision":2,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"30","handling_accepted":true,"context_key":(..ContextKey(allocationId))})
    Do ..Check('unassigned.ok,"A collector cannot self-claim an unassigned pickup.")
    Set assigned=..Run(ids.coordinator,"assign-known-collector","assign_collector",{"allocation_id":(allocationId),"revision":2,"collector_actor_id":(ids.collector)})
    Do ..Check(assigned.ok,"The coordinator must be able to assign a known network collector.")
    Set trip=..Run(ids.collector,"confirm-own-trip","confirm_transport",{"allocation_id":(allocationId),"revision":3,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"30","handling_accepted":true,"context_key":(..ContextKey(allocationId))})
    Do ..Check(trip.ok&&(trip.state="ready"),"A named collector must confirm a compatible trip.")
    Set expired=..Run(ids.coordinator,"never-expire-accepted","expire_hold",{"allocation_id":(allocationId),"revision":4})
    Do ..Check('expired.ok,"An accepted pickup must never auto-release on a timer.")
    Set handoff=..Run(ids.kitchen,"handoff-actual","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"28","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Two meal boxes were not present at the loading point. They remain unresolved."})
    Do ..Check(handoff.ok&&(handoff."collected_quantity"="28"),"Handoff must record actual custody.")
    Set receipt=..Run(ids.recipient,"receipt-actual","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"27","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"One handed-over box was damaged; two promised boxes were never handed over."})
    Do ..Check(receipt.ok&&(receipt."received_quantity"="27")&&(receipt."unresolved_quantity"="3")&&(receipt.state="receipt_issue"),"Receipt cannot turn missing boxes into delivered food.")
    Set forbidden=..Run(ids."second_recipient","other-partner-receipt","receive",{"allocation_id":(allocationId),"revision":6,"quantity":"28","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":""})
    Do ..Check('forbidden.ok,"Another recipient must not act on this collection.")
    Set food=##class(Allfedo.Record.Offer).%OpenId(ids.offer)
    Set observation=..Run(ids.kitchen,"physical-count","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"7","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Seven boxes remain physically here after the earlier 28-box handoff; none are returns."})
    Do ..Check(observation.ok&&(observation.state="review_required")&&(observation."declared_quantity"="40"),"A shortage must preserve the original declaration and pause promises.")
    Quit {"ok":true,"checks":"retry, shared need, rollback, partial acceptance, named trip, no accepted expiry, physical handoff, partial receipt, authorization, shortage history","fixture":(ids)}
}

/// Unknown food facts are saved, then explicitly confirmed. A reduced need never erases existing promises.
ClassMethod TestFacts() As %DynamicObject
{
    Do ..Setup(.ids)
    Set now=##class(Allfedo.Policy).Now(), event=##class(Allfedo.Policy).ISO(now)
    Set food={"description":"Meal boxes awaiting kitchen handling details","quantity":"12","unit":"meal_box","ready_at":(##class(Allfedo.Policy).ISO(now-60)),"collect_by":(##class(Allfedo.Policy).ISO(now+3600)),"holding":null,"handling_until":null,"packaging":"","present_allergens":[],"assessed_allergens":["milk"],"event_at":(event)}
    Set created=..Run(ids.kitchen,"save-unknown-food","create_offer",food)
    Do ..Check(created.ok&&(created.state="needs_details"),"Unknown food conditions must be saved honestly as needing details.")
    Set offerId=created."offer_id", plan=..Plan(ids.coordinator,offerId,ids.need,"10"), blocked=..Run(ids.coordinator,"cannot-plan-unknown","apply_plan",plan)
    Do ..Check('blocked.ok,"Unknown food conditions cannot become a compatible invitation.")
    Set confirmation={"offer_id":(offerId),"revision":1,"ready_at":(food."ready_at"),"collect_by":(food."collect_by"),"holding":"chilled","handling_until":(##class(Allfedo.Policy).ISO(now+4200)),"packaging":"","present_allergens":[],"assessed_allergens":["milk"],"event_at":(event)}
    Set confirmed=..Run(ids.kitchen,"confirm-food-conditions","confirm_food",confirmation)
    Do ..Check(confirmed.ok&&(confirmed.state="open"),"Known food conditions can open the offer while transport packaging remains a separate gap.")
    Set plan=..Plan(ids.coordinator,offerId,ids.need,"10"), held=..Run(ids.coordinator,"send-known-food","apply_plan",plan)
    Do ..Check(held.ok,"Confirmed food can be held for the current receiving need.")
    Set allocationId=held."allocation_ids".%Get(0),reviewedKey=..ContextKey(allocationId),kitchen=##class(Allfedo.Rescue).Actor(ids.kitchen),site=##class(Allfedo.Facts).SiteFor(ids.network,kitchen.OrganizationId)
    Set changedEntrance=..Run(ids.kitchen,"changed-before-recipient-accepts","save_site",{"revision":(site.Revision),"name":(site.Name),"address":(site.Address),"entrance":"Use the north service entrance; the earlier entrance is closed","time_zone":(site.TimeZone),"contact_phone":(site.ContactPhone)})
    Set staleAccept=..Run(ids.recipient,"cannot-accept-unseen-details","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"10","context_key":(reviewedKey)})
    Do ..Check(changedEntrance.ok&&'staleAccept.ok&&(staleAccept.error.message["details changed"),"Recipient acceptance must bind the actual displayed details even when the allocation revision stayed unchanged.")
    Set accepted=..Run(ids.recipient,"accept-known-food","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"10","context_key":(..ContextKey(allocationId))})
    Do ..Check(accepted.ok,"The receiving partner must explicitly accept the food.")
    Set assigned=..Run(ids.coordinator,"assign-known-food-trip","assign_collector",{"allocation_id":(allocationId),"revision":2,"collector_actor_id":(ids.collector)})
    Do ..Check(assigned.ok,"The coordinator must assign this collection.")
    Set trip={"allocation_id":(allocationId),"revision":3,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"10","handling_accepted":true,"context_key":(..ContextKey(allocationId))}
    Set missingPackaging=..Run(ids.collector,"cannot-infer-carrying-fit","confirm_transport",trip)
    Do ..Check('missingPackaging.ok,"A meal-box count cannot establish carrying arrangements when packaging is unknown.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",offerId), confirmation.revision=offer.Revision, confirmation.packaging="Two carry cartons, six sealed meal boxes each"
    Set packed=..Run(ids.kitchen,"confirm-carrying-details","confirm_food",confirmation)
    Do ..Check(packed.ok&&(packed.state="open"),"Adding packaging alone must not rewrite unchanged food conditions or dead-end an existing acceptance.")
    Set trip."context_key"=..ContextKey(allocationId)
    Set ready=..Run(ids.collector,"confirm-informed-trip","confirm_transport",trip)
    Do ..Check(ready.ok,"The assigned collector can confirm actual packaging, capacity, times, and handling.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",offerId), confirmation.revision=offer.Revision, confirmation.packaging="One large insulated carry crate; earlier carton arrangement withdrawn"
    Set changedLoad=..Run(ids.kitchen,"report-changed-confirmed-load","confirm_food",confirmation)
    Do ..Check(changedLoad.ok&&(changedLoad.state="review_required"),"Changing an already confirmed load must pause the earlier pickup agreement.")
    Set pausedCase=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Check(##class(Allfedo.Recovery).TripChanged(pausedCase),"A confirmed collector must not inherit changed carrying instructions without review.")
    Set evidenceSnapshot=##class(Allfedo.Rescue).Snapshot(ids.coordinator,offerId)
    Do ..Check(evidenceSnapshot.offer."source_ids".%Size()=2,"Later food confirmations must preserve the original quantity evidence.")
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set update={"need_id":(ids.need),"revision":(need.Revision),"quantity":"5","unit":"meal_box","receiving_from":(##class(Allfedo.Policy).ISO(now-60)),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(event)}
    Set reduced=..Run(ids.recipient,"report-reduced-actual-need","update_need",update)
    Do ..Check(reduced.ok&&(reduced.state="review_required")&&(reduced."committed_quantity"="10")&&(reduced."shortfall_quantity"="5"),"A reduced actual need must remain truthful while all existing promises remain recorded.")
    Set snapshot=##class(Allfedo.Rescue).Snapshot(ids.coordinator,ids.offer), selected=""
    For index=0:1:snapshot.needs.%Size()-1 { Set item=snapshot.needs.%Get(index) If item.id=ids.need Set selected=item }
    Do ..Check($IsObject(selected)&&(selected."remaining_quantity"="0")&&(selected.state="review_required"),"An oversubscribed need must expose zero remaining capacity, never a negative snapshot.")
    Set otherPlan=..Plan(ids.coordinator,ids.offer,ids."second_need","5"), other=..Run(ids.coordinator,"unaffected-partner-still-works","apply_plan",otherPlan)
    Do ..Check(other.ok,"One partner's changed need must not invalidate the whole network snapshot.")
    Set changedCase=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Set changedContext=##class(Allfedo.Recovery).CurrentContext(changedCase)
    Set rejectedReagreement=..Run(ids.collector,"cannot-bypass-reduced-need","acknowledge_trip",{"allocation_id":(allocationId),"revision":4,"context_key":(..ContextKey(allocationId)),"capacity":"10","handling_accepted":true,"arrival_by":(##class(Allfedo.Policy).ISO(now+1800))})
    Do ..Check('rejectedReagreement.ok&&(rejectedReagreement.error.message["receiving need"),"A collector cannot bypass a reduced receiving need by acknowledging the trip again.")
    Set currentNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Do ..Check((##class(Allfedo.Facts).NeedState(currentNeed)="review_required")&&(currentNeed.CommittedQuantity>currentNeed.RequestedQuantity),"Reduced total demand must block further agreements until existing promises are explicitly changed.")
    Set shortNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need"), validUntil=##class(Allfedo.Policy).Now()+120
    Set shortUpdate={"need_id":(ids."third_need"),"revision":(shortNeed.Revision),"quantity":"15","unit":"meal_box","receiving_from":(##class(Allfedo.Policy).ISO(now-60)),"receiving_until":(##class(Allfedo.Policy).ISO(validUntil+300)),"confirmed_until":(##class(Allfedo.Policy).ISO(validUntil)),"excluded_allergens":["milk"],"accepted_holding":["chilled"],"event_at":(event)}
    Set refreshed=..Run(ids."third_recipient","short-lived-current-need","update_need",shortUpdate)
    Do ..Check(refreshed.ok&&(refreshed.state="open"),"A current short-lived need without promises must be saved.")
    Set shortPlan=..Plan(ids.coordinator,ids."second_offer",ids."third_need","5"), shortHold=..Run(ids.coordinator,"honest-reply-deadline","apply_plan",shortPlan)
    Do ..Check(shortHold.ok,"A compatible request can be sent within the actual short receiving-need deadline.")
    Set shortAllocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",shortHold."allocation_ids".%Get(0))
    Do ..Check(shortAllocation.HoldUntil=validUntil,"Invitation expiry must not outlast the confirmed receiving need.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Outbox WHERE AllocationId=?",shortAllocation.%Id())
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check(query.%Next(),"The short-lived invitation needs a saved notification.")
    Set notification=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",query.ID)
    Do ..Check(notification.Body[##class(Allfedo.Policy).ISO(validUntil),"The advertised email deadline must match the saved invitation deadline.")
    Set before=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need"),oldSourceId=before.SourceId,oldContact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids."third_recipient"),oldContact.Active=0
    Do ##class(Allfedo.Rescue).Save(oldContact)
    Set nextId=..Actor(ids.network,"recipient","northside-duty","Riley Grant"),next=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",nextId),next.OrganizationId=before.OrganizationId,next.Email="northside-duty@example.test"
    Do ##class(Allfedo.Rescue).Save(next)
    Set refresh={"need_id":(""_before.%Id()),"revision":(before.Revision),"quantity":(""_before.RequestedQuantity),"unit":(before.Unit),"receiving_from":(##class(Allfedo.Policy).ISO(before.ReceivingFrom)),"receiving_until":(##class(Allfedo.Policy).ISO(before.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(before.ConfirmedUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(before.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(before.AcceptedHoldingJSON)),"event_at":(##class(Allfedo.Policy).NowISO())}
    Set refreshed=..Run(nextId,"new-duty-contact-confirms-need","update_need",refresh),plan=..Plan(ids.coordinator,ids."second_offer",ids."third_need","1"),held=..Run(ids.coordinator,"notify-current-duty-contact","apply_plan",plan)
    Do ..Check(refreshed.ok&&held.ok,"An approved replacement staff member can confirm current need and receive its invitation.")
    Set currentNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need"),oldSource=##class(Allfedo.Rescue).Open("Allfedo.Record.Source",oldSourceId)
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Outbox WHERE AllocationId=?",held."allocation_ids".%Get(0))
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check(query.%Next(),"The current duty contact needs a saved delivery intention.")
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Set notification=##class(Allfedo.Rescue).Open("Allfedo.Record.Outbox",query.ID)
    Do ..Check((currentNeed.ContactActorId=nextId)&&(notification.RecipientActorId=nextId)&&(notification.Recipient=next.Email)&&(oldSource.ActorId=ids."third_recipient"),"Duty handover changes the current addressed contact while preserving the original source author.")
    Quit {"ok":true,"checks":"confirmed site, unknown food intake, reconfirmed food, packaging gap, explicit informed transport, reduced actual need, preserved promises, zero-clamped capacity, unaffected partners"}
}

/// Real recovery commands preserve custody while changing only explicitly agreed promises.
ClassMethod TestRecovery() As %DynamicObject
{
    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"complete-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty boxes handed to the assigned collector."})
    Set received=..Run(ids.recipient,"complete-receipt","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"All twenty meal boxes accepted."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),balance=##class(Allfedo.Recovery).Balance(allocation),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Do ..Check(handed.ok&&received.ok&&(received.state="received")&&(handed."agreement_issue"="")&&(received."agreement_issue"=""),"An ordinary complete handoff and receipt must finish without an agreement warning.")
    Do ..Check((balance."physical_unknown_quantity"="0")&&(allocation.Quantity=20)&&(need.CommittedQuantity=20)&&(need.RequestedQuantity-need.CommittedQuantity-need.HeldQuantity=30)&&(food.CollectedQuantity=20)&&(food.CurrentQuantity-food.CollectedQuantity-food.CommittedQuantity-food.HeldQuantity=20),"A complete receipt preserves the promise, consumes twenty meals of the receiving need, and leaves only twenty usable boxes at the kitchen.")

    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"20"),stamp=##class(Allfedo.Policy).NowISO()
    Set handoff=..Run(ids.kitchen,"recovery-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"20","occurred_at":(stamp),"note":"Twenty sealed boxes handed to the assigned collector."})
    Do ..Check(handoff.ok,"The actual twenty-box handoff must be recorded.")
    Set receipt=..Run(ids.recipient,"recovery-receipt","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"18","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Eighteen boxes accepted; collector is checking the other two."})
    Do ..Check(receipt.ok,"Actual accepted food must remain distinct from missing food.")
    Set lost=..Run(ids.collector,"recovery-loss","record_disposition",{"allocation_id":(allocationId),"revision":6,"quantity":"2","outcome":"lost","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Two boxes were lost during the trip; they were not delivered or returned."})
    Do ..Check(lost.ok,"The assigned collector can account for a confirmed loss.")
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Do ..Check((need.CommittedQuantity=20)&&(food.CommittedQuantity=0)&&(food.CollectedQuantity=20),"A transit loss cannot restock food or silently decide replacement demand.")
    Set proposed=..Run(ids.coordinator,"settle-known-loss","request_change",{"allocation_id":(allocationId),"revision":7,"new_quantity":"18","reason":"Only eighteen can arrive. Please confirm the full current need before replacement is offered."})
    Do ..Check(proposed.ok&&(proposed."handed_settlement_quantity"="2")&&(proposed."stock_release_quantity"="0"),"Loss settlement must reduce recipient commitment only.")
    Set reply=..Run(ids.recipient,"confirm-replacement-demand","respond_change",{"change_id":(proposed."change_id"),"revision":(proposed."change_revision"),"agree":true,"need_total":"20","need_revision":(need.Revision),"stock_source_id":null,"note":"We still need twenty boxes in total, including the eighteen accepted."})
    Do ..Check(reply.ok&&(reply.state="applied"),"The receiving partner's full current need must authorize replacement capacity.")
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),view=##class(Allfedo.Recovery).View(allocation,##class(Allfedo.Rescue).Actor(ids.recipient))
    Do ..Check((need.RequestedQuantity-need.CommittedQuantity=2)&&(food.CommittedQuantity=0)&&(allocation.CollectedQuantity=20)&&(allocation.OriginalPromiseQuantity=20)&&(allocation.Quantity=18),"The two-box replacement must preserve the original promise and all twenty physical handoffs.")
    Do ..Check((view."physical_unknown_quantity"="0")&&(view."lost_quantity"="2")&&(view."settled_handed_quantity"="2"),"Resolved loss must remain visible in the custody history.")

    Set correctedLoss=..Run(ids.collector,"correct-settled-loss","correct_custody",{"custody_id":(lost."custody_id"),"revision":1,"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"The prior loss report was wrong; the two boxes' current location is unknown."})
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Do ..Check(correctedLoss.ok&&(need.State="review_required"),"Correcting settlement evidence must pause replacement capacity until the recipient confirms its actual need.")

    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"20")
    Set zero=..Run(ids.recipient,"zero-accepted","receive",{"allocation_id":(allocationId),"revision":4,"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"No boxes accepted yet; this is an actual receiving count."})
    Set again=..Run(ids.recipient,"no-second-initial-count","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Repeated initial count."})
    Do ..Check(zero.ok&&'again.ok,"A zero receiving count is still a report; use an addition or explicit correction next.")
    Set correction=..Run(ids.recipient,"correct-zero-count","correct_custody",{"custody_id":(zero."custody_id"),"revision":1,"quantity":"1","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"The earlier count missed one accepted box; the kitchen handoff is still unreported."})
    Do ..Check(correction.ok,"The owning receiving partner can correct its physical report without deleting the original source.")
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),view=##class(Allfedo.Recovery).View(allocation,##class(Allfedo.Rescue).Actor(ids.recipient))
    Do ..Check(view."receipt_recorded"&&(view."custody_history".%Size()=2)&&(view."unmatched_report_quantity"="1"),"Late unmatched receipt remains visible and requires physical reconciliation.")
    Set future=..Run(ids.kitchen,"no-future-stock","count_stock",{"offer_id":(ids.offer),"revision":1,"on_hand_quantity":"40","occurred_at":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()+600)),"note":"Future physical stock must not affect current availability."})
    Do ..Check('future.ok,"The server must reject future physical observations.")

    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"return-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty boxes handed over."})
    Set returned=..Run(ids.kitchen,"confirmed-return","record_disposition",{"allocation_id":(allocationId),"revision":5,"quantity":"2","outcome":"returned_to_kitchen","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Two boxes physically returned and separated from usable stock."})
    Do ..Check(handed.ok&&returned.ok,"A physical return needs kitchen confirmation.")
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=..Run(ids.kitchen,"count-includes-returns","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"22","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty usable boxes plus two quarantined returned boxes are physically present."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Do ..Check(counted.ok&&(food.QuarantinedQuantity=2)&&(food.CurrentQuantity-food.CollectedQuantity=20),"Counting returned boxes must never make them available for another invitation.")
    Set disposal=..Run(ids.kitchen,"dispose-confirmed-quarantine","dispose_quarantined",{"offer_id":(ids.offer),"revision":(food.Revision),"quantity":"2","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"The quarantined returned food was disposed of at the kitchen."})
    Set history=##class(Allfedo.Recovery).History(ids.offer,##class(Allfedo.Rescue).Actor(ids.kitchen))
    Do ..Check(disposal.ok&&(history.%Size()=3),"Lot-level quarantine disposal stays visible and correctable through shared history.")

    // Counts are physically ordered by their full timestamps, never integer seconds or source IDs.
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids."second_offer")
    Set second=$Extract(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()-10),1,19)
    Set newer=..Run(ids."second_kitchen","newer-fraction-count","count_stock",{"offer_id":(food.%Id()),"revision":(food.Revision),"on_hand_quantity":"30","occurred_at":(second_".900000Z"),"note":"First report has the later physical instant."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",food.%Id())
    Set older=..Run(ids."second_kitchen","older-fraction-count","count_stock",{"offer_id":(food.%Id()),"revision":(food.Revision),"on_hand_quantity":"35","occurred_at":(second_".100000Z"),"note":"This arrives later but describes an earlier count."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",food.%Id())
    Do ..Check(newer.ok&&older.ok&&'older."observation_applied"&&(food.ObservedQuantity=30),"An older same-second report cannot replace a newer physical count.")
    Set conflict=..Run(ids."second_kitchen","conflicting-same-time-count","count_stock",{"offer_id":(food.%Id()),"revision":(food.Revision),"on_hand_quantity":"29","occurred_at":(second_".900000Z"),"note":"A different count claims the exact same physical instant."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",food.%Id()),projected=##class(Allfedo.Rescue).Parse(food.StockProjectionJSON)
    Do ..Check(conflict.ok&&projected."review_required"&&(projected."usable_on_hand_quantity"="0"),"Equal-time conflicting counts require a later recount.")
    Do ..Setup(.ids)
    Set now=##class(Allfedo.Policy).Now(),need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set opening=..Run(ids.recipient,"later-receiving-opening","update_need",{"need_id":(ids.need),"revision":(need.Revision),"quantity":"20","unit":"meal_box","receiving_from":(##class(Allfedo.Policy).ISO(now+300)),"receiving_until":(##class(Allfedo.Policy).ISO(now+4500)),"confirmed_until":(##class(Allfedo.Policy).ISO(now+4000)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(##class(Allfedo.Policy).NowISO())})
    Do ..Check(opening.ok,"The partner can state an actual later opening time.")
    Set allocationId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"early-actual-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"1","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"One box was physically handed over."})
    Set early=..Run(ids.recipient,"early-actual-receipt","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"1","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"A staff member actually accepted one box before the agreed opening."})
    Do ..Check(handed.ok&&early.ok&&(early."received_quantity"="1")&&(early."agreement_issue"["outside"),"A real early receipt stays recorded and visibly flags the unmet receiving agreement.")
    Quit {"ok":true,"checks":"known loss and recipient-confirmed replacement, original promises, zero receipt, correction history, future rejection, quarantine excluded from stock, fractional count ordering"}
}

/// Redirect preserves one physical kitchen handoff while a new receiving partner makes its own promise.
ClassMethod TestRedirect() As %DynamicObject
{
    Do ..Setup(.ids)
    Set parentId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"redirect-original-handoff","handoff",{"allocation_id":(parentId),"revision":4,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty boxes physically handed to the collector."})
    Do ..Check(handed.ok,"The redirect needs actual recorded food custody.")
    Set original=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),oldTrip=original.OriginalTripJSON
    Set oldContact=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.recipient),oldContact.Active=0
    Do ##class(Allfedo.Rescue).Save(oldContact)
    Set oldKitchen=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.kitchen),oldKitchen.Active=0
    Do ##class(Allfedo.Rescue).Save(oldKitchen)
    Set issue=..Run(ids.collector,"destination-closed","record_destination_issue",{"allocation_id":(parentId),"revision":5,"quantity_in_custody":"20","current_location":"Parked at the original site's private delivery entrance","handling_maintained":true,"note":"Original receiving contact cannot be reached; no food was handed to that site."})
    Do ..Check(issue.ok&&(issue.state="destination_issue"),"A current destination failure must create an immediate coordinator task.")
    Set target=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."second_need")
    Set offered=..Run(ids.coordinator,"invite-new-receiver","redirect",{"allocation_id":(parentId),"revision":(issue.revision),"target_need_id":(target.%Id()),"target_need_revision":(target.Revision),"quantity":"15","reason":"Ask the other confirmed receiving partner to take food already with the collector."})
    Do ..Check(offered.ok,"A coordinator must be able to offer already-collected food without the unreachable old recipient.")
    Set childId=offered."child_allocation_id",third=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need")
    Set competing=..Run(ids.coordinator,"no-double-redirect","redirect",{"allocation_id":(parentId),"revision":(offered.revision),"target_need_id":(third.%Id()),"target_need_revision":(third.Revision),"quantity":"6","reason":"This would exceed the five boxes not held by the first invitation."})
    Do ..Check('competing.ok,"Two pending redirect invitations must not reserve the same physical food.")
    Set accepted=..Run(ids."second_recipient","new-receiver-partial-accept","accept",{"allocation_id":(childId),"revision":1,"quantity":"10","context_key":(..ContextKey(childId))})
    Do ..Check(accepted.ok&&(accepted."collected_quantity"="10"),"Partial target acceptance must transfer only its agreed food and release the unused invitation hold.")
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",childId),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),oldNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set balance=##class(Allfedo.Recovery).Balance(parent),childView=##class(Allfedo.Recovery).View(child,##class(Allfedo.Rescue).Actor(ids."second_recipient"))
    Do ..Check((parent.TransferredOutQuantity=10)&&(child.TransferredInQuantity=10)&&(balance."physical_unknown_quantity"="10")&&(child.StockCommittedQuantity=0)&&(food.CollectedQuantity=20)&&(food.CommittedQuantity=0)&&(food.HeldQuantity=0),"Transfer must not create stock, count another kitchen collection, or lose remaining collector custody.")
    Do ..Check((childView."kitchen_handoff_quantity"="0")&&'childView.redirect."parent_readable"&&'childView."current_context".details.custody.%IsDefined("location")&&(childView.redirect.children.%Size()=0),"The new receiving partner must not receive the old destination, private location, or sibling details.")
    Do ..Check((oldNeed.State="availability_review")&&(parent.OriginalTripJSON=oldTrip),"The old need stays unavailable for new plans; its immutable original ticket stays unchanged.")
    Set now=##class(Allfedo.Policy).Now(),trip={"allocation_id":(childId),"revision":2,"context_key":(..ContextKey(childId)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1200)),"capacity":"10","handling_accepted":true}
    Set tooSmall=..Run(ids.collector,"capacity-covers-whole-carried-load","confirm_redirect",trip)
    Do ..Check('tooSmall.ok,"Redirecting ten of twenty boxes does not shrink the physical carried load to ten.")
    Set trip.capacity="20",confirmed=..Run(ids.collector,"agree-new-destination","confirm_redirect",trip)
    Do ..Check(confirmed.ok,"The same collector can agree the new destination and whole carried load without another kitchen pickup.")
    Set received=..Run(ids."second_recipient","new-destination-receipt","receive",{"allocation_id":(childId),"revision":3,"quantity":"10","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Ten transferred boxes accepted at the new destination."})
    Do ..Check(received.ok&&(received.state="received"),"The new receiving partner confirms its own actual receipt.")
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Do ..Check((food.CollectedQuantity=20)&&(food.CurrentQuantity-food.CollectedQuantity=20),"Receipt at a redirected site cannot produce another kitchen collection or free returned food.")
    Set ownLocation="Collector is now at the dispatch office after this receiving stop"
    Set childIssue=..Run(ids.collector,"onward-site-now-closed","record_destination_issue",{"allocation_id":(childId),"revision":(received.revision),"quantity_in_custody":"0","current_location":(ownLocation),"handling_maintained":true,"note":"This receiving site has closed after accepting its food; no further arrivals are possible."})
    Set child=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",childId),current=##class(Allfedo.Recovery).CurrentContext(child),ticket=##class(Allfedo.Rescue).Parse(child.OriginalTripJSON)
    Do ..Check(childIssue.ok&&(current.details.custody.location=ownLocation)&&(current.details.pickup.%ToJSON()=ticket.details.pickup.%ToJSON()),"An onward case's newer custody report must replace its parent's old location while preserving the immutable kitchen origin.")
    Set inactiveTarget=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids."third_recipient"),inactiveTarget.Active=0
    Do ##class(Allfedo.Rescue).Save(inactiveTarget)
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),target=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need")
    Set noContact=..Run(ids.coordinator,"no-silent-invitation-to-inactive-contact","redirect",{"allocation_id":(parentId),"revision":(parent.Revision),"target_need_id":(target.%Id()),"target_need_revision":(target.Revision),"quantity":"10","reason":"The target has capacity but must confirm a current duty contact."})
    Do ..Check('noContact.ok&&(noContact.error.message["current contact"),"A new redirect invitation must not save a hold while silently skipping an inactive target contact.")

    Do ..Setup(.ids)
    Set parentId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"partial-before-destination-failure","handoff",{"allocation_id":(parentId),"revision":4,"quantity":"15","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Fifteen collected; five promised boxes remain with the kitchen."})
    Set issue=..Run(ids.collector,"partial-destination-closed","record_destination_issue",{"allocation_id":(parentId),"revision":5,"quantity_in_custody":"15","current_location":"Waiting with fifteen boxes in the vehicle","handling_maintained":true,"note":"The original destination is unavailable."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=..Run(ids.kitchen,"confirm-remaining-physical-stock","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"25","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty-five usable boxes are here, including the five in the old promise; none are returns."})
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId)
    Set released=..Run(ids.coordinator,"cancel-unavailable-kitchen-remainder","release_unavailable",{"allocation_id":(parentId),"revision":(parent.Revision),"stock_source_id":(counted."source_id"),"quantity":"5","reason":"The destination is unavailable; kitchen confirmed actual custody of the unhanded portion. This is coordinator cancellation, not recipient consent."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId),oldNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Do ..Check(handed.ok&&issue.ok&&counted.ok&&released.ok&&(food.CollectedQuantity=15)&&(food.CommittedQuantity=0)&&(parent.Quantity=15)&&(parent.StockCommittedQuantity=0)&&(oldNeed.State="availability_review"),"An unavailable recipient cannot strand kitchen-held food; only the confirmed unhanded promise is cancelled.")
    Set broken=..Run(ids.collector,"report-handling-break","record_destination_issue",{"allocation_id":(parentId),"revision":(parent.Revision),"quantity_in_custody":"15","current_location":"Vehicle waiting for safe disposal instructions","handling_maintained":false,"note":"The required holding conditions were not maintained."})
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId)
    Set later=..Run(ids.collector,"later-cooling-cannot-erase-break","record_destination_issue",{"allocation_id":(parentId),"revision":(parent.Revision),"quantity_in_custody":"15","current_location":"Vehicle after conditions changed again","handling_maintained":true,"note":"Conditions are restored now; this cannot erase the earlier recorded break."})
    Set parent=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",parentId)
    Do ..Check(broken.ok&&later.ok&&(##class(Allfedo.Redirect).Available(parent)=0),"A reported handling break cannot be cleared automatically by a later attestation.")
    Quit {"ok":true,"checks":"unreachable destination, need-only invitations, duplicate custody holds, partial target acceptance, immutable origin, recipient privacy, whole carried capacity, actual redirected receipt, kitchen-only cancellation, handling-break guard"}
}

/// Later return/disposal moves only its linked rejected portion, never another rejection or fresh stock.
ClassMethod TestRejectedTransfer() As %DynamicObject
{
    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"20")
    Set handed=..Run(ids.kitchen,"rejected-transfer-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"20","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty meal boxes handed over."})
    Set received=..Run(ids.recipient,"rejected-transfer-receipt","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"18","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Eighteen accepted; two unusable boxes kept separately here."})
    Set rejected=..Run(ids.recipient,"rejected-kept-at-site","record_disposition",{"allocation_id":(allocationId),"revision":6,"quantity":"2","outcome":"rejected_at_site","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Two unusable boxes are physically kept at this receiving site."})
    Do ..Check(handed.ok&&received.ok&&rejected.ok,"The linked movement requires an actual rejection and custody history.")
    Set originId=rejected."custody_id",body={"custody_id":(originId),"revision":1,"quantity":"1","outcome":"returned_to_kitchen","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"One rejected box physically arrived back at the kitchen and was quarantined."}
    Set forbidden=..Run(ids.collector,"collector-cannot-claim-kitchen-arrival","transfer_rejected",body)
    Do ..Check('forbidden.ok,"Only the kitchen can confirm food actually arrived back there.")
    Set moved=..Run(ids.kitchen,"rejected-box-arrived-back","transfer_rejected",body)
    Set body.outcome="disposed_at_recipient",body."occurred_at"=##class(Allfedo.Policy).NowISO(),body.note="The other rejected box was disposed of at the receiving site."
    Set disposed=..Run(ids.recipient,"rejected-box-disposed-at-site","transfer_rejected",body)
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),origin=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",originId)
    Do ..Check(moved.ok&&disposed.ok&&(allocation.AccountedQuantity=2)&&(allocation.RejectedQuantity=0)&&(allocation.ReturnedQuantity=1)&&(allocation.DisposedQuantity=1)&&(allocation.ReceivedQuantity=18),"The original rejected two must be accounted once after one return and one disposal; accepted food remains eighteen.")
    Do ..Check((food.QuarantinedQuantity=1)&&(food.CurrentQuantity-food.CollectedQuantity=20)&&(origin.Active=1)&&(origin.Quantity=2),"Returning rejected food keeps it unavailable and preserves the original rejection source.")
    Set corrected=..Run(ids.recipient,"correct-rejected-disposal-count","correct_custody",{"custody_id":(disposed."custody_id"),"revision":1,"quantity":"0","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"The disposal count was wrong; that box is still kept separately here."})
    Set current=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",corrected."custody_id"),allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Check(corrected.ok&&(current.FromCustodyId=originId)&&(allocation.RejectedQuantity=1)&&(allocation.ReturnedQuantity=1)&&(allocation.DisposedQuantity=0)&&(allocation.AccountedQuantity=2),"A correction retains the physical portion link and restores only the corrected rejected remainder.")
    Set origin=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",originId)
    Do ..Check(##class(Allfedo.Recovery).CanTransfer(##class(Allfedo.Rescue).Actor(ids.recipient),origin,"disposed_at_recipient")&&'##class(Allfedo.Recovery).CanTransfer(##class(Allfedo.Rescue).Actor(ids.collector),origin,"returned_to_kitchen"),"Shared history permissions must match the physical reporting parties.")
    Set body."occurred_at"=##class(Allfedo.Policy).NowISO(),body.note="That remaining rejected box has now actually been disposed of here."
    Set disposed=..Run(ids.recipient,"later-actual-disposal","transfer_rejected",body)
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
    Set counted=..Run(ids.kitchen,"count-includes-linked-return","count_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"on_hand_quantity":"21","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Twenty usable boxes plus one quarantined returned box are physically here."})
    Set food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId)
    Do ..Check(disposed.ok&&counted.ok&&(food.QuarantinedQuantity=1)&&(food.CurrentQuantity-food.CollectedQuantity=20)&&(allocation.AccountedQuantity=2)&&(allocation.ReceivedQuantity=18),"Neither linked disposition nor a later stock count can restock returned food or create another meal accepted.")
    Set origin=##class(Allfedo.Rescue).Open("Allfedo.Record.Custody",originId)
    Do ..Check(##class(Allfedo.Recovery).RejectedRemaining(origin)=0,"The earlier linked movements explain the full original rejected portion.")
    Set extra=..Run(ids.kitchen,"unexpected-return-after-complete-movement","transfer_rejected",{"custody_id":(originId),"revision":1,"quantity":"1","outcome":"returned_to_kitchen","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Another box actually arrived against the same reference after all earlier rejected boxes had been accounted for."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),food=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer),balance=##class(Allfedo.Recovery).Balance(allocation)
    Do ..Check(extra.ok&&extra."physical_report_saved"&&(allocation.ReturnedQuantity=2)&&(allocation.AccountedQuantity=3)&&(balance."unmatched_report_quantity"="1")&&(allocation.State="custody_review")&&(food.QuarantinedQuantity=2),"Zero expected remainder cannot erase a later actual arrival; preserve it quarantined and flag the excess for review.")

    Do ..Setup(.ids)
    Set allocationId=..ReadyCase(ids,"15")
    Set handed=..Run(ids.kitchen,"two-portions-handoff","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"15","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Fifteen boxes handed over."})
    Set first=..Run(ids.recipient,"first-rejected-portion","record_disposition",{"allocation_id":(allocationId),"revision":5,"quantity":"5","outcome":"rejected_at_site","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"First rejected portion contains five boxes."})
    Set second=..Run(ids.recipient,"second-rejected-portion","record_disposition",{"allocation_id":(allocationId),"revision":6,"quantity":"10","outcome":"rejected_at_site","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"A separate rejected portion contains ten boxes."})
    Set excess=..Run(ids.kitchen,"actual-overreported-return","transfer_rejected",{"custody_id":(first."custody_id"),"revision":1,"quantity":"8","outcome":"returned_to_kitchen","occurred_at":(##class(Allfedo.Policy).NowISO()),"note":"Eight actually arrived bearing the first portion's reference; its original count needs review."})
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),balance=##class(Allfedo.Recovery).Balance(allocation)
    Do ..Check(handed.ok&&first.ok&&second.ok&&excess.ok&&(allocation.RejectedQuantity=10)&&(allocation.ReturnedQuantity=8)&&(allocation.AccountedQuantity=18)&&(balance."unmatched_report_quantity"="3")&&(allocation.State="custody_review"),"An over-return from portion five cannot consume three boxes from an unrelated rejection of ten; preserve the real eight and flag the conflict.")
    Quit {"ok":true,"checks":"linked return and local disposal, single accounting, immutable rejection, source correction link, actor permissions, quarantine never restocked, independent rejected portions and over-report review"}
}

ClassMethod ReadyCase(ids As %DynamicObject, quantity As %String) As %String
{
    Set held=..Run(ids.coordinator,"recovery-plan","apply_plan",..Plan(ids.coordinator,ids.offer,ids.need,quantity))
    Do ..Check(held.ok,"Recovery fixture requires a valid hold.")
    Set allocationId=held."allocation_ids".%Get(0)
    Set accepted=..Run(ids.recipient,"recovery-accept","accept",{"allocation_id":(allocationId),"revision":1,"quantity":(quantity),"context_key":(..ContextKey(allocationId))})
    Set assigned=..Run(ids.coordinator,"recovery-assign","assign_collector",{"allocation_id":(allocationId),"revision":2,"collector_actor_id":(ids.collector)})
    Set now=##class(Allfedo.Policy).Now()
    Set trip=..Run(ids.collector,"recovery-trip","confirm_transport",{"allocation_id":(allocationId),"revision":3,"pickup_at":(##class(Allfedo.Policy).ISO(now+30)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":(quantity),"handling_accepted":true,"context_key":(..ContextKey(allocationId))})
    Do ..Check(accepted.ok&&assigned.ok&&trip.ok,"Recovery fixture requires an accepted promise and a collector's actual agreement.")
    Quit allocationId
}

/// Two real IRIS processes compete after a barrier. Run both shared-need and shared-stock cases.
ClassMethod TestRaces() As %DynamicObject
{
    Do ..Setup(.ids)
    Set first=..Plan(ids.coordinator,ids.offer,ids.need,"35"), second=..Plan(ids.coordinator,ids."second_offer",ids.need,"35")
    Set needRace=..Race(ids.coordinator,first,second)
    Set need=##class(Allfedo.Record.Need).%OpenId(ids.need)
    Do ..Check(needRace.winners=1&&(need.HeldQuantity=35),"Concurrent kitchens must never exceed one shared receiving need.")
    Do ..Setup(.ids)
    // Both needs can individually receive 35, but this lot contains only 40 boxes.
    Set need=##class(Allfedo.Record.Need).%OpenId(ids."second_need"), need.RequestedQuantity=50
    Do ##class(Allfedo.Rescue).Save(need)
    Set first=..Plan(ids.coordinator,ids.offer,ids.need,"35"), second=..Plan(ids.coordinator,ids.offer,ids."second_need","35")
    Set stockRace=..Race(ids.coordinator,first,second)
    Set offer=##class(Allfedo.Record.Offer).%OpenId(ids.offer)
    Do ..Check(stockRace.winners=1&&(offer.HeldQuantity=35),"Concurrent recipients must never exceed one lot's stock.")
    Quit {"ok":true,"shared_need":(needRace),"shared_stock":(stockRace)}
}

ClassMethod Race(actorId As %String, first As %DynamicObject, second As %DynamicObject) As %DynamicObject
{
    Set token="race-"_$Job_"-"_$Increment(^Allfedo.Test.Sequence)
    Set ^Allfedo.Test.Race(token,"ready")=0
    Job ..RaceWorker(token,1,actorId,first.%ToJSON())::5
    Do ..Check($Test,"The first native race worker could not start.")
    Job ..RaceWorker(token,2,actorId,second.%ToJSON())::5
    Do ..Check($Test,"The second native race worker could not start.")
    For attempt=1:1:200 { Quit:$Get(^Allfedo.Test.Race(token,"ready"))=2  Hang .025 }
    Do ..Check($Get(^Allfedo.Test.Race(token,"ready"))=2,"Native race workers did not reach the barrier.")
    Set ^Allfedo.Test.Race(token,"go")=1
    For attempt=1:1:400 { Quit:$Data(^Allfedo.Test.Race(token,"result",1))&&$Data(^Allfedo.Test.Race(token,"result",2))  Hang .025 }
    Do ..Check($Data(^Allfedo.Test.Race(token,"result",1))&&$Data(^Allfedo.Test.Race(token,"result",2)),"Native race workers did not finish.")
    Set firstResult=##class(Allfedo.Rescue).Parse(^Allfedo.Test.Race(token,"result",1)), secondResult=##class(Allfedo.Rescue).Parse(^Allfedo.Test.Race(token,"result",2))
    Set result={"winners":(firstResult.ok+secondResult.ok),"first":(firstResult),"second":(secondResult)}
    Kill ^Allfedo.Test.Race(token)
    Quit result
}

ClassMethod RaceWorker(token As %String, number As %Integer, actorId As %String, planJSON As %String)
{
    Set ready=$Increment(^Allfedo.Test.Race(token,"ready"))
    For attempt=1:1:400 { Quit:$Get(^Allfedo.Test.Race(token,"go"))  Hang .025 }
    If '$Get(^Allfedo.Test.Race(token,"go")) Quit
    Try {
        Set ^Allfedo.Test.Race(token,"result",number)=##class(Allfedo.Rescue).Execute(actorId,token_"-"_number,"apply_plan",planJSON)
    } Catch error {
        Set ^Allfedo.Test.Race(token,"result",number)={"ok":false,"error":{"message":(error.DisplayString())}}.%ToJSON()
    }
}

/// No provider call. Run with the real Production alive: short-lived callers alone cannot expose worker-owned lock leaks.
ClassMethod TestProductionLocks() As %DynamicObject
{
    Set principal=$USERNAME
    Do ..Check((principal'="")&&(principal'="UnknownUser"),"Use an authenticated test principal.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Actor WHERE UserName=?",principal)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check('query.%Next(),"This principal already has an Allfedo membership; use a dedicated test principal.")
    Do ..Setup(.ids)
    Set kitchen=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.kitchen), kitchenLogin=kitchen.UserName
    Set recipient=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.recipient), recipientLogin=recipient.UserName
    Set kitchen.UserName=principal
    Do ##class(Allfedo.Rescue).Save(kitchen)
    Set caught="", summary={}
    Try {
        Set status=##class(Ens.Director).CreateBusinessService("Allfedo.Commands",.service)
        If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
        For number=1:1:2 {
            Set site=##class(Allfedo.Facts).SiteFor(ids.network,kitchen.OrganizationId)
            Set body={"revision":(site.Revision),"name":(site.Name),"address":(site.Address),"entrance":(site.Entrance),"time_zone":(site.TimeZone),"contact_phone":(site.ContactPhone)}
            Set result=..ProductionCommand(service,ids.kitchen,"persistent-site-"_number,"save_site",body,.siteWorkers)
            Do ..Check(result.ok,"A persistent worker kept the site's resource lock after an earlier command.")
            Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
            Set body={"offer_id":(ids.offer),"revision":(offer.Revision),"ready_at":(##class(Allfedo.Policy).ISO(offer.ReadyAt)),"collect_by":(##class(Allfedo.Policy).ISO(offer.CollectBy)),"holding":(offer.Holding),"handling_until":(##class(Allfedo.Policy).ISO(offer.HandlingUntil)),"packaging":(offer.Packaging),"present_allergens":(##class(Allfedo.Rescue).ParseArray(offer.PresentAllergensJSON)),"assessed_allergens":(##class(Allfedo.Rescue).ParseArray(offer.AssessedAllergensJSON)),"event_at":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()))}
            Set result=..ProductionCommand(service,ids.kitchen,"persistent-offer-"_number,"confirm_food",body,.offerWorkers)
            Do ..Check(result.ok,"A persistent worker kept the offer's resource lock after an earlier command.")
        }
        Set kitchen.UserName=kitchenLogin
        Do ##class(Allfedo.Rescue).Save(kitchen)
        Set recipient.UserName=principal
        Do ##class(Allfedo.Rescue).Save(recipient)
        For number=1:1:2 {
            Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
            Set body={"need_id":(ids.need),"revision":(need.Revision),"quantity":(""_need.RequestedQuantity),"unit":(need.Unit),"receiving_from":(##class(Allfedo.Policy).ISO(need.ReceivingFrom)),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(need.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(need.AcceptedHoldingJSON)),"event_at":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()))}
            Set result=..ProductionCommand(service,ids.recipient,"persistent-need-"_number,"update_need",body,.needWorkers)
            Do ..Check(result.ok,"A persistent worker kept the receiving need's lock after an earlier command.")
        }
        Set siteCount=..WorkerCount(.siteWorkers), offerCount=..WorkerCount(.offerWorkers), needCount=..WorkerCount(.needWorkers)
        Do ..Check((siteCount>=1)&&(offerCount>=1)&&(needCount>=1),"Every resource must have an actual recorded Production worker.")
        Set keys("site:" _ ids.network _ ":" _ kitchen.OrganizationId)=1, keys("offer:"_ids.offer)=1, keys("need:"_ids.need)=1, key=""
        For {
            Set key=$Order(keys(key))
            Quit:key=""
            Lock +^Allfedo.Lock(key):0
            Set free=$Test
            If free { Lock -^Allfedo.Lock(key) }
            Do ..Check(free,"A completed Production command still owns a resource lock.")
        }
        Set summary={"ok":true,"site_worker_count":(siteCount),"offer_worker_count":(offerCount),"need_worker_count":(needCount),"commands":6,"checks":"actual Production, principal binding, recorded worker differs from caller, same site/offer/need, external caller acquired locks while Production stayed running"}
    } Catch error {
        Set caught=error
    }
    Set kitchen=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.kitchen), kitchen.UserName=kitchenLogin
    Do ##class(Allfedo.Rescue).Save(kitchen)
    Set recipient=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.recipient), recipient.UserName=recipientLogin
    Do ##class(Allfedo.Rescue).Save(recipient)
    If $IsObject(caught) Throw caught
    Quit summary
}

ClassMethod ProductionCommand(service As Allfedo.CommandService, actorId As %String, requestId As %String, action As %String, body As %DynamicObject, ByRef workers) As %DynamicObject
{
    Set request=##class(Allfedo.Message.CommandRequest).%New()
    Set request.RequestId=requestId, request.Action=action, request.PayloadJSON=body.%ToJSON()
    Set status=service.ProcessInput(request,.response)
    If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
    Set outcome=##class(Allfedo.Rescue).Parse(response.ResultJSON)
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT WorkerJob FROM Allfedo_Record.Command WHERE ActorId=? AND RequestId=?",actorId,requestId)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check(query.%Next(),"Every successful Production command must have a saved audit record.")
    Do ..Check((query.WorkerJob'="")&&(query.WorkerJob'=(""_$Job)),"The command must run on a recorded Production worker, separate from this caller.")
    Set workers(query.WorkerJob)=1
    Quit outcome
}

ClassMethod WorkerCount(ByRef workers) As %Integer
{
    Set count=0, worker=""
    For {
        Set worker=$Order(workers(worker))
        Quit:worker=""
        Set count=count+1
    }
    Quit count
}

/// A short lock timeout is recoverable with the same request ID, rather than a permanent rejection.
ClassMethod TestBusyRecovery() As %DynamicObject
{
    Do ..Setup(.ids)
    Set plan=..Plan(ids.coordinator,ids.offer,ids.need,"25"), token="busy-"_$Job_"-"_$Increment(^Allfedo.Test.Sequence)
    Job ..HoldOffer(token,ids.offer)::5
    Do ..Check($Test,"The native lock worker could not start.")
    For attempt=1:1:200 { Quit:$Get(^Allfedo.Test.Busy(token,"ready"))  Hang .025 }
    Do ..Check($Get(^Allfedo.Test.Busy(token,"ready")),"The native lock worker did not become ready.")
    Set blocked=..Run(ids.coordinator,"retry-after-lock","apply_plan",plan)
    Set ^Allfedo.Test.Busy(token,"release")=1
    For attempt=1:1:200 { Quit:$Get(^Allfedo.Test.Busy(token,"done"))  Hang .025 }
    Do ..Check($Get(^Allfedo.Test.Busy(token,"done")),"The native lock worker did not release its lock.")
    Do ..Check('blocked.ok&&(blocked.error.code="BUSY"),"Lock contention must return unsaved BUSY.")
    Set recovered=..Run(ids.coordinator,"retry-after-lock","apply_plan",plan)
    Do ..Check(recovered.ok,"The same request ID must succeed after the lock clears.")
    Kill ^Allfedo.Test.Busy(token)
    Quit {"ok":true,"blocked":(blocked),"recovered":(recovered)}
}

ClassMethod HoldOffer(token As %String, offerId As %String)
{
    Set key="offer:"_offerId
    Lock +^Allfedo.Lock(key):5
    If '$Test Quit
    Set ^Allfedo.Test.Busy(token,"ready")=1
    For attempt=1:1:600 { Quit:$Get(^Allfedo.Test.Busy(token,"release"))  Hang .025 }
    Lock -^Allfedo.Lock(key)
    Set ^Allfedo.Test.Busy(token,"done")=1
}

/// PAID OPT-IN CHECK: root invokes this explicitly after starting Allfedo.Production. Never run in the ordinary checks.
/// Temporarily bind only the new synthetic coordinator, and refuse to change any existing principal membership.
ClassMethod ProveProductionWithModel() As %DynamicObject
{
    Set principal=$USERNAME
    Do ..Check((principal'="")&&(principal'="UnknownUser"),"Use an authenticated native principal for this opt-in proof.")
    Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT ID FROM Allfedo_Record.Actor WHERE UserName=?",principal)
    Do ##class(Allfedo.Rescue).QueryOK(query)
    Do ..Check('query.%Next(),"This principal already has an Allfedo membership. Use a dedicated test principal instead.")
    Do ..Setup(.ids)
    Set coordinator=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.coordinator), originalLogin=coordinator.UserName
    Set coordinator.UserName=principal
    Do ##class(Allfedo.Rescue).Save(coordinator)
    Set caught="", result=""
    Try {
        Set status=##class(Ens.Director).CreateBusinessService("Allfedo.Commands",.service)
        If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
        Set request=##class(Allfedo.Message.CommandRequest).%New()
        Set request.RequestId="proof-plan", request.Action="plan_offer", request.PayloadJSON={"offer_id":(ids.offer)}.%ToJSON()
        Set status=service.ProcessInput(request,.response)
        If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
        Set proposal=##class(Allfedo.Rescue).Parse(response.ResultJSON)
        Do ..Check(proposal.ok&&(proposal.state="proposed"),"The native agent did not save a valid proposal; inspect its sanitized AgentRun diagnostics.")
        Set run=##class(Allfedo.Rescue).Open("Allfedo.Record.AgentRun",proposal."run_id")
        Do ..Check((run.Outcome="proposed")&&(run.ProposalJSON'=""),"The native proposal must be saved before showing it for review.")
        Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
        Do ..Check((offer.HeldQuantity=0)&&(offer.CommittedQuantity=0),"Planning must not hold or reserve any food.")
        Set request=##class(Allfedo.Message.CommandRequest).%New()
        Set request.RequestId="proof-send-after-review", request.Action="apply_plan", request.PayloadJSON=proposal.proposal.%ToJSON()
        Set status=service.ProcessInput(request,.response)
        If $SYSTEM.Status.IsError(status) Throw ##class(%Exception.StatusException).CreateFromStatus(status)
        Set sent=##class(Allfedo.Rescue).Parse(response.ResultJSON)
        Do ..Check(sent.ok,"The coordinator's separate send action must apply the current safe plan.")
        Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",ids.offer)
        Do ..Check(offer.HeldQuantity>0,"Explicit sending must save guarded food holds.")
        For index=0:1:sent."allocation_ids".%Size()-1 {
            Set id=sent."allocation_ids".%Get(index), allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",id)
            Do ..Check(allocation.State="held","An invitation is a temporary hold, never a confirmed pickup.")
            Set query=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) AS Total FROM Allfedo_Record.Outbox WHERE AllocationId=?",id)
            Do ##class(Allfedo.Rescue).QueryOK(query)
            Do ..Check(query.%Next()&&(query.Total=1),"Every saved invitation must have one notification intention.")
        }
        Set result={"ok":true,"run_id":(proposal."run_id"),"held_quantity":(""_offer.HeldQuantity),"send_result":(sent),"fixture":(ids),"note":"Paid native Production chain proved; recipient acceptance, SMTP acknowledgement and custody are separate checks."}
    } Catch error {
        Set caught=error
    }
    Set coordinator=##class(Allfedo.Rescue).Open("Allfedo.Record.Actor",ids.coordinator), coordinator.UserName=originalLogin
    Do ##class(Allfedo.Rescue).Save(coordinator)
    If $IsObject(caught) Throw caught
    Quit result
}

/// No provider call. Supplies the exact proposal contract for manual plans and native race workers.
ClassMethod Plan(coordinatorId As %String, offerId As %String, needId As %String, quantity As %String) As %DynamicObject
{
    Set snapshot=##class(Allfedo.Rescue).Snapshot(coordinatorId,offerId), selected=""
    For i=0:1:snapshot.needs.%Size()-1 { Set item=snapshot.needs.%Get(i) If item.id=needId Set selected=item }
    Do ..Check($IsObject(selected),"The requested need is not in this network.")
    Set evidence=[]
    For sourceIndex=0:1:snapshot.offer."source_ids".%Size()-1 { Do evidence.%Push(snapshot.offer."source_ids".%Get(sourceIndex),"string") }
    For sourceIndex=0:1:selected."source_ids".%Size()-1 { Do evidence.%Push(selected."source_ids".%Get(sourceIndex),"string") }
    Quit {"offer_id":(offerId),"offer_revision":(snapshot.offer.revision),"reason":"Use this partner's current receiving need; collection and handling still require explicit confirmation.","requests":[{"need_id":(needId),"need_revision":(selected.revision),"quantity":(quantity),"unit":"meal_box","evidence_ids":(evidence)}]}
}

ClassMethod Actor(network As %String, role As %String, organization As %String, name As %String) As %String
{
    Set actor=##class(Allfedo.Record.Actor).%New()
    Set actor.NetworkId=network, actor.Role=role, actor.OrganizationId=organization, actor.DisplayName=name, actor.UserName=network_"-"_role_"-"_organization, actor.Email=organization_"@example.test"
    Do ##class(Allfedo.Rescue).Save(actor)
    Quit ""_actor.%Id()
}

ClassMethod ContextKey(allocationId As %String) As %String
{
    Set allocation=##class(Allfedo.Rescue).Open("Allfedo.Record.Allocation",allocationId),context=##class(Allfedo.Recovery).CurrentContext(allocation)
    Quit context."context_key"
}

ClassMethod Run(actorId As %String, requestId As %String, action As %String, data As %DynamicObject) As %DynamicObject
{
    Quit ##class(Allfedo.Rescue).Parse(##class(Allfedo.Rescue).Execute(actorId,requestId,action,data.%ToJSON()))
}

ClassMethod Check(condition As %Boolean, message As %String)
{
    Do ##class(Allfedo.Rescue).Require(condition,message)
}
}
