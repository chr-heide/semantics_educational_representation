
library(rvest)
library(xml2)
library(docstring)


split_html <- function(file, tag) {
  
  #' Split html-file
  #' 
  #' @description A function that takes an html-file and an html-tag as arguments and returns
  #' a list with the html-file split each time the tag appears
  #' 
  #' @param file a html-file
  #' @param tag a string. the tag to be split on
  
  # Find all cases of the tag
  nodes <- html_nodes(file, tag)
  
  # Finding the parent node - ideally this contain all conten nodes
  parent_node <- xml_parent(nodes)
  
  # Getting all children of the parent-node
  all_children <- xml_children(parent_node[1])
  
  # Finding indices
  target_indices <- which(all_children %in% nodes)
  
  # Empty list to store results
  splits <- list()
  
  # Extract segments starting from each `p.PreTekst` tag to the next one
  for (i in seq_along(target_indices)) {
    if (i < length(target_indices)) {
      splits[[i]] <- all_children[target_indices[i]:(target_indices[i + 1] - 1)]
    } else {
      # From the last `p.PreTekst` to the end
      splits[[i]] <- all_children[target_indices[i]:length(all_children)]
    }
  }
  
  return(splits)
  
}


assemble_html <- function(html_list) {
  
  #' Docstring here
  #' 
  
  html_string <- ""
  
  for (i in 1:length(html_list)) {
    
    html_string <- paste0(html_string, html_list[i])
  }
  
  # Convert to html_format
  out <- read_html(html_string)
  
  return(out)
  
}


