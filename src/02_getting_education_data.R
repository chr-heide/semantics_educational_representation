# Christian Heide
# 02/05/2024
# Collecting education data via the folketing-API


# Imports -----------------------------------------------------------------

# Libraries
library(httr)
library(jsonlite)
library(tidyverse)
library(rvest)
library(stringr)

# Getting data ------------------------------------------------------------

# Defining link and encoding the link
link <- "https://oda.ft.dk/api/Aktør?$inlinecount=allpages"
link <- URLencode(link)


# Number of pages in the search
num_pages <- 180

# Looping over all pages and extracting results
for (i in 1:num_pages) {
  
  # Special case for the first page
  if (i == 1) {
    
    #send GET request
    response <- GET(link)
    
    # format response
    output <- response %>% 
      content(as = "text", encoding = "UTF-8") %>% 
      fromJSON(flatten = TRUE)
    
    nextlink <- output$odata.nextLink
    
    # get dataframe out
    final <- as_tibble(output$value)
    
  } else {
    
    #send GET request
    response <- GET(nextlink)
    
    # format response
    output <- response %>% 
      content(as = "text", encoding = "UTF-8") %>% 
      fromJSON(flatten = TRUE)
    
    nextlink <- output$odata.nextLink
    
    # append data
    final <- add_row(final, as_tibble(output$value))
  }
}

# Converting to a data frame, and only keeping typeid == 5, which means that 
# the actor is an MP
df <- as.data.frame(final) |> 
  filter(typeid == 5)

# And finally saving the the raw results
saveRDS(df, file = "data/raw/mp_biographies.rds")


# Extracting from biography -----------------------------------------------

bios <- readRDS("data/raw/mp_biographies.rds")

# Empty vectors to store results
full_name <- c()
first_name <- c()
surname <- c()
date_of_birth <- c()
gender <- c()
party <- c()
education_text <- c()
education_category <- c()
urls <- c()

# Excluding three biographies that were weird:
# 1: A duplicate of Dan Jørgensen - no problem
# 2: Carsten Aagaard - a substitute member for less than a month in 1999
# 3: Elisabeth Krog who were a member until 1985, e.g. before the relevant period
biographies <- bios$biografi[-c(954, 1601, 2182)]

# Extracting the relevant data from all biographies
for (i in 1:length(biographies)) {
  
  # Faulty full name - only used for demonstration purposes
  full_name <- c(full_name, bios$navn[i])
  
  # First name
  if (!is.na(biographies[i]) & biographies[i] != "") {
    first <- read_html(biographies[i]) |> 
      html_nodes("firstname") |> 
      html_text()
  } else {
    first <- NA
  }
  first_name <- c(first_name, first)
  
  # Surname
  if (!is.na(biographies[i]) & biographies[i] != "") {
    last <- read_html(biographies[i]) |> 
      html_nodes("lastname") |> 
      html_text()
  } else {
    last <- NA
  }
  surname <- c(surname, last)
  
  # Date of birth
  if (!is.na(biographies[i]) & biographies[i] != "") {
    dob <- read_html(biographies[i]) |> 
      html_nodes("born") |> 
      html_text()
  } else {
    dob <- NA
  }
  date_of_birth <- c(date_of_birth, dob)
  
  # Gender
  if (!is.na(biographies[i]) & biographies[i] != "") {
    sex <- read_html(biographies[i]) |> 
      html_nodes("sex") |> 
      html_text()
  } else {
    sex <- NA
  }
  gender <- c(gender, sex)
  
  # Party
  if (!is.na(biographies[i]) & biographies[i] != "") {
    p <- read_html(biographies[i]) |> 
      html_nodes("partyshortname") |> 
      html_text()
  } else {
    p <- NA
  }
  party <- c(party, p)
  
  
  # Education string
  if (!is.na(biographies[i]) & biographies[i] != "") {
    edu_text <- read_html(biographies[i]) |> 
      html_nodes("education") |> 
      html_text() |> 
      paste(collapse = " ")
  } else {
    edu_text <- NA
  }
  education_text <- c(education_text, edu_text)
  
  # Education categories
  if (!is.na(biographies[i]) & biographies[i] != "") {
    edu_category <- read_html(biographies[i]) |> 
      html_node("educationstatistic") |>
      html_text()
  } else {
    edu_category <- NA
  }
  education_category <- c(education_category, edu_category)
  
  # Url - to check if there's any errors
  if (!is.na(biographies[i]) & biographies[i] != "") {
    url <- read_html(biographies[i]) |> 
      html_node("url") |>
      html_text()
  } else {
    url <- NA
  }
  urls <- c(urls, url)
}

# Writing to dataframe
# Note: Creating the full name from the text in the bio, as the meta-data from
# the API was highly faulty
df <- data.frame(
  full_name = full_name,
  first_name = first_name,
  surname = surname,
  name = paste(first_name, surname,sep = " "),
  date_of_birth,
  gender = gender,
  party = party,
  education_text = education_text,
  education_category = education_category,
  url = urls) |> 
  # Translating gender values to english
  mutate(
    gender = case_when(
      gender == "Mand" ~ "Male",
      gender == "Kvinde" ~ "Female",
      .default = NA),
    id = paste(name, party, sep = "_"))
  

# This just demonstrates the problem with the meta-data
doubles <- df |> 
  group_by(full_name) |> 
  summarise(n = n()) |> 
  filter(n > 1)
doubles <- doubles$full_name
df |> 
  filter(full_name %in% doubles) |> 
  select(full_name, name, gender, id, url) |> 
  arrange(desc(full_name)) |> 
  View()

# Many observations are missing relevant data in the biography. To clean up a bit,
# I only keep rows, where there's information in either the education_text or 
# education_category columns. This leaves me with a total of 1510 rows.

df <- df |> 
  filter(nchar(education_text) > 1 | nchar(education_category) > 1)

# As I have constructed ID's by combining name and party, there's a chance that
# different members will have the same ID. This is the case for two ID's that
# correspond to a total of 5 rows. After inspecting these, I find that only one
# of the rows has been an MP in my period. I therefore keep the row and discard
# the other 4. This leaves me with 1506 rows

# Inspecting doubles
doubles <- df |> 
  group_by(id) |> 
  summarise(n = n()) |> 
  filter(n > 1)
df |> 
  filter(id %in% doubles$id) |> 
  View()

# Discarding the 4 irrelevant doubles by subsetting on the unique urls
irrelevant_doubles <- df |> 
  filter(id %in% doubles$id) |> 
  slice(2:5)
df <- df |> 
  filter(!(url %in% irrelevant_doubles$url))

# Finally, I save only columns that are not already in the speech-data and save
# the data
df <- df |> 
  select(name, date_of_birth, gender, education_text, education_category, id)

saveRDS(df, file = "data/processed/mp_biographies.rds")


# Categorizing education --------------------------------------------------

df <- readRDS("data/processed/mp_biographies.rds")

# The education-category is only present for about 350 observations. To categorize
# more, I try to use a dictionary below

# Dictionary to categorize educations
patterns <- list(
  LVU = c(
    "cand\\.", "ph\\.d\\.", "magister", "kandidat", "Aarhus Universitet", "Københavns Universitet",
    "Aalborg Universitet", "Syddansk Universitet", "Copenhagen Business School",
    "Danmarks tekniske uni", "DTU", "SDU", "AU", "KU", "CBS", "Roskilde Universitet",
    "RUC"),
  MVU = c("ingeniør", "lærer", "sygeplejerske", "pædagog", "socialrådgiver",
          "professionsbachelor", "bachelor", "professionshøjskole"),
  KVU = c("diplom", "akademi", "erhvervsakademi"),
  Erhvervsfaglig = c("mekaniker", "tømrer", "elektriker", "udlært", "faglært",
                     "erhvervsskole", "landmand"),
  Gymnasial = c("gymnasium", " HF", " HTX", " HHX", "student"),
  Grundskole = c("folkeskole", "grundskole", "klasse")
)

# Function to categorize education based on the dictionary
categorize_education <- function(text) {
  if (is.na(text) || str_trim(text) == "") {
    return(NA)
  }
  for (category in names(patterns)) {
    for (pattern in patterns[[category]]) {
      if (str_detect(text, regex(pattern, ignore_case = TRUE))) {
        return(category)
      }
    }
  }
  return(NA)
}

# Subsetting to only the rows where there is no education data
empty_edu <- df |> 
  filter(education_category %in% c(NA, ""))

# Applying the dictionary to the subset and adding source indicator
empty_edu <- empty_edu |> 
  mutate(education_category = sapply(education_text, categorize_education),
         edu_source = "dictionary")

# Combining back into one data frame
df <- df |> 
  filter(!education_category %in% c(NA, "")) |> 
  mutate(edu_source = "html tag") |> 
  bind_rows(empty_edu) |> 
  mutate(edu_source = if_else(
    is.na(education_category),
    NA,
    edu_source))

# Saving the final biography data frame
saveRDS(df, file = "data/processed/mp_biographies.rds")



