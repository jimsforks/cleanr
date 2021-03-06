#' Throws an error if the data does not confirm to the rule set.
#'
#' @title Validate data given a rule set
#' @param data The data to validate
#' @param rules List of rules
#' @param rules_file Optional: the yaml file containing the rules
#' @export
rule_validation <- function( data, rules_file = NULL, rules = NULL )
{
  if (is.null(rules))
    rules<-yaml::yaml.load_file(rules_file)

  results <- c()
  for(rule in rules)
  {
    if(is_rule(rule))
      results <- c(results,apply_rule(data,rule))
  }

  return(all(results))
}

relations <- list(
  list("keywords" = c("gt", "greater_than", ">"), "func"=function(x,y) x>y),
  list("keywords" = c("gte", "greater_than_or_equal", ">="), "func"=function(x,y) x>=y),
  list("keywords" = c("lt", "lesser_than", "<"), "func"=function(x,y) x<y),
  list("keywords" = c("lte", "lesser_than_or_equal", "<="), "func"=function(x,y) x<=y)
)

apply_rule<-function(data,rule)
{
  results <- c()
  if("relation" %in% names(rule))
  {
    for( relation in relations )
      if (rule$relation %in% relation$keywords)
      {
        results <- relation$func( data[[rule$fields[1]]], data[[rule$fields[2]]] )
        break
      }
  }

  if("rule" %in% names(rule))
  {
    element<-strsplit(rule$rule," ")[[1]]
    new_rule<-list(fields=c(element[1],element[3]),relation=element[2])
    apply_rule(data,new_rule)
  }

  if("invalid" %in% names(rule))
  {
    values <- rule$invalid
    # Support both [value1, value2] and [[value1, value2],[alt_value1,alt_value2]], so we normalize them here
    if (class(values)!="list")
    {
      values <- list(values)
    }

    for (value in values)
    {
      results_df <- mapply(function(f,v) (data[[f]]==v), rule$fields, value)
      results <- !(rowSums(results_df)==ncol(results_df)) # If all are true then all fields match all values (and sum==ncol)
    }
  }

  if("valid" %in% names(rule))
  {
    values <- rule$valid
    # Support both [value1, value2] and [[value1, value2],[alt_value1,alt_value2]], so we normalize them here
    if (class(values)!="list")
    {
      values <- list(values)
    }

    results <- NULL
    for (value in values)
    {
      results_df <- mapply(function(f,v) (data[[f]]==v), rule$fields, value)
      if (is.null(results))
        results <- (rowSums(results_df)==ncol(results_df))
      else
        results <- (rowSums(results_df)==ncol(results_df))|results # Match this set of values or the previous set of values
    }
  }

  if (!all(results))
  {
    if("relation" %in% names(rule))
      warning_description<-paste(rule$fields[1], rule$relation, rule$fields[2])
    else
      warning_description<-rule
    warning("Rows: ", which(!results)[1], "; failed rule: ", warning_description)
    return(FALSE)
  }
  return(TRUE)
}

is_rule<-function(x)
{
  keywords=c("rule","relation","dependancy","valid","invalid")
  return(any(keywords %in% names(x)))
}
