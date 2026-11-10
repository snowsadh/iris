Include %occStatus

/// Privileged installation only. Creates no user accounts and grants no application-wide elevation.
Class Allfedo.Web.Setup Extends %RegisteredObject
{
ClassMethod Configure() As %Status
{
    Set status=..Security()
    If $$$ISERR(status) Quit status
    Set status=##class(Allfedo.AISettings).Install()
    If $$$ISERR(status) Quit status
    Set status=..Application("/allfedo/api","Allfedo.Web.API","")
    If $$$ISERR(status) Quit status
    Set status=..Application("/allfedo","Allfedo.Web.App","Allfedo.Web.Login.cls")
    If $$$ISERR(status) Quit status
    For table="Actor","Offer","Need","Allocation","Site","AgentRun","Event","Outbox","Custody","ChangeRequest" {
        Set query=##class(%SQL.Statement).%ExecDirect(,"GRANT SELECT ON Allfedo_Record."_table_" TO Allfedo_Partner")
        Do ##class(Allfedo.Rescue).QueryOK(query)
    }
    Quit $$$OK
}

ClassMethod Security() As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If '##class(Security.Resources).Exists("Allfedo_API") {
        Set status=##class(Security.Resources).Create("Allfedo_API","Use the authenticated Allfedo interface","")
        If $$$ISERR(status) Quit status
    }
    If '##class(Security.Roles).Exists("Allfedo_Partner") {
        Set status=##class(Security.Roles).Create("Allfedo_Partner","Invited Allfedo account","Allfedo_API:U,%DB_ALLFEDO:RW,%DB_ALLFEDO_CODE:R","")
        If $$$ISERR(status) Quit status
    } Else {
        Set partner("Resources")="Allfedo_API:U,%DB_ALLFEDO:RW,%DB_ALLFEDO_CODE:R"
        Set status=##class(Security.Roles).Modify("Allfedo_Partner",.partner)
        If $$$ISERR(status) Quit status
    }
    // Native login pages run as the gateway account before the partner authenticates.
    // Grant code-database read to that account only, never to the public user.
    If '##class(Security.Roles).Exists("Allfedo_Gateway") {
        Set status=##class(Security.Roles).Create("Allfedo_Gateway","Load Allfedo native login code","%DB_ALLFEDO_CODE:R","")
        If $$$ISERR(status) Quit status
    } Else {
        Set gateway("Resources")="%DB_ALLFEDO_CODE:R"
        Set status=##class(Security.Roles).Modify("Allfedo_Gateway",.gateway)
        If $$$ISERR(status) Quit status
    }
    Set roles="Allfedo_Gateway", status=##class(Security.Users).AddRoles("CSPSystem",.roles)
    If $$$ISERR(status) Quit status
    Quit $$$OK
}

ClassMethod Application(path As %String, dispatch As %String, login As %String) As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    If ##class(Security.Applications).Exists(path) {
        Set status=##class(Security.Applications).Get(path,.existing)
        If $$$ISERR(status) Quit status
        If (existing("DispatchClass")'=dispatch)||(existing("NameSpace")'="ALLFEDO") Quit $$$ERROR($$$GeneralError,"A different application already owns "_path_".")
    }
    Set properties("NameSpace")="ALLFEDO", properties("DispatchClass")=dispatch, properties("LoginPage")=login
    Set properties("Enabled")=1, properties("AutheEnabled")=32, properties("Resource")="Allfedo_API"
    Set properties("UseCookies")=2, properties("CookiePath")="/allfedo/", properties("SessionScope")=2, properties("GroupById")="Allfedo"
    Set properties("CSRFToken")=1, properties("ServeFiles")=0, properties("CSPZENEnabled")=1
    Set properties("MatchRoles")="", properties("CorsAllowlist")="", properties("CorsCredentialsAllowed")=0
    Set properties("Description")="Authenticated Allfedo records and native business commands"
    If ##class(Security.Applications).Exists(path) {
        Set status=##class(Security.Applications).Modify(path,.properties)
    } Else {
        Set status=##class(Security.Applications).Create(path,.properties)
    }
    If $$$ISERR(status) Quit status
    Quit status
}
}
