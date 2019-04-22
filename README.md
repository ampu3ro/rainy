**rainy** is an R packaged that enhances the functionality of Shiny apps by adding basic interations with cloud databases. Currently only [Microsoft Graph API](https://docs.microsoft.com/en-us/graph/use-the-api) is supported (and only select interactions I've needed at that), but the framework is designed to be extensible. It has some similar functionality to [msgraphr](https://github.com/davidski/msgraphr), which I only recently became of and is a nice solution, however this package was designed with the Shiny use case in mind and may not be limited to a single API.

With easy access to files in the cloud, collaboration across teams doesn't require synching folders locally and cloud infrastructure can be used to process files differently through Shiny. In Enterprise, it's common to run Shiny on a server and while `shiny::fileInput` is convenient, it will copy and transfer all the files referenced, making processing many files cumbersome of impossible. If each file is instead processed in sequence (or in parallel) and only the result of some reduce function saved, memory issues can be avoided!

### Install
```R
devtools::install_github("ampu3ro/rainy")
```

### Microsoft Graph API Setup
[Register your app](https://apps.dev.microsoft.com/) and take note of the _Application ID_ (aka _Client ID_). You will reference this in R like `rainy_app(key="[client ID]")`

In the Azure Portal:

Go to _Authentication_ and add `http://localhost:1410` (and your app URL) to the list of _Redirect URIs_

![Redirect](https://github.com/ampu3ro/rainy/blob/master/www/azure_redirect.PNG)

Go to _API Permissions_ and set the appropriate permissions. You will reference this in R like `graph_login(...,scope="[permission]")`

![Permissions](https://github.com/ampu3ro/rainy/blob/master/www/azure_permissions.PNG)

### Use
```R
library(shiny)
library(rainy)

app <- rainy_app("[client ID]")

ui <- rainy_ui(fluidPage(
  h3("Microsoft Graph API Testing"),
  br(),
  h4("My Profile"),
  verbatimTextOutput("me"),
  hr(),
  uiOutput("uiFile"),
  br(),
  h4("Files Selected"),
  verbatimTextOutput("selected")
),app,graph_endpoint(),"Files.ReadWrite.All")

server <- function(input,output,session) {
  params <- parseQueryString(isolate(session$clientData$url_search))
  if (is.null(params$code))
     return()
  graph_login(app,params$code)
  output$me <- renderPrint(graph_get("me"))

  endpointHint <- graph_get("drives/me")$webUrl
  output$uiFile <- renderUI(fileOneDrive("files",app,endpointHint=endpointHint))
  output$selected <- renderPrint(input$files)
}

runApp(shinyApp(ui=ui,server=server),launch.browser=T)
```

If setup properly you should get something that looks like this

![File](https://github.com/ampu3ro/rainy/blob/master/www/graph_test.PNG)
