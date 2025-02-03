# Christian Heide
# 23/04/2024
# Collecting speech data


# Imports -----------------------------------------------------------------

# Libraries
library(tidyverse)
library(rvest)
library(xml2) # for saving rvest files using `write_xml()`

# Utility functions
source("src/utils/html_processing.R")

# Collecting html-files ---------------------------------------------------

# The ParlSpeech V2 dataset contains data up until december 20th 2018.
# As such, I only collect links after this date.

# Obs: Scraping done the 23rd of April 2024

# Defining the number of pages of search results and a url with search results.
no_pages <- c(1:4)
search_urls <- paste0("https://www.ft.dk/da/dokumenter/dokumentlister/referater?startDate=20181221&endDate=20240423&pageSize=200&totalNumberOfRecords=645&pageNumber=", no_pages)

links <- c()

for (url in search_urls) {
  
  # Reding in the page
  page <- read_html(url)
  
  # Getting the links. Note that I only need every third link in the results
  temp_links <- html_nodes(page, "a.column-documents__link")
  temp_links <- xml_attr(temp_links, "href")[1:length(temp_links) %% 3 == 1]
  
  links <- c(links, temp_links)
  
  Sys.sleep(2)
}


# Creating a vector of names
filenames <- c()
for (i in 1:length(links)) {
  link <- links[i]
  name <- substr(link, nchar(link) - 18, nchar(link) - 4)
  filenames <- c(filenames, name)
}

# Saving all the html-files
for (i in 1:length(links)) {
  
  print(paste("Scraping page number:", i, "of", length(links)))
  
  # Making the link and reading the page
  url <-  paste0("https://www.ft.dk", links[i])
  page <- read_html(url)
  
  # Saving the html-file in the designated folder
  write_xml(page,
            file = paste0("data/raw_html/",
                          filenames[i],
                          ".html")
            )
  
  Sys.sleep(2)
  
}



# Extracting speech data --------------------------------------------------

# With the html-files acquired, the next step is to extract relevant information
# into a data frame

# The loop below does approximately the following for each speech:

# Split the data on each new agenda point

# For each agenda point, extract the agenda and split into speeches within each
# agenda

# For each speech extract text, speaker and party and whether the speaker is the
# chair.

# Finally once looping through all agenda points is done, the speechnumber and
# terms variables are added.

# First making a list of html-files
files <- list.files(path = "data/raw_html/")

# Creating an empty data frame to store the final results
final_df <- data.frame()

# Next looping through all the html-files
for (f in 1:length(files)) {
  
  # Status update
  print(paste0("Extracting from session ", f, " (file: ", files[f], ")"))
  
  file <- read_html(paste0("data/raw_html/", files[f]))
  
  # Creating an empty data frame to store the results from the session
  session_df <- data.frame()
  
  # Extracting the date
  date <- file |> 
    html_nodes("meta[name='DateOfSitting']") |> 
    html_attr("content")
  date <- substr(date, 1, nchar(date) - 9) # Removing time
  
  # Split into agenda segments
  agenda_segments <- split_html(file = file, tag = "p.PreTekst")
  
  # Next loop over each segment of the agenda
  for (i in 1:length(agenda_segments)) {
    
    # Get the item currently on the agenda. Note that it's the second item,
    # as the first is some introductory text
    agenda <- agenda_segments[[i]][2] |>
      html_text()
    
    # Reassemble the current segment to one html-file
    agenda_segment <- assemble_html(agenda_segments[[i]])
    
    # Split the single-agenda-segment into speaker segments. I do this using the
    # time-tag, as time-stamps are each time the speaker changes
    speaker_segments <- split_html(file = agenda_segment,
                                   tag = "p.Tid")
    
    # Next step is looping over all speaker-segments
    for (s in 1:length(speaker_segments)) {
      
      # Reconstruction the speaker-segment into html-file
      speaker_segment <- assemble_html(speaker_segments[[s]])
      
      # Extracting the speakers name
      first_name <- speaker_segment |> 
        html_node(xpath = '//meta[@name="OratorFirstName"]') |> 
        html_attr("content")
      last_name <- speaker_segment |> 
        html_node(xpath = '//meta[@name="OratorLastName"]') |> 
        html_attr("content")
      speaker <- paste(first_name, last_name)
      
      # Extracting party
      party <- speaker_segment |> 
        html_node(xpath = '//meta[@name="GroupNameShort"]') |> 
        html_attr("content")
      
      # Extracting role (chair/MP)
      role <- speaker_segment |> 
        html_node(xpath = '//meta[@name="OratorRole"]') |> 
        html_attr("content")
      
      # Extracting text
      text <- speaker_segment |> 
        html_nodes(".Tekst, .TekstIndryk, .TekstLuft") |> 
        html_text() |> 
        paste(collapse = " ")
      
      # Adding the observation to a temporary data frame
      temp_df <- data.frame(
        date = date,
        agenda = agenda,
        speaker = speaker,
        party  = party,
        role = role,
        text = text)
      
      # There are problems that some speeches are seperated by time stamps, which
      # results in meta data being NA. To avoid this, when this happens, I add the
      # extra text to the previous speech, which is the same speaker. Otherwise it
      # is a complete observation, and I just add to data frame
      if (speaker == "NA NA") {
        session_df$text[length(session_df$text)] <- paste(session_df$text[length(session_df$text)], text, collapse = " ")
      } else {
        session_df <- session_df |> 
          bind_rows(temp_df)
      }}
    }
  
  # After the session is done, i add a column with speechnumber
  speechnumbers <- 1:length(session_df$text)
  session_df <- session_df |> 
    mutate(speechnumber = speechnumbers)
  
  # And I add the column "terms" containing the number of words in each speech
  session_df$terms <- lengths(strsplit(session_df$text, "\\s+"))
  
  # And then I add to the final data frame
  final_df <- final_df |> 
    bind_rows(session_df)
  
}
  
saveRDS(final_df, "data/raw/scraped_speeches.rds")


# Post-processing ---------------------------------------------------------

# Finally processing a bit on the scraped speeches - this is purely meant to
# get the data in the same format as the ParlSpeech dataset

df <- readRDS("data/raw/scraped_speeches.rds")

# Removing non-speech segments
df <- df |> 
  filter(!(role %in% c("Pause", "")))

# First I add three extra columns, that are in the ParlSpeech data

# The first two are just constant, identifying the parliament and country
df <- df |> 
  mutate(
    parliament = "DK-Folketing",
    iso3country = "DNK")

# Next I create the party.fact.id variable by assigning the id, based on party
# codes from https://partyfacts.herokuapp.com/data/partycodes/?country=DNK

df <- df |> 
  mutate(party.facts.id = case_when(
    party == "S" ~ 379,
    party == "V" ~ 1204,
    party == "NB" ~ 7339,
    party == "DF" ~ 1022,
    party == "EL" ~ 1527,
    party == "KF" ~ 536,
    party == "SF" ~ 329,
    party == "RV" ~ 1507,
    party == "ALT" ~ 4070,
    party == "UFG" ~ 2658,
    party == "LA" ~ 212,
    party == "SIU" ~ 6651,
    party == "KD" ~ 53,
    party == "M" ~ 9063,
    party == "DD" ~ 9062,
    .default = NA
  ))

# Finally mutating the role column to be the chair column in ParlSpeech
df <- df |> 
  mutate(chair = if_else(
    role %in% c("formand", "aldersformanden", "midlertidig formand"),
    TRUE,
    FALSE)) |> 
  select(-role)

# Saving the processed data
saveRDS(df, file = "data/processed/scraped_speeches.rds")
