/// Isolated accounts for the real browser journey. Food history remains available for inspection.
Class AllfedoBrowserScenario Extends %RegisteredObject
{
ClassMethod PrepareFromEnvironment() As %String
{
    Do ##class(Allfedo.Rescue).Require(($TLEVEL=0)&&$SYSTEM.Security.Check("%Admin_Secure","U"),"Browser fixtures require the privileged local test runner.")
    Set accounts=##class(Allfedo.Rescue).Parse($SYSTEM.Util.GetEnviron("ALLFEDO_BROWSER_FIXTURE"))
    Do ##class(Allfedo.Rescue).Require(accounts.%Size()=5,"The browser journey needs five isolated accounts covering four roles.")
    For role="coordinator","kitchen","recipient","collector","recipient2" {
        Set account=accounts.%Get(role)
        Do ##class(Allfedo.Rescue).Require($IsObject(account)&&($Extract(account.username,1,17)="allfedo-web-test-")&&($Length(account.password)>=24),"The fixture must use private test accounts.")
    }
    Do ##class(AllfedoScenario).Setup(.ids)
    For role="coordinator","kitchen","recipient","collector","recipient2" {
        Set actorId=$Select(role="recipient2":ids."second_recipient",1:ids.%Get(role))
        Set account=accounts.%Get(role), actor=##class(Allfedo.Rescue).Actor(actorId)
        Do ##class(AllfedoWebScenario).CreateUser(account.username,account.password)
        Set actor.UserName=account.username
        Do ##class(Allfedo.Rescue).Save(actor)
        Set account."actor_id"=""_actor.%Id()
    }
    Quit {"ok":true,"network_id":(ids.network),"accounts":(accounts)}.%ToJSON()
}

ClassMethod RemoveFromEnvironment()
{
    Do ##class(Allfedo.Rescue).Require($SYSTEM.Security.Check("%Admin_Secure","U"),"Browser cleanup requires the privileged local test runner.")
    Do ##class(AllfedoWebScenario).RemoveUsers($SYSTEM.Util.GetEnviron("ALLFEDO_BROWSER_FIXTURE"))
}
}
