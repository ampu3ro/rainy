
#' @title Cloud API Wrappers and Shiny Tools
#' @description API wrappers and tools to facilitate interations between cloud based databases and Shiny apps
#' @docType package
#' @name rainy
#' @import data.table
NULL


#' @title OAuth App
#' @description Helper function that generates an OAuth app object with different defaults
#' @inheritParams httr::oauth_app
#' @details For Microsoft Graph, need to \href{https://apps.dev.microsoft.com/}{register an app}
#' with Azure to set permissions
#' @export
rainy_app <- function(key,redirect_uri=httr::oauth_callback()) {
  httr::oauth_app(appname="NA",key=key,secret=NULL,redirect_uri=gsub("//$","/",redirect_uri))
}


#' @title Shiny OAuth Redirect
#' @description Check for oauth credentials and store code in the URL. This allows for a Shiny to perform all susequent interactions with a cloud database instead
#' of having to login with each interaction (see \code{\link{fileOneDrive}} example)
#' @param ui Shiny UI opbject
#' @inheritParams httr::init_oauth2.0
#' @details Adapted from \href{https://gist.github.com/hadley/144c406871768d0cbe66b0b810160528}{Hadley's solution}
#' @examples
#' \dontrun{
#' library(shiny)
#'
#' app <- rainy_app("[client ID]") #remember to set redirect URI in Azure
#'
#' ui <- rainy_ui(fluidPage(
#'   br(),
#'   h3("You are now logged in as"),
#'   br(),
#'   verbatimTextOutput("me")
#' ),app,graph_endpoint(),"Files.ReadWrite.All")
#'
#' server <- function(input,output,session) {
#'   params <- parseQueryString(isolate(session$clientData$url_search))
#'   if (is.null(params$code))
#'      return()
#'   graph_login(app,params$code)
#'   output$me <- renderPrint(graph_get("me"))
#' }
#'
#' runApp(shinyApp(ui=ui,server=server),launch.browser=T)
#' }
#' @export
rainy_ui <- function(ui,app,endpoint,scope=NULL) {
  function(req) {
    params <- parseQueryString(req$QUERY_STRING)
    if (is.null(params$code)) {
      url <- httr::oauth2.0_authorize_url(endpoint=endpoint,app=app,scope=scope)
      redirect <- sprintf("location.replace(\"%s\");",url)
      shiny::tags$script(shiny::HTML(redirect))
    } else {
      ui
    }
  }
}
