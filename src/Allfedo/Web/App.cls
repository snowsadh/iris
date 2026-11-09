Include %occStatus

/// Serve only the app's named assets after native authentication and membership checks.
Class Allfedo.Web.App Extends %CSP.REST
{
Parameter UseSession = 1;
Parameter HandleCorsRequest = 0;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <Route Url="/" Method="GET" Call="Index"/>
  <Route Url="/" Method="POST" Call="Index"/>
  <Route Url="/:file" Method="GET" Call="RootFile"/>
  <Route Url="/:directory/:file" Method="GET" Call="NestedFile"/>
</Routes>
}

ClassMethod Login(skipheader As %Boolean = 1) As %Status [ ProcedureBlock = 0 ]
{
    Quit ##class(Allfedo.Web.Login).Page(skipheader)
}

ClassMethod Index() As %Status
{
    If %request.Method="POST" { Set %response.Redirect="/allfedo/" Quit $$$OK }
    Quit ..File("index.html")
}

ClassMethod RootFile(file As %String) As %Status
{
    Quit ..File(file)
}

ClassMethod NestedFile(directory As %String, file As %String) As %Status
{
    Quit ..File(directory_"/"_file)
}

ClassMethod File(path As %String) As %Status
{
    Try {
        Set actor=##class(Allfedo.Web.API).Principal()
        Set allowed=$ListBuild("index.html","styles.css","app.js","api.js","render.js","forms.js","time.js","views/kitchen.js","views/receiving.js","views/collections.js","views/coordinator.js","views/site.js","views/recovery.js","views/physical.js","views/redirect.js","assets/public-sans.ttf")
        Do ##class(Allfedo.Web.API).Check($ListFind(allowed,path),404,"NOT_FOUND","This file does not exist.")
        Set stream=##class(%Stream.FileBinary).%New(), status=stream.LinkToFile("/opt/allfedo/web/"_path)
        Do ##class(Allfedo.Web.API).Check($SYSTEM.Status.IsOK(status)&&stream.Size,503,"APP_NOT_INSTALLED","The Allfedo browser files are not installed yet.")
        Set extension=$Piece(path,".",2), %response.ContentType=$Select(extension="html":"text/html",extension="css":"text/css",extension="ttf":"font/ttf",1:"text/javascript")
        Set %response.CharSet="utf-8", %response.NoCharSetConvert=1
        Set %response.Headers("Cache-Control")="no-store", %response.Headers("X-Content-Type-Options")="nosniff"
        Set %response.Headers("Content-Security-Policy")="default-src 'self'; script-src 'self'; style-src 'self'; font-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
        Do stream.OutputToDevice()
    } Catch error {
        Set status=##class(Allfedo.Web.API).Failure(error)
    }
    Quit status
}
}
