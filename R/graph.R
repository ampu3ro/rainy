
#' @title Microsoft Graph Endpoint
#' @description Generates an endpoint object that can be used in \code{\link{graph_login}}
#' @param tenant Graph tenant. For single-tenant should be something like \code{"contoso.onmicrosoft.com"}, otherwise use default \code{"common"}
#' @param ... Not used. Arguments passed from other functions
#' @export
graph_endpoint <- function(tenant="common",...) {
  base <- paste0("https://login.microsoftonline.com/",tenant)
  httr::oauth_endpoint(authorize=paste0(base,"/oauth2/v2.0/authorize"),access=paste0(base,"/oauth2/v2.0/token"))
}


#' @title Microsoft Graph Login
#' @description Performs OAuth2.0 and stores a token for later calls to Graph API
#' @inheritParams httr::init_oauth2.0
#' @export
graph_login <- function(app,code=NULL,scope="Files.ReadWrite.All",endpoint=graph_endpoint()) {

  credentials <- if (is.null(code)) NULL else httr::oauth2.0_access_token(endpoint=endpoint,app=app,code=code)
  token <- httr::oauth2.0_token(endpoint=endpoint,app=app,credentials=credentials,scope=scope,cache=F,use_oob=F)

  x <- token$credentials
  if (("error" %in% names(x)) && (nchar(x$error)>0))
    stop(x$error," (",x$error_codes,")\n",x$error_description)

  options(graph_token=token)

  invisible(token)
}


graph_token <- function() {
  token <- getOption("graph_token")
  if (is.null(token))
    stop("missing Microsoft Graph access token, use graph_login() to generate one",call.=F)
  httr::config(token=token)
}


#' @title Microsoft Graph Base URL
#' @description Helper function to build a base URL with version number
#' @param endpoint URL endpoint. See \href{https://developer.microsoft.com/en-us/graph/docs/concepts/overview}{API overview} for examples
#' @param api API version. If \code{0} will use beta API
#' @export
graph_url <- function(endpoint,api=1,...) {
  version <- ifelse(api==0,"beta",sprintf("v%.1f",api))
  ifelse(grepl("^https",endpoint),endpoint,paste0("https://graph.microsoft.com/",version,"/",endpoint))
}


#' @title Microsoft Graph API Handler
#' @description Wrapper for handling API calls/responses
#' @param ... Optional arguments passed to \code{\link[httr]{VERB}}
#' @inheritParams httr::VERB
#' @inheritParams base::tempfile
#' @inheritParams readxl::read_excel
#' @export
graph_handler <- function(url,...,fileext="",sheet=1,skip=0,col_types=NULL,verb="GET") {

  fileext <- tolower(fileext)
  if (!grepl("^\\.",fileext))
    fileext <- paste0(".",fileext)

  download <- verb=="GET" && grepl("content$",url,ignore.case=T)
  read <- download && fileext %in% c(".rds",".csv",".xls",".xlsx")

  if (read) {
    path <- tempfile(fileext=fileext)
    config <- httr::write_disk(path=path,overwrite=T)
  } else {
    config <- NULL
  }

  response <- httr::VERB(verb=verb,url=url,config=config,...)
  code <- httr::status_code(response)
  good <- code<300

  if (read && good) {
    if (fileext==".rds") {
      object <- readRDS(path)

    }  else if (fileext %in% c(".xls",".xlsx")) {

      object <- sapply(sheet,function(sheet) {
        as.data.table(readxl::read_excel(path,sheet=sheet,skip=skip,col_types=colTypes))
      },simplify=F)

      if (length(sheet)==1)
        object <- object[[1]]

    } else  {
      if (!is.null(col_types))
        colClasses <- switch(col_types,text="character",col_types)

      object <- fread(path,skip=skip,colClasses=colTypes)
    }

    file.remove(path)
    return(object)
  }

  as <- if (download && good) NULL else "text"
  content <- httr::content(response,as,encoding="UTF-8")

  if (download && good)
    return(content)

  list <- jsonlite::fromJSON(content,flatten=T)

  if (good)
    return(list)

  error <- paste0(list$error$code," (",code,")\n",list$error$message)
  stop(error)
}


#' @title Microsoft Graph GET Request
#' @description Standard GET call to Graph API
#' @param ... Optional arguments passed to \code{\link{graph_url}} and \code{\link{graph_handler}}
#' @inheritParams graph_url
#' @return List of vectors and a data.frame of values
#' @examples
#' \dontrun{
#' graph_get("me")
#' graph_get("drives")
#' }
#' @export
graph_get <- function(endpoint,...) {
  token <- graph_token()
  url <- graph_url(endpoint,...)
  graph_handler(url,token,...,verb="GET")
}


#' @title Microsoft Graph Search Query
#' @description Search the hierarchy of drive items for items matching a query. Looks at file metadata and data within files
#' @param text The query text used to search for items. Values may be matched across several fields including filename, metadata, and file content
#' @param drive Drive item endpoint preceding "/search".
#' See \href{https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_get}{Get file or folder} for examples
#' @param top Number of items to return in a result set. If \code{NA} will return all
#' @param ... Optional arguments passed to \code{\link{graph_get}}
#' @return data.table of query results
#' @export
graph_search <- function(text,drive="me/drive/root",top=NA_integer_,...) {

  endpoint <- paste0(drive,"/search(q='",curl::curl_escape(text),"')",ifelse(is.na(top),"",paste0("?$top=",top)))
  query <- graph_get(endpoint,...)

  if (length(query$value)==0)
    return()

  url <- query$`@odata.nextLink`

  if (is.null(url))
    return(as.data.table(query$value))

  while (!is.null(url)) {
    x <- graph_get(url)
    query$value <- rbindlist(list(query$value,x$value),fill=T)
    url <- x$`@odata.nextLink`
  }
  query$value
}


#' @title Microsoft Graph File Upload
#' @description Upload the contents of a new file or update the contents of an existing file
#' @param name Filename to save as. Defaults to original filename
#' @inheritParams graph_url
#' @inheritParams base::tempfile
#' @return List of drive item IDs and metadata
#' @export
graph_upload <- function(path,endpoint="me/drive/root",name=curl::curl_escape(basename(path)),fileext=tools::file_ext(path),...) {

  token <- graph_token()

  if (file.info(path)$size>4e6)
    stop(path," too large for simple upload")

  if (!grepl("content$",endpoint,ignore.case=T))
    endpoint <- paste0(endpoint,":/",name,":/content")

  url <- graph_url(endpoint,...)
  file <- paste0(path,ifelse(grepl("\\.",path),"",fileext))
  body <- httr::upload_file(path,type=mime::guess_type(file))

  graph_handler(url,token,body=body,...,fileext=fileext,verb="PUT")
}
