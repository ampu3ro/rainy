
#' @title Microsoft OneDrive File Upload Control
#' @description Shiny button that when clicked shows a file picker used to get Graph file IDs and metadata.
#' See \href{https://docs.microsoft.com/en-us/onedrive/developer/controls/file-pickers/js-v72/open-file}{File Picker reference guide} for details
#' @param endpointHint Endpoint hint is used for SDK redirects the app to the right OAuth endpoint based on which OneDrive API endpoints the app wants talk to.
#' The value of \code{endpointHint} could be \code{"api.onedrive.com"} for OneDrive personal, the OneDrive for Business URL or a SharePoint document library URL,
#' ex. \code{"https://contoso-my.sharepoint.com/personal/foo_contoso_onmicrosoft_com/"} or \code{"https://contoso.sharepoint.com/shared\%20documents/"}
#' @param queryParameters A character vector of additional query parameters as specified by the OneDrive API that define how an item is returned.
#' This typically includes a select and/or expand value
#' @param viewType The type of item that can be selected. Can be \code{"files"}, \code{"folders"} or \code{"all"}
#' @param sdk SDK version
#' @inheritParams shiny::actionButton
#' @return A Shiny button. Files selected will get returned as json to input$inputId
#' @examples
#' \dontrun{
#' library(shiny)
#'
#' ui <- fluidPage(
#'   br(),
#'   fileOneDrive("selected",rainy_app("[client ID]")),
#'   br(),
#'   verbatimTextOutput("response")
#' )
#'
#' server <- function(input,output) {
#'   output$response <- renderPrint(input$selected)
#' }
#'
#' runApp(shinyApp(ui=ui,server=server),launch.browser=T)
#' }
#' @export
fileOneDrive <- function(inputId,app,multiple=F,accept=NULL,viewType="files",queryParameters=NULL,
                         label="Browse...",icon=shiny::icon("cloud"),width=NULL,
                         endpointHint="api.onedrive.com",sdk=7.2,...) {

  picker <- paste0('function picker_',inputId,'(){',
                   ' var odOptions = {',
                   '  clientId: "',app$key,'",',
                   '  action: "query",',
                   '  multiSelect: ',tolower(multiple),',',
                   '  viewType: "',tolower(match.arg(viewType,c("files","folders","all"))),'",',
                   '  advanced: {',
                   '   endpointHint: "',endpointHint,'",',
                   if (!is.null(queryParameters)) paste0('queryParameters: "select=',paste(queryParameters,collapse=","),'",'),
                   if (!is.null(accept)) paste0('filter: "folder,',paste(accept,collapse=","),'",'),
                   '  },',
                   '  success: function(files) {',
                   '   Shiny.onInputChange("',inputId,'",files)',
                   '  }',
                   ' };',
                   ' OneDrive.open(odOptions);',
                   '}')

  text <- paste0('<script type="text/javascript" src="https://js.live.net/v',sprintf("%.1f",sdk),'/OneDrive.js"></script>',
                 '<script type="text/javascript">',picker,'</script>')

  button <- shiny::tags$button(type="button",
                               class="btn btn-default",
                               list(shiny:::validateIcon(icon),label),
                               onClick=paste0("picker_",inputId,"()"),shiny::HTML(text),...)

  div(class="form-group shiny-input-container",
      style=if (!is.null(width)) paste0("width: ",shiny::validateCssUnit(width),";"),
      shiny::div(class="input-group",shiny::tags$label(class="input-group-btn",button)))
}
