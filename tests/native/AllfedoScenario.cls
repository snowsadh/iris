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
    Set now=##class(Allfedo.Policy).Now(), event=##class(Allfedo.Policy).ISO(now)
    Set offer={"description":"Sealed vegetable meal boxes","quantity":"40","unit":"meal_box","ready_at":(##class(Allfedo.Policy).ISO(now-60)),"collect_by":(##class(Allfedo.Policy).ISO(now+3600)),"holding":"chilled","handling_until":(##class(Allfedo.Policy).ISO(now+4200)),"packaging":"Four carry cartons, ten sealed meal boxes each","present_allergens":[],"assessed_allergens":["milk","peanut"],"event_at":(event)}
    Set result=..Run(ids.kitchen,"create-offer","create_offer",offer)
    Do ..Check(result.ok,"Fixture kitchen offer was rejected.")
    Set ids.offer=""_result."offer_id"
    Set result=..Run(ids."second_kitchen","create-offer","create_offer",offer)
    Do ..Check(result.ok,"Second kitchen offer was rejected.")
    Set ids."second_offer"=""_result."offer_id"
    Set need={"quantity":"50","unit":"meal_box","receiving_until":(##class(Allfedo.Policy).ISO(now+4500)),"confirmed_until":(##class(Allfedo.Policy).ISO(now+4000)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(event)}
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
    Set accepted=..Run(ids.recipient,"accept-thirty","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"30"})
    Do ..Check(accepted.ok&&(accepted.state="accepted"),"Recipient acceptance should convert the hold.")
    Set now=##class(Allfedo.Policy).Now()
    Set unassigned=..Run(ids.collector,"cannot-self-claim","confirm_transport",{"allocation_id":(allocationId),"revision":2,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"30","handling_accepted":true})
    Do ..Check('unassigned.ok,"A collector cannot self-claim an unassigned pickup.")
    Set assigned=..Run(ids.coordinator,"assign-known-collector","assign_collector",{"allocation_id":(allocationId),"revision":2,"collector_actor_id":(ids.collector)})
    Do ..Check(assigned.ok,"The coordinator must be able to assign a known network collector.")
    Set trip=..Run(ids.collector,"confirm-own-trip","confirm_transport",{"allocation_id":(allocationId),"revision":3,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"30","handling_accepted":true})
    Do ..Check(trip.ok&&(trip.state="ready"),"A named collector must confirm a compatible trip.")
    Set expired=..Run(ids.coordinator,"never-expire-accepted","expire_hold",{"allocation_id":(allocationId),"revision":4})
    Do ..Check('expired.ok,"An accepted pickup must never auto-release on a timer.")
    Set handoff=..Run(ids.kitchen,"handoff-actual","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"28","note":"Two meal boxes were not present at the loading point. They remain unresolved."})
    Do ..Check(handoff.ok&&(handoff."collected_quantity"="28"),"Handoff must record actual custody.")
    Set receipt=..Run(ids.recipient,"receipt-actual","receive",{"allocation_id":(allocationId),"revision":5,"quantity":"27","note":"One handed-over box was damaged; two promised boxes were never handed over."})
    Do ..Check(receipt.ok&&(receipt."received_quantity"="27")&&(receipt."unresolved_quantity"="3")&&(receipt.state="receipt_issue"),"Receipt cannot turn missing boxes into delivered food.")
    Set forbidden=..Run(ids."second_recipient","other-partner-receipt","receive",{"allocation_id":(allocationId),"revision":6,"quantity":"28","note":""})
    Do ..Check('forbidden.ok,"Another recipient must not act on this collection.")
    Set food=##class(Allfedo.Record.Offer).%OpenId(ids.offer)
    Set observation=..Run(ids.kitchen,"physical-count","observe_stock",{"offer_id":(ids.offer),"revision":(food.Revision),"quantity":"35","note":"Counted the original lot total, including 28 boxes already handed over."})
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
    Set allocationId=held."allocation_ids".%Get(0), accepted=..Run(ids.recipient,"accept-known-food","accept",{"allocation_id":(allocationId),"revision":1,"quantity":"10"})
    Do ..Check(accepted.ok,"The receiving partner must explicitly accept the food.")
    Set assigned=..Run(ids.coordinator,"assign-known-food-trip","assign_collector",{"allocation_id":(allocationId),"revision":2,"collector_actor_id":(ids.collector)})
    Do ..Check(assigned.ok,"The coordinator must assign this collection.")
    Set trip={"allocation_id":(allocationId),"revision":3,"pickup_at":(##class(Allfedo.Policy).ISO(now+60)),"arrival_by":(##class(Allfedo.Policy).ISO(now+1800)),"capacity":"10","handling_accepted":true}
    Set missingPackaging=..Run(ids.collector,"cannot-infer-carrying-fit","confirm_transport",trip)
    Do ..Check('missingPackaging.ok,"A meal-box count cannot establish carrying arrangements when packaging is unknown.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",offerId), confirmation.revision=offer.Revision, confirmation.packaging="Two carry cartons, six sealed meal boxes each"
    Set packed=..Run(ids.kitchen,"confirm-carrying-details","confirm_food",confirmation)
    Do ..Check(packed.ok&&(packed.state="open"),"Adding packaging alone must not rewrite unchanged food conditions or dead-end an existing acceptance.")
    Set ready=..Run(ids.collector,"confirm-informed-trip","confirm_transport",trip)
    Do ..Check(ready.ok,"The assigned collector can confirm actual packaging, capacity, times, and handling.")
    Set offer=##class(Allfedo.Rescue).Open("Allfedo.Record.Offer",offerId), confirmation.revision=offer.Revision, confirmation.packaging="One large insulated carry crate; earlier carton arrangement withdrawn"
    Set changedLoad=..Run(ids.kitchen,"report-changed-confirmed-load","confirm_food",confirmation)
    Do ..Check(changedLoad.ok&&(changedLoad.state="review_required"),"Changing an already confirmed load must pause the earlier pickup agreement.")
    Set pausedLoad=..Run(ids.kitchen,"no-handoff-against-old-load","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"10","note":""})
    Do ..Check('pausedLoad.ok,"A confirmed collector must not inherit a new carrying load without review.")
    Set evidenceSnapshot=##class(Allfedo.Rescue).Snapshot(ids.coordinator,offerId)
    Do ..Check(evidenceSnapshot.offer."source_ids".%Size()=2,"Later food confirmations must preserve the original quantity evidence.")
    Set need=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids.need)
    Set update={"need_id":(ids.need),"revision":(need.Revision),"quantity":"5","unit":"meal_box","receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":[],"accepted_holding":["chilled"],"event_at":(event)}
    Set reduced=..Run(ids.recipient,"report-reduced-actual-need","update_need",update)
    Do ..Check(reduced.ok&&(reduced.state="review_required")&&(reduced."committed_quantity"="10")&&(reduced."shortfall_quantity"="5"),"A reduced actual need must remain truthful while all existing promises remain recorded.")
    Set snapshot=##class(Allfedo.Rescue).Snapshot(ids.coordinator,ids.offer), selected=""
    For index=0:1:snapshot.needs.%Size()-1 { Set item=snapshot.needs.%Get(index) If item.id=ids.need Set selected=item }
    Do ..Check($IsObject(selected)&&(selected."remaining_quantity"="0")&&(selected.state="review_required"),"An oversubscribed need must expose zero remaining capacity, never a negative snapshot.")
    Set otherPlan=..Plan(ids.coordinator,ids.offer,ids."second_need","5"), other=..Run(ids.coordinator,"unaffected-partner-still-works","apply_plan",otherPlan)
    Do ..Check(other.ok,"One partner's changed need must not invalidate the whole network snapshot.")
    Set handoff=..Run(ids.kitchen,"pause-changed-promise","handoff",{"allocation_id":(allocationId),"revision":4,"quantity":"10","note":""})
    Do ..Check('handoff.ok,"Changed receiving facts must pause an unsupported physical handoff.")
    Set shortNeed=##class(Allfedo.Rescue).Open("Allfedo.Record.Need",ids."third_need"), validUntil=##class(Allfedo.Policy).Now()+120
    Set shortUpdate={"need_id":(ids."third_need"),"revision":(shortNeed.Revision),"quantity":"15","unit":"meal_box","receiving_until":(##class(Allfedo.Policy).ISO(validUntil+300)),"confirmed_until":(##class(Allfedo.Policy).ISO(validUntil)),"excluded_allergens":["milk"],"accepted_holding":["chilled"],"event_at":(event)}
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
    Quit {"ok":true,"checks":"confirmed site, unknown food intake, reconfirmed food, packaging gap, explicit informed transport, reduced actual need, preserved promises, zero-clamped capacity, unaffected partners"}
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
            Set body={"need_id":(ids.need),"revision":(need.Revision),"quantity":(""_need.RequestedQuantity),"unit":(need.Unit),"receiving_until":(##class(Allfedo.Policy).ISO(need.ReceivingUntil)),"confirmed_until":(##class(Allfedo.Policy).ISO(need.ConfirmedUntil)),"excluded_allergens":(##class(Allfedo.Rescue).ParseArray(need.ExcludedAllergensJSON)),"accepted_holding":(##class(Allfedo.Rescue).ParseArray(need.AcceptedHoldingJSON)),"event_at":(##class(Allfedo.Policy).ISO(##class(Allfedo.Policy).Now()))}
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

ClassMethod Run(actorId As %String, requestId As %String, action As %String, data As %DynamicObject) As %DynamicObject
{
    Quit ##class(Allfedo.Rescue).Parse(##class(Allfedo.Rescue).Execute(actorId,requestId,action,data.%ToJSON()))
}

ClassMethod Check(condition As %Boolean, message As %String)
{
    Do ##class(Allfedo.Rescue).Require(condition,message)
}
}
